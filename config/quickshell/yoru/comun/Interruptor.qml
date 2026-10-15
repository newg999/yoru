// ============================================================================
//  Interruptor — fila con un texto y un interruptor a la derecha
//
//    Interruptor { titulo: "Desenfoque"; detalle: "..."; activo: x; onCambiar: v => x = v }
//
//  Se pulsa en toda la fila, no solo en el interruptor.
// ============================================================================
import QtQuick

Rectangle {
    id: fila

    property string titulo: ""
    property string detalle: ""          // segunda línea, en gris
    property bool activo: false
    signal cambiar(bool valor)

    implicitHeight: detalle !== "" ? 48 : 40
    radius: 10
    color: raton.containsMouse ? Tema.cajaHover : "transparent"
    Behavior on color { ColorAnimation { duration: Tema.rapida } }

    Column {
        anchors {
            left: parent.left; leftMargin: 12
            right: carril.left; rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        Texto {
            width: parent.width
            text: fila.titulo
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Texto {
            width: parent.width
            visible: text !== ""
            text: fila.detalle
            color: Tema.gris
            font.bold: false
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    // El interruptor: carril con una bola que pasa de izquierda a derecha
    Rectangle {
        id: carril
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: 38; height: 22; radius: 11
        color: fila.activo ? Tema.claro(0.90) : Tema.claro(0.15)
        Behavior on color { ColorAnimation { duration: Tema.rapida } }

        Rectangle {
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: fila.activo ? parent.width - width - 3 : 3
            color: fila.activo ? Tema.oscuro : Tema.texto
            Behavior on x { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: fila.cambiar(!fila.activo)
    }
}
