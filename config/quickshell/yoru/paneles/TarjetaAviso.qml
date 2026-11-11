// ============================================================================
//  TarjetaAviso — una notificación (en los avisos emergentes y en el panel)
//
//    ┌────────────────────────────────────┐
//    │        DISCORD            hace 2 min │   ← al pasar el ratón, ✕
//    │ [img]  Título                        │
//    │        Texto, hasta 4 líneas…        │
//    │        [Responder] [Marcar leído]    │
//    └────────────────────────────────────┘
//
//  Con el mismo orden que la tarjeta de la música: de dónde viene en
//  pequeño y mayúsculas, el título y, más suave, el texto.
//
//  Clic = su acción por defecto (suele abrir la app) · ✕ = descartarla
//  (la ✕ sale al pasar el ratón). Las urgentes llevan el borde rojo.
//  Con tiempo (0-1, los avisos emergentes), una raya fina abajo marca lo
//  que le queda antes de irse.
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
    readonly property var n: entrada?.n ?? null
    property int lineas: 4                  // del texto, como mucho
    readonly property bool hover: encima.hovered
    readonly property bool urgente: n?.urgency === NotificationUrgency.Critical
    readonly property string foto: Notificaciones.imagen(n)
    property real tiempo: -1                // lo que le queda (0-1); -1 = sin raya

    // El margen de dentro (más holgado que el de las tarjetas pequeñas)
    readonly property int margen: 14
    implicitHeight: Math.max(columna.implicitHeight, marco.height) + 2 * margen
    radius: Tema.esquina(12)
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

    // Imagen o icono de la app (centrado con el texto); si no hay, su inicial
    Item {
        id: marco
        x: tarjeta.margen
        y: tarjeta.margen + Math.max(0, Math.min(columna.height, 72) - height) / 2
        width: 40; height: 40

        ClippingRectangle {
            anchors.fill: parent
            radius: Tema.esquina(10)
            color: "transparent"
            visible: tarjeta.foto !== "" && imagen.status !== Image.Error

            Image {
                id: imagen
                anchors.fill: parent
                source: tarjeta.foto
                sourceSize: Qt.size(80, 80)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: Tema.esquina(10)
            color: tarjeta.urgente ? Qt.rgba(Tema.rojo.r, Tema.rojo.g, Tema.rojo.b, 0.18) : Tema.claro(0.08)
            visible: tarjeta.foto === "" || imagen.status === Image.Error

            Texto {
                anchors.centerIn: parent
                readonly property string nombre: (tarjeta.n?.appName ?? "").trim()
                text: nombre !== "" ? nombre[0].toUpperCase() : "󰂚"
                font.pixelSize: 18
                color: tarjeta.urgente ? Tema.rojo : Tema.texto
            }
        }
    }

    Column {
        id: columna
        anchors {
            left: marco.right; leftMargin: 12
            right: parent.right; rightMargin: tarjeta.margen
            top: parent.top; topMargin: tarjeta.margen
        }
        spacing: 2

        // APP                                            ahora  (✕ encima)
        Item {
            width: parent.width
            height: 14

            Texto {
                anchors { left: parent.left; right: cuando.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: (tarjeta.n?.appName || "Aviso").toUpperCase()
                textFormat: Text.PlainText
                font.pixelSize: 9
                font.letterSpacing: 1.2
                color: tarjeta.urgente ? Tema.rojo : Tema.gris
                elide: Text.ElideRight
            }
            Texto {
                id: cuando
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: Notificaciones.hace(tarjeta.entrada?.hora ?? new Date())
                font.pixelSize: 10
                font.bold: false
                color: Tema.gris
                opacity: encima.hovered ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
            }
            BotonIcono {
                id: cerrar
                anchors { right: parent.right; rightMargin: -6; verticalCenter: parent.verticalCenter }
                implicitWidth: 22; implicitHeight: 22
                icono: "󰅖"
                colorIcono: Tema.texto
                opacity: encima.hovered ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                onClic: Notificaciones.descartar(tarjeta.entrada)
            }
        }

        Texto {
            width: parent.width
            visible: text !== ""
            text: tarjeta.n?.summary ?? ""
            textFormat: Text.PlainText
            font.pixelSize: 13
            color: Tema.texto
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
            opacity: 0.7
            linkColor: Tema.blanco
            wrapMode: Text.Wrap
            maximumLineCount: tarjeta.lineas
            elide: Text.ElideRight
            onLinkActivated: enlace => Qt.openUrlExternally(enlace)
        }

        // Botones de acción
        Item {
            width: parent.width
            height: 36
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
                        radius: Tema.esquina(8)
                        color: sobre.containsMouse ? Tema.claro(0.16) : Tema.claro(0.08)
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }

                        Texto {
                            id: etiqueta
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, columna.width - 24)
                            text: accion.modelData.text
                            font.pixelSize: 12
                            color: Tema.texto
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

    // Lo que le queda antes de irse (los avisos emergentes): una raya fina
    // en el borde de abajo, entre las esquinas
    Rectangle {
        visible: tarjeta.tiempo >= 0
        x: tarjeta.radius
        y: parent.height - height - 1
        width: (parent.width - 2 * tarjeta.radius) * Math.max(0, tarjeta.tiempo)
        height: 2
        radius: 1
        color: tarjeta.urgente ? Tema.rojo : Tema.blanco
        opacity: 0.45
    }
}
