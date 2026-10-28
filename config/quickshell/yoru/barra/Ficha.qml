// ============================================================================
//  Ficha — botón redondo dentro de una píldora (BarraIslas.qml)
//  Gris oscuro normal, del color del tema con activa: true (wifi conectado,
//  bluetooth encendido...). Con carga (0 a 1), se llena de color solo hasta
//  ahí, como una batería; con ola: true, ese relleno ondea como agua
//  (la batería mientras carga).
//
//    Ficha {
//        icono: "󰖩"; texto: "Casa"; activa: true
//        onClic: boton => ...      // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
//        onRueda: pasos => ...     // +1 arriba, -1 abajo
//    }
// ============================================================================
import QtQuick
import Quickshell.Widgets
import qs.comun

// ClippingRectangle: lo de dentro (el agua) sigue las esquinas redondas
ClippingRectangle {
    id: ficha

    property string icono: ""
    property string texto: ""
    property bool activa: false
    property real carga: -1             // 0..1: llena hasta ahí (-1 = no)
    property bool ola: false            // el relleno ondea
    property bool pulsable: true
    property bool apagada: false        // gris (sin reproductor...)
    property color colorIcono: tinta
    property int tamIcono: 13
    property int anchoTexto: 0          // > 0 = recorta el texto con "…"
    readonly property alias hover: raton.containsMouse

    signal clic(int boton)
    signal rueda(int pasos)

    readonly property color tinta: apagada ? Tema.tenue : activa ? Tema.oscuro : (hover && pulsable ? Tema.blanco : Tema.texto)

    implicitHeight: 22
    implicitWidth: texto === "" ? implicitHeight : fila.implicitWidth + 2 * (icono === "" ? 10 : 9)
    radius: height / 2
    color: activa ? (hover && pulsable ? Qt.lighter(Tema.blanco, 1.1) : Tema.blanco)
        : hover && pulsable ? Tema.claro(0.14) : Tema.claro(0.07)
    Behavior on color { ColorAnimation { duration: Tema.rapida } }

    // Lo cargado: del color del tema, de la izquierda hasta «carga»
    Agua {
        visible: ficha.carga >= 0 && !ficha.activa
        anchors.fill: parent
        horizontal: true
        nivel: ficha.carga
        color: Tema.blanco
        inclinacion: 1.5
        vaiven: 1600
        moviendo: ficha.ola
    }

    // Icono y texto
    component Contenido: Row {
        property color tintaIcono
        property color tintaTexto
        spacing: 6
        Text {
            visible: ficha.icono !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.icono
            color: parent.tintaIcono
            font.family: Tema.mono
            font.pixelSize: ficha.tamIcono
        }
        Text {
            visible: ficha.texto !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.texto
            color: parent.tintaTexto
            font.family: Tema.mono
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
            width: ficha.anchoTexto > 0 ? Math.min(implicitWidth, ficha.anchoTexto) : implicitWidth
        }
    }

    Contenido {
        id: fila
        anchors.centerIn: parent
        tintaIcono: ficha.colorIcono
        tintaTexto: ficha.tinta
    }
    // Con carga: encima de lo lleno, el mismo texto en oscuro (claro sobre lo
    // vacío y oscuro sobre el color: se lee entero a cualquier carga)
    Item {
        visible: ficha.carga >= 0 && !ficha.activa
        width: ficha.width * Math.max(0, Math.min(1, ficha.carga))
        height: ficha.height
        clip: true
        Contenido {
            x: fila.x
            y: fila.y
            tintaIcono: Tema.oscuro
            tintaTexto: Tema.oscuro
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
