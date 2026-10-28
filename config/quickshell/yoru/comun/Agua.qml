// ============================================================================
//  Agua — relleno como el agua de un vaso
//  La superficie plana, que se inclina despacio a un lado y al otro, con una
//  línea más clara encima (el reflejo). Al cambiar el nivel se mece un poco
//  más y se calma, como al mover el vaso.
//  Es un rectángulo grande que se gira (barato: lo hace la gráfica); con
//  moviendo: false se queda quieto y recto. Llena del todo o vacía, recta.
//
//    Agua {
//        anchors.fill: parent
//        nivel: 0.63              // de 0 a 1
//        horizontal: true         // se llena de izquierda a derecha (si no, de abajo arriba)
//        color: Tema.blanco
//        moviendo: cargando
//    }
//  Para que siga unas esquinas redondas, va dentro de un ClippingRectangle.
// ============================================================================
import QtQuick

Item {
    id: agua

    property real nivel: 0
    property bool horizontal: false
    property color color: "white"
    property real inclinacion: 2        // lo que sube/baja la superficie en cada borde (px)
    property bool moviendo: false
    property int vaiven: 2200           // ms de un lado al otro

    // El nivel sube y baja suave
    property real visto: Math.max(0, Math.min(1, nivel))
    Behavior on visto { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

    // Al cambiar bastante el nivel (más de un 5 %), el vaso «se mueve»: más
    // vaivén que se va calmando. Los cambios pequeños (la CPU sube y baja
    // sin parar) no lo mueven
    property real meneo: 0
    property real anterior: nivel
    onNivelChanged: {
        if (moviendo && Math.abs(nivel - anterior) > 0.05)
            calmar.restart();
        anterior = nivel;
    }
    NumberAnimation {
        id: calmar
        target: agua
        property: "meneo"
        from: 1
        to: 0
        duration: 2500
        easing.type: Easing.OutQuad
    }

    // De -1 a 1 y vuelta, suave en los extremos
    property real lado: 0
    SequentialAnimation on lado {
        running: agua.moviendo && agua.visible && agua.visto > 0 && agua.visto < 1
        loops: Animation.Infinite
        onRunningChanged: if (!running) agua.lado = 0
        NumberAnimation { to: 1; duration: agua.vaiven / 2; easing.type: Easing.InOutSine }
        NumberAnimation { to: -1; duration: agua.vaiven; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: agua.vaiven / 2; easing.type: Easing.InOutSine }
    }

    // Cuánto se inclina: menos cerca de lleno o de vacío (no se sale)
    readonly property real ancho: horizontal ? height : width
    readonly property real tope: (horizontal ? width : height) * Math.min(visto, 1 - visto)
    readonly property real angulo: ancho > 0
        ? Math.atan2(Math.min(tope, inclinacion * (1 + meneo)) * lado, ancho / 2) * 180 / Math.PI : 0

    // De sobra, para que al girar no se le vean las esquinas
    readonly property real grande: 2 * (width + height)

    Rectangle {
        visible: agua.visto > 0
        antialiasing: true
        color: agua.color
        width: agua.grande
        height: agua.grande
        // La superficie es el borde de arriba (o el de la derecha, en horizontal)
        x: agua.horizontal ? agua.width * agua.visto - width : (agua.width - width) / 2
        y: agua.horizontal ? (agua.height - height) / 2 : agua.height * (1 - agua.visto)
        transformOrigin: agua.horizontal ? Item.Right : Item.Top
        rotation: agua.horizontal ? -agua.angulo : agua.angulo

        // El reflejo
        Rectangle {
            visible: agua.visto < 1
            antialiasing: true
            color: Qt.rgba(1, 1, 1, 0.35)
            width: agua.horizontal ? 1.2 : parent.width
            height: agua.horizontal ? parent.height : 1.2
            x: agua.horizontal ? parent.width - width : 0
        }
    }
}
