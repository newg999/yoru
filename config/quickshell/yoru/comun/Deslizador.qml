// ============================================================================
//  Deslizador — barra para el volumen, el brillo...
//  valor va de 0 a 1. Arrastrar, hacer clic o usar la rueda lo cambia
//  y avisa con movido(nuevo).
//  Con conOndas (el progreso de la música), la parte hecha es una línea
//  ondulada que avanza mientras ondas es true (suena); si no, se aplana.
// ============================================================================
import QtQuick

Item {
    id: deslizador

    property real valor: 0
    property bool apagado: false
    property bool ondas: false
    property bool conOndas: false      // dibuja la parte hecha como onda (plana si ondas es false)
    readonly property bool arrastrando: raton.pressed
    signal movido(real nuevo)

    implicitHeight: 22
    implicitWidth: 200

    // Mientras se arrastra se muestra la posición del ratón (sin esperar al sistema)
    property real _local: 0
    readonly property real mostrado: arrastrando ? _local : Math.max(0, Math.min(1, valor))

    // La onda: crece y se aplana poco a poco, y se desplaza mientras hay ondas
    property real amplitudOnda: ondas ? 3 : 0
    Behavior on amplitudOnda { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
    property real faseOnda: 0
    NumberAnimation on faseOnda {
        running: deslizador.conOndas && deslizador.amplitudOnda > 0 && Ajustes.animaciones
        from: 0; to: 2 * Math.PI
        duration: 4000      // una ola cada 4 s: se mueve, pero sin distraer
        loops: Animation.Infinite
    }

    Rectangle {
        id: carril
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        // Con onda, el carril solo se ve en la parte que falta
        anchors.leftMargin: deslizador.conOndas ? deslizador.mostrado * deslizador.width : 0
        height: deslizador.conOndas ? 4 : 6
        radius: height / 2
        color: Tema.claro(0.18)

        Rectangle {
            visible: !deslizador.conOndas
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

    // La parte hecha, ondulada
    Canvas {
        id: onda
        visible: deslizador.conOndas
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 14
        readonly property color color: deslizador.apagado ? Tema.tenue : Tema.blanco
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const fin = deslizador.mostrado * width;
            if (fin < 2)
                return;
            const medio = height / 2, ola = 2 * Math.PI / 26;   // una ola cada 26 px
            ctx.strokeStyle = color;
            ctx.lineWidth = 3.5;
            ctx.lineCap = "round";
            ctx.beginPath();
            for (let x = 2; x <= fin; x += 1) {
                const y = medio + deslizador.amplitudOnda * Math.sin(x * ola - deslizador.faseOnda);
                if (x === 2) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
        Connections {
            target: deslizador
            enabled: deslizador.conOndas
            function onFaseOndaChanged() { onda.requestPaint(); }
            function onAmplitudOndaChanged() { onda.requestPaint(); }
            function onMostradoChanged() { onda.requestPaint(); }
            function onApagadoChanged() { onda.requestPaint(); }
        }
        onWidthChanged: requestPaint()
        onVisibleChanged: requestPaint()
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
