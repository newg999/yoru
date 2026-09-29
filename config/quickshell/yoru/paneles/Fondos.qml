// ============================================================================
//  Fondos — elegir fondo de pantalla con miniaturas, en mitad de la pantalla
//  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin panel
//
//    ↑ ↓ ← → para moverte · Enter para ponerlo · Esc para cerrar
//
//  Los fondos salen de ~/.local/share/wallpapers (scripts/fondos.sh hace
//  las miniaturas la primera vez) y se ponen con niri/scripts/wallpaper.sh,
//  que también los lleva al bloqueo, al inicio de sesión y a «yoru tema fondo».
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Panel {
    id: panel
    nombre: "fondos"
    lado: "medio"
    ancho: 1000

    readonly property int columnas: 5
    readonly property string casa: Quickshell.env("HOME")

    property var fondos: []          // [{ruta, miniatura, nombre}]
    property string actual: ""
    property bool cargando: false

    onAbiertoChanged: {
        if (abierto) {
            cargando = fondos.length === 0;
            leer.running = true;
            actualFile.reload();
            rejilla.forceActiveFocus();
        }
    }

    function poner(fondo) {
        if (!fondo)
            return;
        actual = fondo.ruta;
        Niri.lanzar([casa + "/.config/niri/scripts/wallpaper.sh", fondo.ruta]);
        Paneles.cerrar();
    }

    FileView {
        id: actualFile
        path: panel.casa + "/.cache/wallpaper-actual"
        onLoaded: panel.actual = text().trim()
    }

    Process {
        id: leer
        command: [Quickshell.shellPath("scripts/fondos.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.fondos = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [ruta, miniatura] = l.split("\t");
                    return {ruta, miniatura, nombre: ruta.split("/").pop().replace(/\.[^.]+$/, "")};
                });
                panel.cargando = false;
                const i = panel.fondos.findIndex(f => f.ruta === panel.actual);
                rejilla.currentIndex = Math.max(i, 0);
                rejilla.positionViewAtIndex(rejilla.currentIndex, GridView.Contain);
            }
        }
    }

    Column {
        width: parent.width
        spacing: 12

        Titular {
            width: parent.width
            texto: "Fondos · " + panel.fondos.length

            BotonIcono {
                icono: "󰒝"
                ayuda: "Uno al azar"
                visible: panel.fondos.length > 1
                onClic: panel.poner(panel.fondos[Math.floor(Math.random() * panel.fondos.length)])
            }
        }

        GridView {
            id: rejilla
            width: parent.width
            height: Math.min(Math.ceil(Math.max(panel.fondos.length, 1) / panel.columnas), 3) * cellHeight
            clip: true
            cellWidth: Math.floor(width / panel.columnas)
            cellHeight: cellWidth
            model: panel.fondos
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            keyNavigationWraps: true
            focus: true

            Keys.onReturnPressed: panel.poner(panel.fondos[currentIndex])
            Keys.onEnterPressed: panel.poner(panel.fondos[currentIndex])
            Keys.onEscapePressed: Paneles.cerrar()

            Texto {
                visible: panel.fondos.length === 0
                anchors.centerIn: parent
                text: panel.cargando ? "Preparando miniaturas…"
                    : "No hay fondos: echa imágenes en wallpapers/ o ejecuta wallpapers/descargar.sh"
                font.bold: false
                color: Tema.gris
            }

            delegate: Item {
                id: celda
                required property var modelData
                required property int index
                readonly property bool elegida: GridView.isCurrentItem
                readonly property bool puesto: modelData.ruta === panel.actual
                width: rejilla.cellWidth
                height: rejilla.cellHeight

                Rectangle {
                    anchors { fill: parent; margins: 5 }
                    radius: 12
                    color: Tema.caja
                    border.width: celda.elegida ? 3 : celda.puesto ? 1 : 0
                    border.color: celda.elegida ? Tema.blanco : Tema.claro(0.5)

                    ClippingRectangle {
                        anchors { fill: parent; margins: celda.elegida ? 5 : 3 }
                        radius: 9
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: "file://" + celda.modelData.miniatura
                            sourceSize: Qt.size(256, 256)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: celda.elegida ? 1 : 0.8
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                        }
                    }

                    // El que está puesto ahora
                    Rectangle {
                        visible: celda.puesto
                        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                        width: 24; height: 24; radius: 12
                        color: Tema.blanco
                        Texto {
                            anchors.centerIn: parent
                            text: "󰄬"
                            font.pixelSize: 14
                            color: Tema.oscuro
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: rejilla.currentIndex = celda.index
                    onClicked: panel.poner(celda.modelData)
                }
            }
        }

        Texto {
            leftPadding: 4
            width: parent.width
            elide: Text.ElideRight
            text: (panel.fondos[rejilla.currentIndex]?.nombre ?? "") + "  <font color='" + Tema.gris + "'>·  Enter lo pone  ·  Esc cierra</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
        }
    }
}
