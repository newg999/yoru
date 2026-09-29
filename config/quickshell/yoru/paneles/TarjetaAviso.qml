// ============================================================================
//  TarjetaAviso — una notificación (en los avisos emergentes y en el panel)
//
//    ┌────────────────────────────────────┐
//    │ [img]  Discord · hace 2 min      ✕ │
//    │        Título                      │
//    │        Texto, hasta 4 líneas…      │
//    │        [Responder] [Marcar leído]  │
//    └────────────────────────────────────┘
//
//  Clic = su acción por defecto (suele abrir la app) · ✕ = descartarla
//  Las urgentes llevan el borde rojo.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.comun

Rectangle {
    id: tarjeta

    required property var entrada           // {n, hora} de Notificaciones
    // Al descartarla, la notificación desaparece un instante antes que su
    // tarjeta: de ahí los «n?.»
    readonly property var n: entrada.n
    property int lineas: 4                  // del texto, como mucho
    readonly property bool hover: encima.hovered
    readonly property bool urgente: n?.urgency === NotificationUrgency.Critical
    readonly property string foto: Notificaciones.imagen(n)

    implicitHeight: Math.max(columna.implicitHeight, 44) + 24
    radius: 12
    color: encima.hovered ? Tema.cajaHover : Tema.caja
    border.width: 1
    border.color: urgente ? Tema.rojo : Tema.claro(0.08)
    Behavior on color { ColorAnimation { duration: Tema.rapida } }

    // Encima de la tarjeta o de sus botones (para que el aviso no se vaya)
    HoverHandler { id: encima }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Notificaciones.abrir(tarjeta.entrada)
    }

    // Imagen o icono de la app; si no hay, una campana
    Item {
        id: marco
        x: 12; y: 12
        width: 44; height: 44

        ClippingRectangle {
            anchors.fill: parent
            radius: 10
            color: "transparent"
            visible: tarjeta.foto !== "" && imagen.status !== Image.Error

            Image {
                id: imagen
                anchors.fill: parent
                source: tarjeta.foto
                sourceSize: Qt.size(88, 88)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Tema.caja
            visible: tarjeta.foto === "" || imagen.status === Image.Error

            Texto {
                anchors.centerIn: parent
                text: "󰂚"
                font.pixelSize: 20
                color: tarjeta.urgente ? Tema.rojo : Tema.gris
            }
        }
    }

    Column {
        id: columna
        anchors {
            left: marco.right; leftMargin: 12
            right: parent.right; rightMargin: 12
            top: parent.top; topMargin: 12
        }
        spacing: 3

        // App · hora                                                    ✕
        Item {
            width: parent.width
            height: 18

            Texto {
                anchors { left: parent.left; right: cerrar.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                text: Tema.html(tarjeta.n?.appName || "Aviso")
                    + Tema.suave("  ·  " + Notificaciones.hace(tarjeta.entrada.hora))
                textFormat: Text.StyledText
                font.pixelSize: 11
                font.bold: false
                color: Tema.gris
                elide: Text.ElideRight
            }
            BotonIcono {
                id: cerrar
                anchors { right: parent.right; rightMargin: -6; verticalCenter: parent.verticalCenter }
                implicitWidth: 24; implicitHeight: 24
                icono: "󰅖"
                colorIcono: Tema.gris
                opacity: encima.hovered ? 1 : 0.5
                onClic: Notificaciones.descartar(tarjeta.entrada)
            }
        }

        Texto {
            width: parent.width
            visible: text !== ""
            text: tarjeta.n?.summary ?? ""
            textFormat: Text.PlainText
            font.pixelSize: 13
            color: Tema.blanco
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }

        Texto {
            width: parent.width
            visible: text !== ""
            // El texto puede traer <b>, <i> y enlaces
            text: (tarjeta.n?.body ?? "").replace(/\n/g, "<br>")
            textFormat: Text.StyledText
            font.pixelSize: 12
            font.bold: false
            color: Tema.texto
            linkColor: Tema.blanco
            wrapMode: Text.Wrap
            maximumLineCount: tarjeta.lineas
            elide: Text.ElideRight
            onLinkActivated: enlace => Qt.openUrlExternally(enlace)
        }

        // Botones de acción
        Item {
            width: parent.width
            height: 34
            visible: botones.count > 0

            Row {
                anchors.bottom: parent.bottom
                spacing: 6

                Repeater {
                    id: botones
                    model: Notificaciones.acciones(tarjeta.n)

                    Rectangle {
                        id: accion
                        required property var modelData
                        width: Math.min(etiqueta.implicitWidth + 24, columna.width)
                        height: 28
                        radius: 8
                        color: sobre.containsMouse ? Tema.claro(0.9) : Tema.claro(0.1)
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }

                        Texto {
                            id: etiqueta
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, columna.width - 24)
                            text: accion.modelData.text
                            font.pixelSize: 12
                            color: sobre.containsMouse ? Tema.oscuro : Tema.texto
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: sobre
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: accion.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
