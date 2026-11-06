// ============================================================================
//  BarraVolumen — barra gruesa y redonda, como la del dock (yoru-dock):
//  arrastrar, clic o rueda. «valor» de 0 a 1; al moverlo avisa con movido(v)
// ============================================================================
import QtQuick
import qs.comun

Item {
    id: barra

    property real valor: 0
    property bool apagado: false        // silenciado: la parte llena en gris
    property int grueso: 8
    signal movido(real v)

    height: 20
    property real arrastre: 0
    readonly property real v: raton.pressed ? arrastre : Math.max(0, Math.min(1, valor))

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: barra.grueso
        radius: barra.grueso / 2
        color: Tema.claro(0.10)
        Rectangle {
            width: Math.max(barra.grueso, parent.width * barra.v)
            height: parent.height
            radius: parent.radius
            color: barra.apagado ? Tema.claro(0.25) : Tema.blanco
            Behavior on width { enabled: !raton.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }
    Rectangle {
        width: barra.grueso + 8
        height: width
        radius: width / 2
        x: Math.max(0, Math.min(barra.width - width, barra.width * barra.v - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: Tema.texto
        border.width: 2
        border.color: Tema.oscuro
        scale: raton.pressed ? 1.25 : raton.containsMouse ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on x { enabled: !raton.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: raton
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function mover(m) {
            barra.arrastre = Math.max(0, Math.min(1, (m.x - 6) / barra.width));
            barra.movido(Math.round(barra.arrastre * 100) / 100);
        }
        onPressed: m => mover(m)
        onPositionChanged: m => { if (pressed) mover(m); }
        onWheel: w => barra.movido(Math.max(0, Math.min(1, barra.valor + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
