// ============================================================================
//  Isla — recuadro translúcido de la barra que agrupa uno o varios módulos
//  Los módulos se ponen dentro y se colocan en fila.
//  Si no hay nada visible dentro, la isla se desvanece.
//  Con pulsable: true, la isla entera es un solo botón (se ilumina al pasar
//  el ratón y avisa con clic(boton) y rueda(pasos)).
// ============================================================================
import QtQuick

Rectangle {
    id: isla

    default property alias contenido: fila.data
    property int relleno: 14            // margen a izquierda y derecha
    property alias espacio: fila.spacing
    property bool vacia: fila.implicitWidth <= 0
    property bool pulsable: false
    readonly property alias hover: raton.containsMouse
    signal clic(int boton)
    signal rueda(int pasos)

    implicitWidth: vacia ? 0 : fila.implicitWidth + 2 * relleno
    implicitHeight: Tema.altoBarra
    radius: Tema.radio
    color: pulsable && raton.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Tema.isla
    Behavior on color { ColorAnimation { duration: Tema.rapida } }
    border.width: 1
    border.color: Tema.islaBorde
    clip: true

    opacity: vacia ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    Behavior on implicitWidth { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

    MouseArea {
        id: raton
        anchors.fill: parent
        enabled: isla.pulsable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => isla.clic(e.button)
        onWheel: e => {
            if (e.angleDelta.y !== 0)
                isla.rueda(e.angleDelta.y > 0 ? 1 : -1);
        }
    }

    Row {
        id: fila
        anchors.verticalCenter: parent.verticalCenter
        x: isla.relleno
        spacing: 0
    }
}
