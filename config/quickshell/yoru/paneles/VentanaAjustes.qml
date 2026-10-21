// ============================================================================
//  VentanaAjustes — los Ajustes de Yoru, como una app aparte
//  Una ventana normal de niri (se mueve, se cierra con Mod+Q o Esc...) con
//  las secciones a la izquierda, como en la mayoría de escritorios, y la
//  elegida a la derecha (PestanaAjustes.qml).
//  Se abre con Mod+Alt+T, desde el lanzador, el centro de control o el botón
//  Ajustes del panel central: todos llaman a Paneles.alternar("ajustes", ...)
//  Solo existe mientras está abierta (Paneles.ajustesAbiertos).
//  Su fondo translúcido se desenfoca por una regla de niri (rules.kdl, por
//  su título: Paneles.tituloAjustes)
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Scope {
    LazyLoader {
        active: Paneles.ajustesAbiertos

        FloatingWindow {
            id: ventana

            title: Paneles.tituloAjustes
            implicitWidth: 1080
            implicitHeight: 760
            minimumSize: Qt.size(780, 480)
            color: Tema.panel
            visible: true
            // Cerrada desde niri (Mod+Q, el botón de cerrar...): se olvida
            onVisibleChanged: if (!visible) Paneles.ajustesAbiertos = false

            readonly property var secciones: [
                {id: "tema", icono: "󰏘", texto: "Tema", detalle: "Colores de todo el escritorio"},
                {id: "fondo", icono: "󰸉", texto: "Fondo", detalle: "El fondo de pantalla"},
                {id: "barra", icono: "󰕮", texto: "Barra y dock", detalle: "Dónde va la barra, qué se ve en ella y el dock"},
                {id: "aspecto", icono: "󰙵", texto: "Aspecto", detalle: "Esquinas, transparencias, letra, animaciones y luz nocturna"},
                {id: "pantallas", icono: "󰍹", texto: "Pantallas", detalle: "Colocar los monitores, resolución y escala"},
                {id: "raton", icono: "󰍽", texto: "Ratón", detalle: "Velocidad, rueda, touchpad y cursor"},
                {id: "apps", icono: "󰀻", texto: "Apps", detalle: "Con qué app se abre cada cosa"}
            ]
            readonly property var actual: secciones.find(s => s.id === Paneles.seccionAjustes) ?? secciones[0]

            // Las secciones leen sus datos al pasar «abierto» a true: si ya
            // naciera en true no se enterarían (QML no avisa del valor inicial)
            property bool lista: false
            Component.onCompleted: lista = true

            Shortcut {
                sequence: "Escape"
                onActivated: Paneles.ajustesAbiertos = false
            }

            // ---------------------------------------------- Barra lateral
            Rectangle {
                id: lateral
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 250
                color: Tema.claro(0.03)

                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Tema.claro(0.08)
                }

                Column {
                    anchors { fill: parent; margins: 14; topMargin: 22 }
                    spacing: 4

                    Row {
                        leftPadding: 10
                        bottomPadding: 18
                        spacing: 12
                        Texto {
                            text: "󰒓"
                            font.pixelSize: 22
                            color: Tema.blanco
                        }
                        Texto {
                            text: "Ajustes"
                            font.pixelSize: 20
                            color: Tema.blanco
                        }
                    }

                    Repeater {
                        model: ventana.secciones

                        Rectangle {
                            id: fila
                            required property var modelData
                            readonly property bool elegida: Paneles.seccionAjustes === modelData.id
                            width: parent.width
                            height: 42
                            radius: 10
                            color: elegida ? Tema.claro(0.90) : filaRaton.containsMouse ? Tema.cajaHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }

                            Row {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 14
                                Texto {
                                    width: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: fila.modelData.icono
                                    font.pixelSize: 17
                                    color: fila.elegida ? Tema.oscuro : Tema.texto
                                }
                                Texto {
                                    text: fila.modelData.texto
                                    font.pixelSize: 14
                                    color: fila.elegida ? Tema.oscuro : Tema.texto
                                }
                            }
                            MouseArea {
                                id: filaRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Paneles.seccionAjustes = fila.modelData.id
                            }
                        }
                    }
                }
            }

            // ------------------------------------------- La sección elegida
            Flickable {
                id: desplazable
                anchors { left: lateral.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                contentHeight: columna.height + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Cada sección empieza arriba
                Connections {
                    target: Paneles
                    function onSeccionAjustesChanged() { desplazable.contentY = 0; }
                }

                Column {
                    id: columna
                    x: Math.max(36, (desplazable.width - width) / 2)
                    y: 30
                    width: Math.min(desplazable.width - 72, 860)
                    spacing: 22

                    Column {
                        width: parent.width
                        spacing: 4
                        Texto {
                            text: ventana.actual.texto
                            font.pixelSize: 26
                            color: Tema.blanco
                        }
                        Texto {
                            width: parent.width
                            text: ventana.actual.detalle
                            font.pixelSize: 13
                            font.bold: false
                            color: Tema.gris
                            wrapMode: Text.Wrap
                        }
                    }

                    PestanaAjustes {
                        width: parent.width
                        pestana: Paneles.seccionAjustes
                        abierto: ventana.lista
                        pantalla: ventana.screen
                    }
                }
            }

            // Barra de desplazamiento: fina, y solo si hay algo que desplazar
            Rectangle {
                visible: desplazable.contentHeight > desplazable.height
                anchors.right: parent.right
                anchors.rightMargin: 4
                width: 4
                radius: 2
                color: Tema.claro(0.25)
                y: desplazable.visibleArea.yPosition * desplazable.height + 4
                height: Math.max(30, desplazable.visibleArea.heightRatio * desplazable.height - 8)
            }
        }
    }
}
