// ============================================================================
//  Isla — recuadro translúcido de la barra que agrupa uno o varios módulos
//  Los módulos se ponen dentro y se colocan en fila.
//  Si no hay nada visible dentro, la isla se desvanece.
//  Con pulsable: true, la isla entera es un solo botón (avisa con clic(boton)
//  y rueda(pasos)); al pasar el ratón se iluminan sus módulos, como los demás
//  (resaltado: isla.hover), sin cambiar el fondo.
//  Con ayuda: "...", al dejar el ratón encima sale un recuadro con más
//  información (ver Ayuda.qml).
// ============================================================================
import QtQuick
import Quickshell

Rectangle {
    id: isla

    default property alias contenido: fila.data
    property int relleno: 14            // margen a izquierda y derecha
    property alias espacio: fila.spacing
    property bool vacia: fila.implicitWidth <= 0
    property bool pulsable: false
    readonly property alias hover: raton.containsMouse
    property string ayuda: ""
    signal clic(int boton)
    signal rueda(int pasos)

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

    // Ayuda: tras un momento con el ratón encima; se quita al abrir o cerrar
    // un panel (lo normal después de un clic)
    HoverHandler { id: sobre }
    Timer {
        id: retraso
        property bool mostrar: false
        interval: 600
        running: sobre.hovered && !mostrar
        onTriggered: mostrar = true
    }
    Connections {
        target: sobre
        function onHoveredChanged() {
            if (!sobre.hovered)
                retraso.mostrar = false;
        }
    }
    Connections {
        target: Paneles
        function onAbiertoChanged() {
            retraso.mostrar = false;
        }
    }
    Ayuda {
        objetivo: isla
        texto: isla.ayuda
        mostrar: retraso.mostrar && Paneles.abierto === "" && !Niri.overview
    }

    Row {
        id: fila
        anchors.verticalCenter: parent.verticalCenter
        x: isla.relleno
        spacing: 0
    }
}
