// ============================================================================
//  Ficha — botón redondo dentro de una píldora (BarraIslas.qml)
//  Gris oscuro normal, del color del tema con activa: true (wifi conectado,
//  bluetooth encendido...). Con carga (0 a 1), se llena de color solo hasta
//  ahí, como una batería.
//
//    Ficha {
//        icono: "󰖩"; texto: "Casa"; activa: true
//        onClic: boton => ...      // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
//        onRueda: pasos => ...     // +1 arriba, -1 abajo
//    }
// ============================================================================
import QtQuick
import qs.comun

Rectangle {
    id: ficha

    property string icono: ""
    property string texto: ""
    property bool activa: false
    property real carga: -1             // 0..1: llena hasta ahí (-1 = no)
    property bool pulsable: true
    property bool apagada: false        // gris (sin reproductor...)
    property color colorIcono: tinta
    property int tamIcono: 13
    property int anchoTexto: 0          // > 0 = recorta el texto con "…"
    readonly property alias hover: raton.containsMouse

    signal clic(int boton)
    signal rueda(int pasos)

    readonly property bool llena: activa || carga > 0.5
    readonly property color tinta: apagada ? Tema.tenue : llena ? Tema.oscuro : (hover && pulsable ? Tema.blanco : Tema.texto)

    implicitHeight: 22
    implicitWidth: texto === "" ? implicitHeight : fila.implicitWidth + 2 * (icono === "" ? 10 : 9)
    radius: height / 2
    color: activa ? (hover && pulsable ? Qt.lighter(Tema.blanco, 1.1) : Tema.blanco)
        : hover && pulsable ? Tema.claro(0.14) : Tema.claro(0.07)
    Behavior on color { ColorAnimation { duration: Tema.rapida } }
    clip: true

    // Lo cargado: del color del tema, de la izquierda hasta «carga»
    Rectangle {
        visible: ficha.carga >= 0 && !ficha.activa
        width: ficha.width * Math.max(0, Math.min(1, ficha.carga))
        height: ficha.height
        radius: ficha.radius
        color: Tema.blanco
        // Recto por la derecha (salvo lleno del todo)
        Rectangle {
            visible: parent.width < ficha.width && parent.width > ficha.radius
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: ficha.radius
            color: Tema.blanco
        }
    }

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: ficha.icono !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.icono
            color: ficha.colorIcono
            font.family: Tema.mono
            font.pixelSize: ficha.tamIcono
        }
        Text {
            visible: ficha.texto !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.texto
            color: ficha.tinta
            font.family: Tema.mono
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
            width: ficha.anchoTexto > 0 ? Math.min(implicitWidth, ficha.anchoTexto) : implicitWidth
        }
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        enabled: ficha.pulsable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => ficha.clic(e.button)
        onWheel: e => {
            if (e.angleDelta.y !== 0)
                ficha.rueda(e.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
