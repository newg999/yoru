// ============================================================================
//  IconoCable — la conexión por cable de la ficha de red, dibujada: un
//  conector RJ45 visto de frente, con sus contactos y el cable saliendo por
//  abajo (rejilla de 24×24). Lo usa Ficha.qml.
//
//      ╭──────────╮
//      │ ╷  ╷  ╷  │      los contactos
//      ╰─╮      ╭─╯
//        ╰──┬───╯        la lengüeta
//           │            el cable
// ============================================================================
import QtQuick
import QtQuick.Shapes
import qs.comun

Item {
    id: cable
    property color color: Tema.texto
    property int tam: 18
    width: tam
    height: tam

    Shape {
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: cable.tam / 24; yScale: cable.tam / 24 }

        // El cuerpo: ancho arriba y estrecho abajo, con las esquinas redondas
        ShapePath {
            strokeColor: cable.color; strokeWidth: 2; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 6.5; startY: 3.5
            PathLine { x: 17.5; y: 3.5 }
            PathArc { x: 19.5; y: 5.5; radiusX: 2; radiusY: 2 }
            PathLine { x: 19.5; y: 11 }
            PathArc { x: 17.5; y: 13; radiusX: 2; radiusY: 2 }
            PathLine { x: 16; y: 13 }
            PathLine { x: 16; y: 15.5 }
            PathArc { x: 14.5; y: 17; radiusX: 1.5; radiusY: 1.5 }
            PathLine { x: 9.5; y: 17 }
            PathArc { x: 8; y: 15.5; radiusX: 1.5; radiusY: 1.5 }
            PathLine { x: 8; y: 13 }
            PathLine { x: 6.5; y: 13 }
            PathArc { x: 4.5; y: 11; radiusX: 2; radiusY: 2 }
            PathLine { x: 4.5; y: 5.5 }
            PathArc { x: 6.5; y: 3.5; radiusX: 2; radiusY: 2 }
        }
        // Los contactos y el cable
        ShapePath {
            strokeColor: cable.color; strokeWidth: 2; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 9; startY: 7
            PathLine { x: 9; y: 9 }
            PathMove { x: 12; y: 7 }
            PathLine { x: 12; y: 9 }
            PathMove { x: 15; y: 7 }
            PathLine { x: 15; y: 9 }
            PathMove { x: 12; y: 17 }
            PathLine { x: 12; y: 21 }
        }
    }
}
