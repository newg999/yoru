// ============================================================================
//  Página «temas» de la píldora (Pildora.qml): las paletas de «yoru tema»,
//  con buscador y sus colores en puntitos. Clic = ponerla (tarda un poco:
//  regenera los colores de todo). La que está puesta va resaltada.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Column {
    id: pagina

    property bool activa: false
    spacing: 8

    readonly property string yoru: Quickshell.env("HOME") + "/.local/bin/yoru"
    property var temas: []            // [{id, nombre, claro, colores}]
    property string aplicando: ""

    readonly property var filtrados: {
        const q = buscar.text.trim().toLowerCase();
        return q === "" ? temas : temas.filter(t => t.nombre.toLowerCase().includes(q) || t.id.includes(q));
    }

    onActivaChanged: {
        if (activa) {
            buscar.text = "";
            leer.running = true;
            buscar.forceActiveFocus();
        }
    }

    function poner(t) {
        if (aplicando !== "" || t.id === Tema.modo)
            return;
        aplicando = t.id;
        aplicar.command = [yoru, "tema", t.id];
        aplicar.running = true;
    }

    Process {
        id: leer
        command: [pagina.yoru, "tema", "--lista"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pagina.temas = JSON.parse(text);
                } catch (e) {
                    console.warn("yoru tema --lista:", e);
                }
            }
        }
    }
    Process {
        id: aplicar
        onExited: pagina.aplicando = ""
    }

    // Buscador
    Rectangle {
        width: parent.width
        height: 36
        radius: 18
        color: Tema.claro(0.04)
        border.width: 1
        border.color: buscar.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

        Texto {
            id: lupa
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: "󰍉"
            font.pixelSize: 15
            color: Tema.gris
        }
        TextInput {
            id: buscar
            anchors { left: lupa.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 13
            clip: true
            Keys.onReturnPressed: if (pagina.filtrados.length) pagina.poner(pagina.filtrados[0])
            Keys.onEnterPressed: if (pagina.filtrados.length) pagina.poner(pagina.filtrados[0])
            Texto {
                visible: buscar.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar un tema…"
                font.bold: false
                font.pixelSize: 13
                color: Tema.gris
            }
        }
    }

    ListView {
        id: lista
        width: parent.width
        height: Math.min(contentHeight, 320)
        clip: true
        spacing: 2
        model: pagina.filtrados
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: fila
            required property var modelData
            readonly property bool puesto: modelData.id === Tema.modo
            readonly property var c: modelData.colores
            width: lista.width
            height: 34
            radius: 8
            color: puesto ? Tema.activo : filaRaton.containsMouse ? Tema.cajaHover : "transparent"
            Behavior on color { ColorAnimation { duration: Tema.rapida } }

            Texto {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: fila.modelData.nombre + (pagina.aplicando === fila.modelData.id ? "  ·  poniendo…" : "")
                font.pixelSize: 12
                font.bold: fila.puesto
                color: fila.puesto ? Tema.blanco : Tema.texto
            }
            // Fondo, texto, acento, rojo y amarillo (los «del fondo» salen
            // de la imagen: un icono en vez de colores)
            Row {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: fila.c ? [fila.c.fondo2, fila.c.texto, fila.c.acento, fila.c.rojo, fila.c.amarillo] : []
                    Rectangle {
                        required property string modelData
                        width: 9; height: 9; radius: 4.5
                        color: modelData
                        border.width: 1
                        border.color: Tema.claro(0.15)
                    }
                }
                Texto {
                    visible: !fila.c
                    text: "󰸉"
                    font.pixelSize: 13
                    color: Tema.gris
                }
            }
            MouseArea {
                id: filaRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pagina.poner(fila.modelData)
            }
        }
    }
}
