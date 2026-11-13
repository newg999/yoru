// ============================================================================
//  IconoVolumen — el altavoz de la ficha del sonido, dibujado (rejilla de
//  24×24): las ondas aparecen según sube el volumen y, silenciado, una X.
//  Siempre centrado: se corre según lo que se ve. Lo usa Ficha.qml.
//
//      ▐◣  )  )        0 % → solo el altavoz (y la X si está en silencio)
//      ▐◤  )  )        20 % → la onda corta entera · 45-70 % → sale la larga
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

    function entre(v, desde, hasta) { return Math.max(0, Math.min(1, (v - desde) / (hasta - desde))); }
    function tinta(a) { return Qt.rgba(color.r, color.g, color.b, Math.max(0, Math.min(1, a))); }

    readonly property bool calla: mudo || volumen <= 0.001
    // Cuánto se ve cada pieza (0..1), animado
    property real corta: calla ? 0 : entre(volumen, 0, 0.2)
    property real larga: calla ? 0 : entre(volumen, 0.45, 0.7)
    property real cruz: calla ? 1 : 0
    Behavior on corta { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutQuad } }
    Behavior on larga { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutQuad } }
    Behavior on cruz { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }

    // La boca del cono: de ahí salen las ondas (arcos de ±50°)
    readonly property real bocaX: 12.5
    readonly property var radios: [3.4, 7]
    function arco(r, arriba) {
        const a = 50 * Math.PI / 180;
        return { x: bocaX + r * Math.cos(a), y: 12 + (arriba ? -1 : 1) * r * Math.sin(a) };
    }
    // Centrado: del borde izquierdo del cuerpo (3,2) a lo último que se ve
    readonly property real fin: Math.max(13.3 + 3.6 * corta + 3.6 * larga, 13.3 + 9 * Math.min(1, cruz))
    readonly property real escala: tam / 24

    Shape {
        width: 24
        height: 24
        x: (12 - (3.2 + icono.fin) / 2) * icono.escala
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: icono.escala; yScale: icono.escala }

        // El cuerpo y el cono, de una pieza
        ShapePath {
            fillColor: icono.color
            strokeColor: icono.color
            strokeWidth: 1.6
            joinStyle: ShapePath.RoundJoin
            startX: 4; startY: 9.5
            PathLine { x: 7.5; y: 9.5 }
            PathLine { x: icono.bocaX; y: 5.2 }
            PathLine { x: icono.bocaX; y: 18.8 }
            PathLine { x: 7.5; y: 14.5 }
            PathLine { x: 4; y: 14.5 }
            PathLine { x: 4; y: 9.5 }
        }
        // Las dos ondas
        ShapePath {
            strokeColor: icono.tinta(icono.corta)
            strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: icono.arco(icono.radios[0], true).x; startY: icono.arco(icono.radios[0], true).y
            PathArc {
                x: icono.arco(icono.radios[0], false).x; y: icono.arco(icono.radios[0], false).y
                radiusX: icono.radios[0]; radiusY: icono.radios[0]
            }
        }
        ShapePath {
            strokeColor: icono.tinta(icono.larga)
            strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: icono.arco(icono.radios[1], true).x; startY: icono.arco(icono.radios[1], true).y
            PathArc {
                x: icono.arco(icono.radios[1], false).x; y: icono.arco(icono.radios[1], false).y
                radiusX: icono.radios[1]; radiusY: icono.radios[1]
            }
        }
        // Silencio: una X donde irían las ondas
        ShapePath {
            strokeColor: icono.tinta(icono.cruz)
            strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: 16.5; startY: 9.5
            PathLine { x: 21.5; y: 14.5 }
            PathMove { x: 21.5; y: 9.5 }
            PathLine { x: 16.5; y: 14.5 }
        }
    }
}
