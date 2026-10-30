// ============================================================================
//  Dock — barra de apps abajo, como la del Mac, con la estética de Yoru
//
//    [favoritas] │ [abiertas que no están fijadas]
//
//    Clic           = ir a su ventana · si tiene varias, una lista para elegir
//                     a cuál · si no está abierta, la abre
//    Clic central   = ventana nueva
//    Clic derecho   = menú: sus ventanas, fijar / quitar, ventana nueva,
//                     cerrar todas
//
//  Los puntitos de debajo son sus ventanas abiertas; el alargado, la app
//  que tiene el foco. Cuándo sale se elige en Ajustes (Barra y dock):
//    · con el overview (Mod+Tab), como en GNOME: no reserva espacio y al
//      elegir una app el overview se cierra (lo normal)
//    · siempre, pegado abajo y reservando su espacio
//    · nunca
//  Las apps: comun/Tareas.qml (las favoritas, en comun/Favoritos.qml).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.comun

PanelWindow {
    id: dock
    required property ShellScreen modelData
    screen: modelData

    // Medidas
    readonly property int celda: 40          // hueco de cada app
    readonly property int icono: 28
    readonly property int alto: 44           // alto de la isla
    readonly property bool siempre: Ajustes.dock === "siempre"
    readonly property bool mostrado: siempre || (Ajustes.dock === "overview" && Niri.overview)
    readonly property int margen: siempre ? Tema.margenBarra : 12   // hasta el borde de abajo

    // La ventana mide justo lo que la isla (centrada abajo). El nombre y el
    // menú salen en ventanitas aparte que solo existen mientras se ven.
    // (Antes era una franja transparente de 2560×260 y niri tenía que
    // mezclarla en cada fotograma: con un vídeo, la gráfica iba al 40 %)
    anchors.bottom: true
    margins.bottom: margen
    implicitWidth: isla.width
    implicitHeight: alto
    // (con el estilo dock no: ese ya lleva las apps, barra/BarraDock.qml)
    // (con la barra de Windows tampoco: las apps van en ella)
    visible: Ajustes.dock !== "nunca" && !Ajustes.estiloDock && !Ajustes.windows
    exclusionMode: siempre ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: siempre ? alto + margen : 0
    color: "transparent"
    WlrLayershell.namespace: "yoru-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Escondido: sin zona de clic, para que los clics lleguen a las ventanas
    mask: mostrado ? null : vacia
    Region { id: vacia }
    Connections {
        target: Niri
        function onOverviewChanged() {
            if (!Niri.overview)
                menu.cerrar();
        }
    }

    // ------------------------------------------------------------- Isla
    Rectangle {
        id: isla
        width: fila.implicitWidth + 12
        height: dock.alto
        radius: Tema.radio + 2
        color: Tema.isla
        border.width: Tema.borde(1)
        border.color: Tema.islaBorde
        visible: Tareas.apps.length > 0

        // Sube desde abajo al abrir el overview, como la barra baja desde arriba
        opacity: dock.mostrado ? 1 : 0
        transform: Translate {
            y: dock.mostrado ? 0 : dock.alto + dock.margen
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }

        Row {
            id: fila
            anchors.centerIn: parent

            Repeater {
                model: Tareas.apps

                Row {
                    id: hueco
                    required property var modelData
                    required property int index
                    readonly property var app: modelData
                    readonly property bool enfocada: Tareas.enfocada(app)

                    // Rayita entre las favoritas y las demás
                    Rectangle {
                        visible: hueco.index === Tareas.fijas && Tareas.fijas > 0
                        width: 1
                        height: dock.icono - 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tema.claro(0.15)
                    }
                    Item { visible: hueco.index === Tareas.fijas && Tareas.fijas > 0; width: 6; height: 1 }

                    Item {
                        id: elemento
                        width: dock.celda
                        height: dock.alto

                        // Brillo al pasar el ratón
                        Rectangle {
                            anchors.centerIn: imagen
                            width: dock.icono + 8; height: width
                            radius: 9
                            color: Tema.blanco
                            opacity: raton.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                        }

                        IconImage {
                            id: imagen
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                            implicitSize: dock.icono
                            source: Tareas.icono(hueco.app)
                            asynchronous: true
                            // Crece un poco hacia arriba al pasar el ratón
                            transformOrigin: Item.Bottom
                            scale: raton.pressed ? 1.05 : raton.containsMouse ? 1.16 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                        }

                        // Ventanas abiertas: hasta 3 puntitos; el de la app con el
                        // foco es alargado, como el escritorio activo de la barra
                        Row {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
                            spacing: 3
                            Repeater {
                                model: Math.min(3, hueco.app.ventanas.length)
                                Rectangle {
                                    required property int index
                                    height: 3
                                    width: hueco.enfocada && index === 0 ? 10 : 3
                                    radius: 1.5
                                    color: hueco.enfocada ? Tema.blanco : Tema.claro(0.55)
                                    Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        MouseArea {
                            id: raton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: e => {
                                if (e.button === Qt.RightButton) {
                                    menu.abrir(hueco.app, elemento, false);
                                } else if (e.button === Qt.MiddleButton) {
                                    menu.cerrar();
                                    Tareas.lanzar(hueco.app);
                                } else {
                                    menu.pulsar(hueco.app, elemento);
                                }
                            }
                        }

                        // Nombre encima del icono (tras un momento con el ratón)
                        Timer {
                            id: retraso
                            interval: 450
                            running: raton.containsMouse && !menu.abierto
                        }
                        LazyLoader {
                            active: raton.containsMouse && !retraso.running && !menu.abierto
                            PopupWindow {
                                anchor.item: elemento
                                anchor.rect.y: -8
                                anchor.rect.width: elemento.width
                                anchor.rect.height: 1
                                anchor.edges: Edges.Top
                                anchor.gravity: Edges.Top
                                implicitWidth: etiqueta.implicitWidth + 24
                                implicitHeight: etiqueta.implicitHeight + 14
                                color: "transparent"
                                visible: true
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Tema.panel
                                    border.width: Tema.borde(1)
                                    border.color: Tema.claro(0.25)
                                    Texto {
                                        id: etiqueta
                                        anchors.centerIn: parent
                                        text: Tareas.nombre(hueco.app)
                                            + (hueco.app.ventanas.length > 1 ? Tema.suave("  ×" + hueco.app.ventanas.length) : "")
                                        textFormat: Text.StyledText
                                        font.bold: false
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Menú (clic con varias ventanas y clic derecho)
    MenuApp {
        id: menu
    }
}
