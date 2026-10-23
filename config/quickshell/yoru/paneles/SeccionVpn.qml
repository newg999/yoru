// ============================================================================
//  VPN — va encima de las redes wifi en el Centro de control
//    Clic en una VPN (o en su interruptor) = conectar / desconectar
//    󰆴 = borrarla (pide un segundo clic: se pierde su clave)
//    󰐕 = añadir una: elige un .conf de WireGuard o un .ovpn de OpenVPN de
//        los que haya en tu carpeta personal, o escribe su ruta
//  Los datos y las órdenes van por comun/Vpn.qml (scripts/vpn.py)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Column {
    id: seccion

    property bool activa: false        // la sección está a la vista
    property bool anadiendo: false     // formulario de añadir abierto
    property string borrando: ""       // uuid esperando el 2.º clic para borrar
    spacing: 4

    onActivaChanged: {
        if (activa)
            Vpn.leer();
        else
            anadiendo = false;
    }
    onAnadiendoChanged: {
        if (anadiendo) {
            ruta.text = "";
            nombre.text = "";
            errorImportar = "";
            buscador.running = true;
        }
    }

    // --------------------------------------------------- Añadir una VPN
    property var archivos: []          // [{ruta, archivo, carpeta, tipo}] de vpn.py buscar
    property string errorImportar: ""
    property bool importando: false

    // «Ipad_wg_config.conf» → «Ipad wg config»
    function nombreDe(archivo) {
        return archivo.replace(/\.(conf|ovpn)$/i, "").replace(/[_-]+/g, " ").trim();
    }

    function importar() {
        if (importando)
            return;
        errorImportar = "";
        importando = true;
        importador.command = [Vpn.script, "importar", ruta.text, nombre.text];
        importador.running = true;
    }

    Process {
        id: buscador
        command: [Vpn.script, "buscar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    seccion.archivos = JSON.parse(text);
                } catch (e) {
                    seccion.archivos = [];
                }
            }
        }
    }

    Process {
        id: importador
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            seccion.importando = false;
            if (codigo !== 0) {
                seccion.errorImportar = errores.text.trim() || "No se pudo añadir";
                return;
            }
            seccion.anadiendo = false;
            Vpn.leer();
        }
    }

    Timer {
        id: esperaBorrar
        interval: 3000
        onTriggered: seccion.borrando = ""
    }

    // Cuadro de texto como el de la contraseña del wifi
    component Campo: Rectangle {
        id: campo
        property alias text: entrada.text
        property string pista: ""
        signal aceptado()
        function enfocar() {
            entrada.forceActiveFocus();
        }
        width: parent.width
        height: 40
        radius: Tema.esquina(10)
        color: Tema.caja
        border.width: 1
        border.color: entrada.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

        TextInput {
            id: entrada
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            verticalAlignment: TextInput.AlignVCenter
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 13
            clip: true
            onAccepted: campo.aceptado()
            Keys.onEscapePressed: seccion.anadiendo = false

            Texto {
                visible: entrada.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: campo.pista
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
        }
    }

    // ------------------------------------------------------------ Lista
    Titular {
        width: parent.width
        texto: "VPN"

        BotonIcono {
            icono: seccion.anadiendo ? "󰅖" : "󰐕"
            onClic: seccion.anadiendo = !seccion.anadiendo
        }
    }

    Texto {
        visible: Vpn.lista.length === 0 && !seccion.anadiendo
        width: parent.width
        height: 36
        horizontalAlignment: Text.AlignHCenter
        font.bold: false
        font.pixelSize: 12
        color: Tema.gris
        text: "Ninguna todavía: pulsa 󰐕 para añadir una"
    }

    Repeater {
        model: Vpn.lista

        Fila {
            id: fila
            required property var modelData
            readonly property bool encendida: modelData.estado !== ""
            readonly property bool cambiando: modelData.estado === "activando" || Vpn.ocupada === modelData.uuid
            width: parent.width
            icono: "󰦝"
            titulo: modelData.nombre
            formato: Text.PlainText
            seleccionada: modelData.estado === "activa"
            ocupada: cambiando
            detalle: cambiando ? (encendida ? "Cambiando…" : "Conectando…")
                : modelData.estado === "activa" ? modelData.tipo + " · conectada"
                : modelData.tipo
            onClic: Vpn.alternar(modelData)

            BotonIcono {
                icono: "󰆴"
                colorIcono: fila.seleccionada ? Tema.oscuro : Tema.gris
                alerta: seccion.borrando === fila.modelData.uuid
                onClic: {
                    if (seccion.borrando !== fila.modelData.uuid) {
                        seccion.borrando = fila.modelData.uuid;
                        esperaBorrar.restart();
                        return;
                    }
                    seccion.borrando = "";
                    Vpn.borrar(fila.modelData);
                }
            }

            // Interruptor (como el de Ajustes)
            Item {
                width: 46
                height: 30
                Rectangle {
                    anchors.centerIn: parent
                    width: 38; height: 22; radius: 11
                    color: fila.seleccionada ? Tema.oscuro : Tema.claro(0.15)
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }

                    Rectangle {
                        width: 16; height: 16; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        x: fila.encendida ? parent.width - width - 3 : 3
                        color: fila.seleccionada ? Tema.blanco : Tema.texto
                        Behavior on x { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Texto {
        visible: seccion.borrando !== ""
        width: parent.width
        leftPadding: 4
        text: "Pulsa 󰆴 otra vez para borrarla"
        color: Tema.rojo
        font.pixelSize: 11
        font.bold: false
    }
    Texto {
        visible: Vpn.error !== ""
        width: parent.width
        leftPadding: 4
        text: Vpn.error
        color: Tema.rojo
        font.pixelSize: 11
        font.bold: false
        wrapMode: Text.Wrap
    }

    // ---------------------------------------------------- Formulario
    Column {
        visible: seccion.anadiendo
        width: parent.width
        spacing: 6

        Texto {
            width: parent.width
            leftPadding: 4
            text: seccion.archivos.length ? "Elige el archivo de la VPN" : "No he encontrado archivos de VPN en tu carpeta"
            font.pixelSize: 12
            font.bold: false
            color: Tema.gris
        }

        Repeater {
            model: seccion.archivos
            Fila {
                id: archivo
                required property var modelData
                width: parent.width
                icono: "󰈙"
                titulo: modelData.archivo
                formato: Text.PlainText
                detalle: modelData.tipo + " · " + modelData.carpeta
                seleccionada: ruta.text === modelData.ruta
                onClic: {
                    ruta.text = modelData.ruta;
                    if (nombre.text === "" || seccion.archivos.some(a => seccion.nombreDe(a.archivo) === nombre.text))
                        nombre.text = seccion.nombreDe(modelData.archivo);
                    nombre.enfocar();
                }
            }
        }

        Campo {
            id: ruta
            pista: "O escribe su ruta: ~/Descargas/casa.conf"
            onAceptado: nombre.enfocar()
        }
        Campo {
            id: nombre
            pista: "Nombre (p. ej. Casa)"
            onAceptado: seccion.importar()
        }

        Texto {
            visible: seccion.errorImportar !== ""
            width: parent.width
            leftPadding: 4
            text: seccion.errorImportar
            color: Tema.rojo
            font.pixelSize: 11
            font.bold: false
            wrapMode: Text.Wrap
        }

        Opciones {
            width: parent.width
            opciones: [
                {id: "anadir", icono: seccion.importando ? "󰔟" : "󰐕", texto: "Añadir"},
                {id: "cancelar", icono: "󰅖", texto: "Cancelar"}
            ]
            onElegir: id => {
                if (id === "anadir")
                    seccion.importar();
                else
                    seccion.anadiendo = false;
            }
        }

        Texto {
            width: parent.width
            leftPadding: 4
            text: "Queda guardada en el sistema: después puedes borrar el archivo, que lleva tu clave."
            font.pixelSize: 11
            font.bold: false
            color: Tema.gris
            wrapMode: Text.Wrap
        }
    }

    Item { width: 1; height: 4 }
}
