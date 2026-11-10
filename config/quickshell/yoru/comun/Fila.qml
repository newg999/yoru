// ============================================================================
//  Fila — un elemento de las listas de los paneles (red wifi, dispositivo...)
//  La elegida (seleccionada) se marca con Seleccion: fondo tenue, rayita de
//  luz y el texto del color del tema. Los botones extra van a la derecha.
// ============================================================================
import QtQuick

Rectangle {
    id: fila

    property string icono: ""
    property string titulo: ""
    property string detalle: ""          // segunda línea, en gris
    property bool seleccionada: false    // en uso / conectada
    property bool ocupada: false         // conectando... (el icono parpadea)
    property int formato: Text.AutoText  // Text.PlainText si el título es texto ajeno
    default property alias extras: botones.data
    readonly property alias hover: raton.containsMouse
    readonly property color colorTexto: seleccionada ? Tema.blanco : Tema.texto

    signal clic()

    implicitHeight: detalle !== "" ? 48 : 40
    radius: Tema.esquina(10)
    color: !seleccionada && raton.containsMouse ? Tema.cajaHover : "transparent"
    Behavior on color { ColorAnimation { duration: Tema.rapida } }

    Seleccion { activa: fila.seleccionada; radio: fila.radius }

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: fila.clic()
    }

    Texto {
        id: icono
        text: fila.icono
        font.pixelSize: 18
        color: fila.colorTexto
        width: 22
        horizontalAlignment: Text.AlignHCenter
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }

        SequentialAnimation on opacity {
            running: fila.ocupada
            loops: Animation.Infinite
            onRunningChanged: if (!running) icono.opacity = 1
            NumberAnimation { to: 0.3; duration: 500 }
            NumberAnimation { to: 1; duration: 500 }
        }
    }

    Column {
        anchors {
            left: icono.right; leftMargin: 12
            right: botones.left; rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        Texto {
            width: parent.width
            text: fila.titulo
            textFormat: fila.formato
            color: fila.colorTexto
            font.bold: fila.seleccionada
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

    Row {
        id: botones
        spacing: 2
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
    }
}
