// ============================================================================
//  Opciones — botones en fila para elegir una (como el perfil de energía)
//
//    Opciones {
//        opciones: [{id: "arriba", icono: "󰞕", texto: "Arriba"}, ...]
//        valor: Ajustes.barra
//        onElegir: id => Ajustes.barra = id
//    }
// ============================================================================
import QtQuick

Row {
    id: selector

    property var opciones: []
    property string valor: ""
    signal elegir(string id)

    spacing: 6

    Repeater {
        model: selector.opciones

        Rectangle {
            id: boton
            required property var modelData
            readonly property bool elegido: selector.valor === modelData.id
            width: (selector.width - selector.spacing * (selector.opciones.length - 1)) / selector.opciones.length
            height: 36
            radius: 10
            color: elegido ? Tema.claro(0.90) : raton.containsMouse ? Tema.cajaHover : Tema.caja
            Behavior on color { ColorAnimation { duration: Tema.rapida } }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Texto {
                    visible: text !== ""
                    text: boton.modelData.icono ?? ""
                    font.pixelSize: 15
                    color: boton.elegido ? Tema.oscuro : Tema.texto
                }
                Texto {
                    text: boton.modelData.texto
                    font.pixelSize: 12
                    color: boton.elegido ? Tema.oscuro : Tema.texto
                }
            }

            MouseArea {
                id: raton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: selector.elegir(boton.modelData.id)
            }
        }
    }
}
