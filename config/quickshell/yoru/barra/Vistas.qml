// ============================================================================
//  Vistas — al dejar el ratón sobre una app de la barra de Windows
//  (BarraWindows.qml), encima de ella salen sus ventanas en tarjetas, como
//  las vistas previas de Windows: el icono y el título de cada una, dónde
//  está (o «Minimizada») y una × para cerrarla.
//    clic = ir a ella (si está minimizada, vuelve) · central / × = cerrarla
//  Sin ventanas, solo el nombre de la app.
//  (niri no deja capturar una ventana suelta: por eso no hay miniatura)
//
//    mostrar(app, item)   la de esa app, sobre su botón
//    soltar()             el ratón se ha ido: se cierra tras un momento
//                         (a no ser que vaya a las tarjetas)
//    cerrar()             ya
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun

Item {
    id: vistas

    property string clave: ""
    property Item sobre: null
    // Se busca en Tareas.apps cada vez: así sigue al día si se abre o se
    // cierra una ventana con las tarjetas a la vista
    readonly property var app: clave !== "" ? (Tareas.apps.find(a => a.clave === clave) ?? null) : null
    readonly property bool abierto: app !== null
    property bool dentro: false

    function mostrar(a, item) {
        salida.stop();
        sobre = item;
        clave = a.clave;
    }
    function soltar() {
        salida.restart();
    }
    function cerrar() {
        salida.stop();
        clave = "";
    }

    Timer {
        id: salida
        interval: 280
        onTriggered: {
            if (!vistas.dentro)
                vistas.clave = "";
        }
    }

    LazyLoader {
        active: vistas.abierto && vistas.sobre !== null

        PopupWindow {
            id: ventana
            anchor.item: vistas.sobre
            anchor.rect.y: -8
            anchor.rect.width: vistas.sobre?.width ?? 0
            anchor.rect.height: 1
            anchor.edges: Edges.Top
            anchor.gravity: Edges.Top
            // Hueco de sobra para el rebote al aparecer (no se corta)
            implicitWidth: caja.width
            implicitHeight: caja.height + 6
            color: "transparent"
            visible: true

            readonly property var ventanas: vistas.app?.ventanas ?? []

            Rectangle {
                id: caja
                y: 6
                width: ventana.ventanas.length > 0 ? tarjetas.width + 16 : nombre.implicitWidth + 24
                height: ventana.ventanas.length > 0 ? tarjetas.height + 16 : nombre.implicitHeight + 16
                radius: Tema.esquina(10)
                color: Tema.panel
                border.width: Tema.borde(1)
                border.color: Tema.claro(0.18)
                Behavior on width { NumberAnimation { duration: Tema.rebote * 0.7; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                // Al aparecer sube un poco desde la barra, con rebote
                opacity: 0
                transform: Translate { id: subir; y: 10 }
                Component.onCompleted: entrada.start()
                ParallelAnimation {
                    id: entrada
                    NumberAnimation { target: caja; property: "opacity"; to: 1; duration: Tema.rapida }
                    NumberAnimation { target: subir; property: "y"; to: 0; duration: Tema.rebote; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                }

                HoverHandler {
                    onHoveredChanged: {
                        vistas.dentro = hovered;
                        if (!hovered)
                            vistas.soltar();
                    }
                }

                // Sin ventanas: solo el nombre
                Texto {
                    id: nombre
                    visible: ventana.ventanas.length === 0
                    anchors.centerIn: parent
                    text: vistas.app ? Tareas.nombre(vistas.app) : ""
                    font.pixelSize: 12
                }

                Row {
                    id: tarjetas
                    x: 8
                    y: 8
                    spacing: 6

                    Repeater {
                        model: ventana.ventanas.slice(0, 6)

                        Rectangle {
                            id: tarjeta
                            required property var modelData
                            readonly property var v: modelData
                            readonly property bool enfocada: v.id === Niri.enfocada?.id
                            readonly property bool escondida: Tareas.minimizada(v)
                            width: ventana.ventanas.length > 3 ? 168 : 200
                            height: 124
                            radius: Tema.esquina(8)
                            color: raton.containsMouse ? Tema.claro(0.10) : enfocada ? Tema.claro(0.06) : "transparent"
                            border.width: enfocada ? 1 : 0
                            border.color: Tema.claro(0.18)
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }

                            scale: raton.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.rebote * 0.6; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                            MouseArea {
                                id: raton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: e => {
                                    if (e.button === Qt.MiddleButton) {
                                        Tareas.cerrar(tarjeta.v);
                                    } else {
                                        Tareas.irA(tarjeta.v);
                                        vistas.cerrar();
                                    }
                                }
                            }

                            // Arriba: icono, título y ×
                            IconImage {
                                id: icono
                                x: 8
                                y: 8
                                implicitSize: 16
                                source: Tareas.icono(vistas.app)
                                asynchronous: true
                            }
                            Texto {
                                anchors { left: icono.right; leftMargin: 8; right: cerrar.left; rightMargin: 4; verticalCenter: icono.verticalCenter }
                                text: tarjeta.v.title || Tareas.nombre(vistas.app)
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                font.bold: false
                            }
                            Rectangle {
                                id: cerrar
                                anchors { right: parent.right; rightMargin: 4; verticalCenter: icono.verticalCenter }
                                width: 24
                                height: 24
                                radius: Tema.esquina(6)
                                opacity: raton.containsMouse || cerrarRaton.containsMouse ? 1 : 0
                                color: cerrarRaton.containsMouse ? Tema.rojo : "transparent"
                                Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                                Behavior on color { ColorAnimation { duration: Tema.rapida } }
                                Texto {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.pixelSize: 14
                                    color: cerrarRaton.containsMouse ? Tema.oscuro : Tema.texto
                                }
                                MouseArea {
                                    id: cerrarRaton
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Tareas.cerrar(tarjeta.v)
                                }
                            }

                            // Debajo, donde iría la miniatura: el icono en grande
                            // y dónde está
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; top: icono.bottom; bottom: parent.bottom; margins: 8 }
                                radius: Tema.esquina(6)
                                color: Tema.claro(0.05)
                                opacity: tarjeta.escondida ? 0.55 : 1

                                IconImage {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -6
                                    implicitSize: 40
                                    source: Tareas.icono(vistas.app)
                                    asynchronous: true
                                }
                                Texto {
                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                                    text: tarjeta.escondida ? "Minimizada" : Tareas.lugar(tarjeta.v)
                                    font.pixelSize: 10
                                    font.bold: false
                                    color: Tema.gris
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
