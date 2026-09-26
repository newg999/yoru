// ============================================================================
//  Isla — recuadro translúcido de la barra que agrupa uno o varios módulos
//  Los módulos se ponen dentro y se colocan en fila.
//  Si no hay nada visible dentro, la isla se desvanece.
// ============================================================================
import QtQuick

Rectangle {
    id: isla

    default property alias contenido: fila.data
    property int relleno: 14            // margen a izquierda y derecha
    property alias espacio: fila.spacing
    property bool vacia: fila.implicitWidth <= 0

    implicitWidth: vacia ? 0 : fila.implicitWidth + 2 * relleno
    implicitHeight: Tema.altoBarra
    radius: Tema.radio
    color: Tema.isla
    border.width: 1
    border.color: Tema.islaBorde
    clip: true

    opacity: vacia ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    Behavior on implicitWidth { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

    Row {
        id: fila
        anchors.verticalCenter: parent.verticalCenter
        x: isla.relleno
        spacing: 0
    }
}
