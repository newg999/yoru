// Cabecera pequeña de una lista ("REDES WIFI", "SALIDA"...) con botones a la derecha
import QtQuick
import qs.comun

Item {
    property string texto: ""
    default property alias extras: botones.data

    implicitHeight: 30

    Texto {
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        text: parent.texto.toUpperCase()
        font.pixelSize: 11
        font.letterSpacing: 1
        color: Tema.gris
    }
    Row {
        id: botones
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 2
    }
}
