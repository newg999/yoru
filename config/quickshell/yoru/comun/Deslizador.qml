// ============================================================================
//  Deslizador — barra para el volumen, el brillo...
//  valor va de 0 a 1. Arrastrar, hacer clic o usar la rueda lo cambia
//  y avisa con movido(nuevo).
// ============================================================================
import QtQuick

Item {
    id: deslizador

    property real valor: 0
    property bool apagado: false
    readonly property bool arrastrando: raton.pressed
    signal movido(real nuevo)

    implicitHeight: 22
    implicitWidth: 200

    // Mientras se arrastra se muestra la posición del ratón (sin esperar al sistema)
    property real _local: 0
    readonly property real mostrado: arrastrando ? _local : Math.max(0, Math.min(1, valor))

    Rectangle {
        id: carril
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.18)

        Rectangle {
            width: Math.max(carril.height, deslizador.mostrado * carril.width)
            height: parent.height
            radius: parent.radius
            color: deslizador.apagado ? Tema.tenue : Tema.blanco
            Behavior on width {
                enabled: !deslizador.arrastrando
                NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {
        id: bola
        width: raton.containsMouse || deslizador.arrastrando ? 18 : 14
        height: width
        radius: width / 2
        color: deslizador.apagado ? Tema.gris : Tema.blanco
        anchors.verticalCenter: parent.verticalCenter
        x: deslizador.mostrado * (deslizador.width - width)
        Behavior on width { NumberAnimation { duration: Tema.rapida } }
        Behavior on x {
            enabled: !deslizador.arrastrando
            NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function mover(x) {
            deslizador._local = Math.max(0, Math.min(1, (x - 4) / deslizador.width));
            deslizador.movido(deslizador._local);
        }
        onPressed: e => mover(e.x)
        onPositionChanged: e => { if (pressed) mover(e.x); }
        onWheel: e => {
            const paso = e.angleDelta.y > 0 ? 0.05 : -0.05;
            deslizador.movido(Math.max(0, Math.min(1, Math.round((deslizador.valor + paso) * 20) / 20)));
        }
    }
}
