// ============================================================================
//  IconoVolumen — el altavoz del dock (yoru-dock), dibujado: las ondas salen
//  una a una según sube el volumen; silenciado, una X. Lo usa Ficha.qml.
// ============================================================================
import QtQuick
import QtQuick.Shapes
import qs.comun

Item {
    id: icono
    property real volumen: 0            // 0..1
    property bool mudo: false
    property color color: Tema.texto
    property int tam: 20
    width: tam
    height: tam

    readonly property bool silencio: mudo || volumen <= 0.001
    property real onda1: silencio ? 0 : Math.max(0, Math.min(1, volumen / 0.15))
    property real onda2: silencio ? 0 : Math.max(0, Math.min(1, (volumen - 0.4) / 0.3))
    property real equis: silencio ? 1 : 0
    Behavior on onda1 { NumberAnimation { duration: Tema.normal * 0.8; easing.type: Easing.OutCubic } }
    Behavior on onda2 { NumberAnimation { duration: Tema.normal * 0.8; easing.type: Easing.OutCubic } }
    Behavior on equis { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }

    // Lo que se ve (cuerpo y ondas encendidas), siempre centrado: se corre
    // según cuántas ondas hay
    readonly property real k: tam / 24
    readonly property real bordeDerecho: Math.max(12.8 + 5.0 * onda1 + 3.7 * onda2, 12.8 + 8.2 * Math.min(1, equis))
    readonly property real desvio: 12 - (2.2 + bordeDerecho) / 2

    Shape {
        width: 24
        height: 24
        x: icono.desvio * icono.k
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: icono.k; yScale: icono.k }
        // El cuerpo
        ShapePath {
            fillColor: icono.color; strokeColor: icono.color
            strokeWidth: 2; joinStyle: ShapePath.RoundJoin
            startX: 3; startY: 9.2
            PathLine { x: 7; y: 9.2 }
            PathLine { x: 12; y: 5 }
            PathLine { x: 12; y: 19 }
            PathLine { x: 7; y: 14.8 }
            PathLine { x: 3; y: 14.8 }
            PathLine { x: 3; y: 9.2 }
        }
        // Onda pequeña
        ShapePath {
            strokeColor: Qt.rgba(icono.color.r, icono.color.g, icono.color.b, icono.onda1)
            strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 15.5; startY: 9
            PathArc { x: 15.5; y: 15; radiusX: 4.2; radiusY: 4.2 }
        }
        // Onda grande
        ShapePath {
            strokeColor: Qt.rgba(icono.color.r, icono.color.g, icono.color.b, icono.onda2)
            strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 18; startY: 6
            PathArc { x: 18; y: 18; radiusX: 8.5; radiusY: 8.5 }
        }
        // Silenciado: una X
        ShapePath {
            strokeColor: Qt.rgba(icono.color.r, icono.color.g, icono.color.b, Math.max(0, Math.min(1, icono.equis)))
            strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 15.5; startY: 9.5
            PathLine { x: 20.5; y: 14.5 }
            PathMove { x: 20.5; y: 9.5 }
            PathLine { x: 15.5; y: 14.5 }
        }
    }
}
