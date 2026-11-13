// ============================================================================
//  IconoCable — el ethernet del dock (el antiguo estilo Dock): pantalla, pie y la clavija
//  RJ45 con su cable, dibujado. Lo usa Ficha.qml.
//  Basado en QsDock de LeyzS (MIT): ver LICENSES/QsDock-LeyzS.txt
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
        width: 512
        height: 512
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: cable.tam / 512; yScale: cable.tam / 512 }
        ShapePath {
            strokeColor: cable.color; strokeWidth: 42; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            startX: 304; startY: 80
            PathLine { x: 112; y: 80 }
            PathArc { x: 64; y: 128; radiusX: 48; radiusY: 48; direction: PathArc.Counterclockwise }
            PathLine { x: 64; y: 288 }
            PathArc { x: 112; y: 336; radiusX: 48; radiusY: 48; direction: PathArc.Counterclockwise }
            PathLine { x: 400; y: 336 }
            PathArc { x: 448; y: 288; radiusX: 48; radiusY: 48; direction: PathArc.Counterclockwise }
            PathLine { x: 448; y: 272 }
        }
        ShapePath {
            strokeColor: cable.color; strokeWidth: 42; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 208; startY: 350
            PathLine { x: 208; y: 420 }
            PathMove { x: 304; y: 350 }
            PathLine { x: 304; y: 420 }
            PathMove { x: 160; y: 432 }
            PathLine { x: 352; y: 432 }
            PathMove { x: 400; y: 226 }
            PathLine { x: 400; y: 432 }
        }
        ShapePath {
            strokeColor: cable.color; strokeWidth: 42; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 384; startY: 80
            PathLine { x: 416; y: 80 }
            PathArc { x: 432; y: 96; radiusX: 16; radiusY: 16 }
            PathLine { x: 432; y: 192 }
            PathArc { x: 416; y: 208; radiusX: 16; radiusY: 16 }
            PathLine { x: 384; y: 208 }
            PathArc { x: 368; y: 192; radiusX: 16; radiusY: 16 }
            PathLine { x: 368; y: 96 }
            PathArc { x: 384; y: 80; radiusX: 16; radiusY: 16 }
            PathMove { x: 368; y: 128 }
            PathLine { x: 432; y: 128 }
        }
    }
}
