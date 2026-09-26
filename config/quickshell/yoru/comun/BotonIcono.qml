// Botón redondo con un icono (buscar, olvidar, desconectar...)
import QtQuick

Rectangle {
    id: boton

    property string icono: ""
    property string ayuda: ""            // (reservado para un tooltip)
    property color colorIcono: Tema.texto
    property bool girando: false         // p. ej. mientras busca redes
    signal clic()

    implicitWidth: 30
    implicitHeight: 30
    radius: 8
    color: raton.containsMouse ? Tema.cajaHover : "transparent"
    Behavior on color { ColorAnimation { duration: Tema.rapida } }

    Texto {
        id: texto
        anchors.centerIn: parent
        text: boton.icono
        font.pixelSize: 15
        color: raton.containsMouse ? Tema.blanco : boton.colorIcono

        RotationAnimation on rotation {
            running: boton.girando
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 1200
            onRunningChanged: if (!running) texto.rotation = 0
        }
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: boton.clic()
    }
}
