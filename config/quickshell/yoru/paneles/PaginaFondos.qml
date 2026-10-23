// ============================================================================
//  Página «fondos» de la píldora (Pildora.qml): los fondos en cuadrícula,
//  cuatro por fila (rueda = bajar). Clic = ponerlo; el puesto va con borde.
//  (El selector grande, con más opciones: Mod+Alt+W)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Item {
    id: pagina

    property bool activa: false
    // Dos filas y media a la vista: se nota que hay más debajo
    implicitHeight: Math.min(rejilla.contentHeight, rejilla.cellHeight * 2.5)

    readonly property string casa: Quickshell.env("HOME")
    property var fondos: []          // [{ruta, miniatura}]
    property string actual: ""

    onActivaChanged: {
        if (activa) {
            actualArchivo.reload();
            leer.running = true;
        }
    }

    function poner(f) {
        console.info("Píldora › fondo:", f.ruta);
        actual = f.ruta;
        Niri.lanzar([casa + "/.config/niri/scripts/wallpaper.sh", f.ruta]);
    }

    FileView {
        id: actualArchivo
        path: pagina.casa + "/.cache/wallpaper-actual"
        onLoaded: pagina.actual = text().trim()
    }
    Process {
        id: leer
        command: [Quickshell.shellPath("scripts/fondos.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                pagina.fondos = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [ruta, miniatura] = l.split("\t");
                    return {ruta, miniatura};
                });
                const i = pagina.fondos.findIndex(f => f.ruta === pagina.actual);
                if (i >= 0)
                    rejilla.positionViewAtIndex(i, GridView.Contain);
            }
        }
    }

    GridView {
        id: rejilla
        anchors.fill: parent
        clip: true
        model: pagina.fondos
        cellWidth: width / 4
        cellHeight: cellWidth * 16 / 10
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: tarjeta
            required property var modelData
            readonly property bool puesto: modelData.ruta === pagina.actual
            width: rejilla.cellWidth
            height: rejilla.cellHeight

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: Tema.esquina(10)
                color: Tema.claro(0.06)
                clip: true
                scale: tarjetaRaton.containsMouse ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: Tema.rapida } }

                Image {
                    anchors.fill: parent
                    source: "file://" + tarjeta.modelData.miniatura
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(180, 320)
                }
                // El puesto: borde y una marca
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: tarjeta.puesto ? 2 : 0
                    border.color: Tema.blanco
                }
                Rectangle {
                    visible: tarjeta.puesto
                    anchors { right: parent.right; top: parent.top; margins: 6 }
                    width: 20; height: 20; radius: 10
                    color: Tema.blanco
                    Texto {
                        anchors.centerIn: parent
                        text: "󰄬"
                        font.pixelSize: 12
                        color: Tema.oscuro
                    }
                }
            }
            MouseArea {
                id: tarjetaRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: pagina.poner(tarjeta.modelData)
            }
        }
    }
}
