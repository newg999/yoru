// Escritorios de esta pantalla: el activo es una píldora blanca alargada y
// los demás, circulitos grises (como en DMS). Los que tienen ventanas se
// ven un poco más claros.
// Clic = ir a ese escritorio · Rueda = anterior / siguiente
import QtQuick
import qs.comun

Isla {
    id: isla
    required property string salida
    relleno: 10
    espacio: 6

    Repeater {
        model: Niri.escritoriosDe(isla.salida)

        Item {
            id: escritorio
            required property var modelData
            readonly property bool activo: modelData.is_active
            readonly property bool conVentanas: modelData.active_window_id !== null

            implicitWidth: punto.width
            implicitHeight: Tema.altoBarra

            Rectangle {
                id: punto
                anchors.verticalCenter: parent.verticalCenter
                height: 10
                width: escritorio.activo ? 26 : 10
                radius: height / 2
                color: escritorio.modelData.is_urgent ? Tema.rojo
                    : escritorio.activo || raton.containsMouse ? Tema.blanco
                    : escritorio.conVentanas ? Qt.rgba(1, 1, 1, 0.5)
                    : Qt.rgba(1, 1, 1, 0.25)
                Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
            }

            MouseArea {
                id: raton
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.irA(escritorio.modelData)
                onWheel: e => Niri.accion(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
            }
        }
    }
}
