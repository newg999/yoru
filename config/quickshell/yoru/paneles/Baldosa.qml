// ============================================================================
//  Baldosa — botón grande del centro de control (Wi-Fi, Bluetooth...)
//    Clic en el icono redondo  = encender / apagar
//    Clic en el resto          = abrir su lista debajo
//  Encendida: icono en blanco. Con su lista abierta: borde blanco.
// ============================================================================
import QtQuick
import qs.comun

Rectangle {
    id: baldosa

    property string icono: ""
    property string titulo: ""
    property string detalle: ""
    property bool encendida: false
    property bool elegida: false         // su lista está abierta
    signal alternar()                    // encender / apagar
    signal elegir()                      // abrir su lista

    implicitHeight: 60
    radius: 12
    color: raton.containsMouse ? Tema.cajaHover : Tema.caja
    border.width: 1
    border.color: elegida ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.06)
    Behavior on color { ColorAnimation { duration: Tema.rapida } }
    Behavior on border.color { ColorAnimation { duration: Tema.normal } }

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: baldosa.elegir()
    }

    // Icono redondo: encender / apagar
    Rectangle {
        id: circulo
        width: 38; height: 38; radius: 19
        anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
        color: baldosa.encendida ? Tema.blanco : Qt.rgba(1, 1, 1, circuloRaton.containsMouse ? 0.16 : 0.08)
        Behavior on color { ColorAnimation { duration: Tema.normal } }

        Texto {
            anchors.centerIn: parent
            text: baldosa.icono
            font.pixelSize: 18
            color: baldosa.encendida ? Tema.oscuro : Tema.gris
            Behavior on color { ColorAnimation { duration: Tema.normal } }
        }

        MouseArea {
            id: circuloRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: baldosa.alternar()
        }
    }

    Column {
        anchors {
            left: circulo.right; leftMargin: 11
            right: flecha.left; rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        Texto {
            width: parent.width
            text: baldosa.titulo
            font.pixelSize: 13
            color: Tema.blanco
            elide: Text.ElideRight
        }
        Texto {
            width: parent.width
            text: baldosa.detalle
            font.pixelSize: 11
            font.bold: false
            color: Tema.gris
            elide: Text.ElideRight
        }
    }

    Texto {
        id: flecha
        text: "󰅀"
        font.pixelSize: 14
        color: baldosa.elegida ? Tema.blanco : Tema.gris
        rotation: baldosa.elegida ? 180 : 0
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        Behavior on rotation { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
    }
}
