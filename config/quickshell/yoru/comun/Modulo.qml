// ============================================================================
//  Modulo — un icono (y opcionalmente un texto) de la barra que se puede pulsar
//  Al pasar el ratón se ilumina en blanco, como en waybar.
//
//    Modulo {
//        icono: "󰕾"; texto: "40%"
//        onClic: boton => ...        // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
//        onRueda: pasos => ...       // +1 arriba, -1 abajo
//    }
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

    signal clic(int boton)
    signal rueda(int pasos)

    readonly property color colorActual: colorAviso.a > 0 ? colorAviso
        : (raton.containsMouse && pulsable) || resaltado ? Tema.blanco
        : apagado ? Tema.tenue : Tema.texto

    implicitWidth: fila.implicitWidth + 2 * relleno
    implicitHeight: Tema.altoBarra

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: modulo.texto !== "" && modulo.icono !== "" ? 10 : 0

        Texto {
            text: modulo.icono
            visible: text !== ""
            font.pixelSize: modulo.tamIcono
            color: modulo.colorActual
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
        }
        Texto {
            text: modulo.texto
            visible: text !== ""
            color: modulo.colorActual
            elide: Text.ElideRight
            width: modulo.anchoTexto > 0 ? Math.min(implicitWidth, modulo.anchoTexto) : implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
        }
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
