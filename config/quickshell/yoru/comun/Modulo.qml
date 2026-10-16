// ============================================================================
//  Modulo — un icono (y opcionalmente un texto) de la barra que se puede pulsar
//  Al pasar el ratón se ilumina en blanco, como en waybar.
//  Con la barra a la izquierda, el texto va debajo del icono, más pequeño.
//
//    Modulo {
//        icono: "󰕾"; texto: "40%"
//        onClic: boton => ...        // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
//        onRueda: pasos => ...       // +1 arriba, -1 abajo
//    }
//  Con punto: true, un puntito rojo en la esquina del icono (hay algo nuevo)
// ============================================================================
import QtQuick

Item {
    id: modulo

    property string icono: ""
    property string texto: ""
    property int tamIcono: texto === "" ? Tema.icono : Math.round(Tema.letra * 1.2)
    property int relleno: texto === "" ? 9 : 7
    property bool apagado: false        // gris (silenciado, desconectado...)
    property color colorAviso: "transparent"
    property bool pulsable: true
    property bool resaltado: false      // iluminado desde fuera (isla pulsable)
    property alias hover: raton.containsMouse
    property int anchoTexto: 0          // > 0 = recorta el texto con "…"
    property bool punto: false          // puntito rojo sobre el icono

    signal clic(int boton)
    signal rueda(int pasos)

    readonly property bool vertical: Ajustes.vertical

    readonly property color colorActual: colorAviso.a > 0 ? colorAviso
        : (raton.containsMouse && pulsable) || resaltado ? Tema.blanco
        : apagado ? Tema.tenue : Tema.texto

    implicitWidth: vertical ? Tema.anchoBarra : fila.implicitWidth + 2 * relleno
    implicitHeight: !vertical ? Tema.altoBarra
        : texto === "" ? Tema.altoBarra - 2 : fila.implicitHeight + 12

    // Icono y texto en fila (barra arriba) o uno sobre otro (a la izquierda)
    Grid {
        id: fila
        anchors.centerIn: parent
        // Solo cambian las columnas: una (en columna) o una por elemento (en
        // fila). Cambiar filas y columnas a la vez pasa un momento por 1×1 y
        // Qt avisa. Con columnas de sobra, Grid deja una separación de más al
        // final y el texto quedaba descentrado (más aire a la derecha)
        columns: modulo.vertical ? 1 : Math.max(1, (modulo.icono !== "" ? 1 : 0) + (modulo.texto !== "" ? 1 : 0))
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: modulo.texto === "" || modulo.icono === "" ? 0 : modulo.vertical ? 1 : 10

        Texto {
            id: textoIcono
            text: modulo.icono
            visible: text !== ""
            font.pixelSize: modulo.tamIcono
            color: modulo.colorActual
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
        }
        Texto {
            text: modulo.texto
            visible: text !== ""
            color: modulo.colorActual
            font.pixelSize: modulo.vertical ? Math.min(Tema.letra, 11) : Tema.letra
            horizontalAlignment: Text.AlignHCenter
            lineHeight: modulo.vertical ? 0.95 : 1
            elide: Text.ElideRight
            readonly property int maximo: modulo.vertical ? Tema.anchoBarra - 4 : modulo.anchoTexto
            width: maximo > 0 ? Math.min(implicitWidth, maximo) : implicitWidth
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
        }
    }

    Rectangle {
        visible: modulo.punto
        width: 7
        height: 7
        radius: 3.5
        color: Tema.rojo
        x: fila.x + textoIcono.x + textoIcono.width - 5
        y: fila.y + textoIcono.y + 1
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        enabled: modulo.pulsable
        hoverEnabled: true
        acceptedButtons: modulo.pulsable ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
        cursorShape: modulo.pulsable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: e => modulo.clic(e.button)
        onWheel: e => {
            if (e.angleDelta.y !== 0)
                modulo.rueda(e.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
