// ============================================================================
//  Vacio — cuando no hay nada que enseñar (estilo «Noche»): compacto, con un
//  icono en un círculo tenue, una frase y, si hace falta, una pista debajo
//
//          ( 󰝛 )
//      No suena nada
//   Pon música y sale aquí
//
//      Vacio { icono: "󰝛"; titulo: "No suena nada"; detalle: "…" }
// ============================================================================
import QtQuick

Column {
    id: vacio
    property string icono: ""
    property string titulo: ""
    property string detalle: ""
    property int ancho: 280             // del texto de la pista, como mucho
    spacing: 6

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: vacio.icono !== ""
        width: 52; height: 52; radius: 26
        color: Tema.caja
        border.width: 1
        border.color: Tema.claro(0.1)
        Texto {
            anchors.centerIn: parent
            text: vacio.icono
            font.pixelSize: 22
            color: Tema.gris
        }
    }
    Item { width: 1; height: 4; visible: vacio.icono !== "" }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: vacio.titulo
        color: Tema.texto
        font.family: Tema.fuente
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: text !== ""
        width: Math.min(implicitWidth, vacio.ancho)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: vacio.detalle
        color: Tema.gris
        font.family: Tema.fuente
        font.pixelSize: 12
    }
}
