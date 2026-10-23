// ============================================================================
//  Ajustes › Fecha y hora — zona horaria, hora automática y el reloj de la barra
//  La zona y la hora automática son del sistema (timedatectl): al cambiarlas
//  pide la contraseña de administrador. Cambiada la zona, la barra se
//  reinicia sola para que su reloj la coja (Qt no se entera si no) y vuelve
//  a abrir esta sección.
//  El formato del reloj (24/12 h, segundos) se guarda en comun/Ajustes.qml.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Column {
    id: seccion
    spacing: 8

    property bool activa: false        // a la vista: se lee de nuevo
    onActivaChanged: if (activa) leer()

    property string zona: ""           // «Atlantic/Canary»
    property string desfase: ""        // «+01:00»
    property bool automatica: true     // hora por internet (NTP)
    property var zonas: []             // todas, de «timedatectl list-timezones»
    property string error: ""
    property bool ocupado: false

    function leer() {
        error = "";
        lector.running = true;
        if (zonas.length === 0)
            listaZonas.running = true;
    }
    // «America/Argentina/Buenos_Aires» → «Buenos Aires · America / Argentina»
    function bonita(z) {
        const partes = z.split("/");
        const ciudad = partes.pop().replace(/_/g, " ");
        return partes.length ? `${ciudad}  ·  ${partes.join(" / ").replace(/_/g, " ")}` : ciudad;
    }
    function cambiar(orden) {
        if (ocupado)
            return;
        error = "";
        ocupado = true;
        cambio.command = orden;
        cambio.running = true;
    }

    Process {
        id: lector
        command: ["sh", "-c", "timedatectl show -p Timezone -p NTP; date +%:z"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const linea of text.trim().split("\n")) {
                    if (linea.startsWith("Timezone="))
                        seccion.zona = linea.slice(9);
                    else if (linea.startsWith("NTP="))
                        seccion.automatica = linea.slice(4) === "yes";
                    else
                        seccion.desfase = linea;
                }
            }
        }
    }
    Process {
        id: listaZonas
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: seccion.zonas = text.trim().split("\n")
        }
    }
    Process {
        id: cambio
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            seccion.ocupado = false;
            if (codigo !== 0) {
                seccion.error = errores.text.trim() || "No se pudo cambiar";
                return;
            }
            const eraZona = cambio.command[1] === "set-timezone";
            seccion.leer();
            busqueda.text = "";
            // El reloj de la barra no ve la zona nueva hasta reiniciarla
            if (eraZona)
                Niri.lanzar(["sh", "-c", "sleep 0.5; systemctl --user restart yoru-shell; sleep 2; qs -c yoru ipc call panel alternar ajustes fecha"]);
        }
    }

    SystemClock {
        id: reloj
        precision: SystemClock.Seconds
    }

    // --------------------------------------------------- La hora de ahora
    Rectangle {
        width: parent.width
        height: 96
        radius: Tema.esquina(12)
        color: Tema.caja

        Column {
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 4
            Texto {
                text: Qt.formatDateTime(reloj.date, Ajustes.reloj24 ? "HH:mm:ss" : "h:mm:ss AP")
                font.pixelSize: 32
                color: Tema.blanco
            }
            Texto {
                text: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM 'de' yyyy")
                font.pixelSize: 13
                font.bold: false
                color: Tema.gris
            }
        }
        Column {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 4
            Texto {
                anchors.right: parent.right
                text: seccion.zona !== "" ? seccion.bonita(seccion.zona).split("  ·  ")[0] : ""
                font.pixelSize: 15
            }
            Texto {
                anchors.right: parent.right
                text: seccion.zona + (seccion.desfase !== "" ? "  ·  UTC" + seccion.desfase : "")
                font.pixelSize: 11
                font.bold: false
                color: Tema.gris
            }
        }
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Zona horaria"; width: parent.width }
    Interruptor {
        width: parent.width
        titulo: "Hora automática"
        detalle: "La pone en hora por internet"
        activo: seccion.automatica
        onCambiar: v => seccion.cambiar(["timedatectl", "set-ntp", v ? "true" : "false"])
    }

    // Buscador de zonas: escribe tu ciudad (Canary, Madrid, Mexico...)
    Rectangle {
        width: parent.width
        height: 42
        radius: Tema.esquina(10)
        color: Tema.caja
        border.width: 1
        border.color: busqueda.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

        Texto {
            id: lupa
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: "󰍉"
            font.pixelSize: 16
            color: Tema.gris
        }
        TextInput {
            id: busqueda
            anchors { left: lupa.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 13
            clip: true
            Texto {
                visible: busqueda.text === ""
                text: "Buscar ciudad para cambiar de zona (en inglés: Canary, Madrid, Mexico...)"
                font.pixelSize: 13
                font.bold: false
                color: Tema.tenue
            }
            Keys.onReturnPressed: if (resultados.count > 0) seccion.cambiar(["timedatectl", "set-timezone", resultados.model[0]])
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: busqueda.text.trim() !== ""

        Repeater {
            id: resultados
            model: {
                const q = busqueda.text.trim().toLowerCase().replace(/ /g, "_");
                return q === "" ? [] : seccion.zonas.filter(z => z.toLowerCase().includes(q)).slice(0, 8);
            }
            Rectangle {
                id: filaZona
                required property string modelData
                required property int index
                width: parent.width
                height: 38
                radius: Tema.esquina(10)
                color: zonaRaton.containsMouse || index === 0 ? Tema.cajaHover : "transparent"

                Texto {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: seccion.bonita(filaZona.modelData)
                    font.pixelSize: 13
                    font.bold: filaZona.modelData === seccion.zona
                }
                Texto {
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    visible: filaZona.modelData === seccion.zona
                    text: "󰄬"
                    color: Tema.blanco
                }
                MouseArea {
                    id: zonaRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seccion.cambiar(["timedatectl", "set-timezone", filaZona.modelData])
                }
            }
        }
        Texto {
            visible: resultados.count === 0
            leftPadding: 14
            text: "Ninguna zona con ese nombre"
            font.pixelSize: 12
            font.bold: false
            color: Tema.gris
        }
    }

    Texto {
        width: parent.width
        visible: seccion.error !== ""
        text: seccion.error
        color: Tema.rojo
        font.pixelSize: 12
        font.bold: false
        wrapMode: Text.Wrap
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Reloj de la barra"; width: parent.width }
    Opciones {
        width: parent.width
        opciones: [
            {id: "24", icono: "󰥔", texto: "24 horas  (14:30)"},
            {id: "12", icono: "󰥔", texto: "12 horas  (2:30 PM)"}
        ]
        valor: Ajustes.reloj24 ? "24" : "12"
        onElegir: id => Ajustes.reloj24 = id === "24"
    }
    Interruptor {
        width: parent.width
        titulo: "Segundos"
        detalle: Ajustes.vertical ? "Con la barra a la izquierda no caben: no se ven" : "El reloj de la barra con segundos"
        activo: Ajustes.relojSegundos
        onCambiar: v => Ajustes.relojSegundos = v
    }
}
