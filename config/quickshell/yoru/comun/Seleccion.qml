// ============================================================================
//  Seleccion — cómo se marca lo elegido en una lista (estilo «Noche»)
//
//    ▌  Wi-Fi de casa                ← fondo tenue y una rayita de luz a
//                                      la izquierda; el texto, del color
//                                      del tema (Tema.blanco)
//
//  Va la primera dentro de la fila (debajo de su texto), que deja su propio
//  fondo para el ratón encima:
//      Rectangle {
//          color: !elegida && raton.containsMouse ? Tema.cajaHover : "transparent"
//          Seleccion { activa: elegida }
//          ...
//      }
//  La rayita crece desde el centro al elegirla.
// ============================================================================
import QtQuick

Item {
    id: seleccion
    property bool activa: false
    property real radio: Tema.esquina(10)
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        radius: seleccion.radio
        color: Tema.seleccion
        opacity: seleccion.activa ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
    }
    Rectangle {
        anchors { left: parent.left; leftMargin: 3; verticalCenter: parent.verticalCenter }
        width: 3
        height: seleccion.activa ? Math.round(parent.height * 0.5) : 0
        radius: 1.5
        color: Tema.blanco
        opacity: seleccion.activa ? 1 : 0
        Behavior on height { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
    }
}
