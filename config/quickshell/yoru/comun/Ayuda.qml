// ============================================================================
//  Ayuda — recuadro con información al dejar el ratón encima (tooltip)
//  Sale debajo de «objetivo», centrado (o a su derecha, con la barra a la
//  izquierda). Lo usan las islas de la barra:
//
//    Isla { ayuda: "CPU 12%<br><font color='gris'>...</font>" }
//
//  El texto admite <b>, <br> y <font color>. Solo se crea mientras se ve.
// ============================================================================
import QtQuick
import Quickshell

LazyLoader {
    id: ayuda

    property Item objetivo: null
    property string texto: ""
    property bool mostrar: false

    active: mostrar && texto !== "" && objetivo !== null

    PopupWindow {
        anchor.item: ayuda.objetivo
        anchor.rect.width: ayuda.objetivo.width + (Ajustes.vertical ? 6 : 0)
        anchor.rect.height: ayuda.objetivo.height + (Ajustes.vertical ? 0 : 6)
        anchor.edges: Ajustes.vertical ? Edges.Right : Edges.Bottom
        anchor.gravity: Ajustes.vertical ? Edges.Right : Edges.Bottom
        implicitWidth: caja.width
        implicitHeight: caja.height
        color: "transparent"
        visible: true

        Rectangle {
            id: caja
            width: etiqueta.implicitWidth + 24
            height: etiqueta.implicitHeight + 16
            radius: 10
            color: Tema.panel
            border.width: 1
            border.color: Tema.claro(0.25)

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }

            Texto {
                id: etiqueta
                x: 12; y: 8
                text: ayuda.texto
                textFormat: Text.StyledText
                font.bold: false
                font.pixelSize: 12
                lineHeight: 1.25
            }
        }
    }
}
