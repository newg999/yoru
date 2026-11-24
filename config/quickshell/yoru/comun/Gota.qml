// ============================================================================
//  Gota — una gota que cae de una isla (o de una tarjeta) y se ensancha
//  hasta ser un recuadro: la de los avisos (paneles/Goteo.qml) y la de los
//  paneles con «Gotean de su isla» (paneles/Panel.qml)
//
//  Con f de 0 a 1:
//    0 → faseGota    nace la gota bajo la fuente y cae colgando de un
//                    cuello; en «faseCorte» el cuello se suelta y lo que
//                    queda arriba se recoge
//    faseGota → 1    la gota se ensancha (con un poco de rebote) y crece
//                    hasta el recuadro final
//  De 1 a 0, lo mismo al revés: la fuente se la vuelve a tragar.
//
//        ( fuente )      sx, sy = el centro de su borde de abajo
//            ╲╱          el cuello
//            ●           la gota (r0)
//     ╭──────────────╮   y0: arriba del recuadro
//     │              │   xFin, anchoFin, altoFin
//     ╰──────────────╯
//
//  No pinta nada por sí sola: su cuerpo y su cuello se dibujan dentro de
//  «capa», que pone quien la usa. La capa se pinta opaca (Tema.oscuro) y
//  con la transparencia encima (de una vez, para que donde se tocan no se
//  vea más oscuro) y recorta lo que cae sobre la fuente, que ya está pintada.
//
//    Gota {
//        capa: goo; f: progreso
//        sx: ...; sy: ...; fuenteR: isla.height / 2
//        y0: ...; xFin: ...; anchoFin: ...; altoFin: ...
//    }
// ============================================================================
import QtQuick
import QtQuick.Shapes

Item {
    id: gota

    required property Item capa
    property real f: 0
    // La fuente: el centro de su borde de abajo y su radio (la mitad de su
    // alto: el cuello arranca algo por dentro de ella, que no se ve)
    property real sx: 0
    property real sy: 0
    property real fuenteR: 0            // 0 = un borde recto (una tarjeta)
    // El recuadro al que llega
    property real y0: 0
    property real xFin: 0
    property real anchoFin: 0
    property real altoFin: 0
    property real radioFin: 20

    property real r0: 13
    property real faseGota: 0.42
    property real faseCorte: 0.78
    property color color: Tema.oscuro

    // Para quien la usa: lo que va de la parte de recuadro (0-1), para
    // ir mostrando su contenido
    readonly property real pB: cl((f - faseGota) / (1 - faseGota))

    function cl(t) { return Math.max(0, Math.min(1, t)); }
    function salida(t) { return 1 - Math.pow(1 - t, 3); }
    function suave(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
    function muelle(t, s) { const u = t - 1; return 1 + (s + 1) * u * u * u + s * u * u; }

    // La gota: su radio y dónde está su centro
    function radio(p) { return r0 * salida(cl(p * 1.8)); }
    function centro(p) {
        const r = radio(p);
        const ini = sy - r * 0.3;
        return ini + (y0 + r0 - ini) * suave(p);
    }
    readonly property real pA: cl(f / faseGota)
    readonly property real r: radio(pA)
    readonly property real cy: centro(pA)

    // El cuello: de la fuente a la gota; al soltarse, lo que queda arriba se recoge
    readonly property bool cortado: pA >= faseCorte
    readonly property real largoCorte: Math.max(0, centro(faseCorte) - radio(faseCorte) - sy) / 2
    readonly property real a: fuenteR > 0 ? Math.min(fuenteR * 0.8, r0 * 1.6) : r0 * 1.4
    readonly property real ty: sy - (fuenteR > 0 ? Math.min(fuenteR * 0.45, 8) : 0.5)
    readonly property real wy: cortado
        ? sy + largoCorte * (1 - salida(cl((pA - faseCorte) / (1 - faseCorte))))
        : sy + Math.max(0, cy - r - sy) / 2
    readonly property real m: cortado ? 0 : r * 0.8 + (0.6 - r * 0.8) * suave(pA / faseCorte)
    readonly property real b: cortado ? 0 : r * 0.9
    readonly property real by: cortado ? wy : cy

    // El recuadro: de la gota a su sitio, ensanchándose con un poco de rebote
    readonly property real ew: muelle(pB, 0.9)
    readonly property real eh: salida(cl((pB - 0.12) / 0.88))
    readonly property rect cuerpo: f <= faseGota
        ? Qt.rect(sx - r, cy - r, 2 * r, 2 * r)
        : Qt.rect(sx - r0 + (xFin - sx + r0) * ew, y0,
                  2 * r0 + (anchoFin - 2 * r0) * ew,
                  2 * r0 + (altoFin - 2 * r0) * eh)

    Rectangle {
        parent: gota.capa
        visible: gota.f > 0
        x: gota.cuerpo.x
        y: gota.cuerpo.y
        width: gota.cuerpo.width
        height: gota.cuerpo.height
        radius: Math.min(height / 2, width / 2,
            gota.f <= gota.faseGota ? gota.r : gota.r0 + (gota.radioFin - gota.r0) * gota.pB)
        color: gota.color
        antialiasing: true
    }

    Shape {
        parent: gota.capa
        visible: gota.f > 0 && gota.pA < 1 && gota.r > 0.5
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: trazo
            fillColor: gota.color
            strokeWidth: -1
            readonly property real sx: gota.sx
            readonly property real sy: gota.sy
            readonly property real k1: Math.max(2, (gota.wy - sy) * 0.6)
            readonly property real k2: (gota.by - gota.wy) * 0.4
            startX: sx + gota.a; startY: gota.ty
            PathCubic {
                control1X: trazo.sx + gota.a * 0.5; control1Y: trazo.sy
                control2X: trazo.sx + gota.m; control2Y: gota.wy - trazo.k1
                x: trazo.sx + gota.m; y: gota.wy
            }
            PathCubic {
                control1X: trazo.sx + gota.m; control1Y: gota.wy + trazo.k2
                control2X: trazo.sx + gota.b; control2Y: gota.by - trazo.k2
                x: trazo.sx + gota.b; y: gota.by
            }
            PathLine { x: trazo.sx - gota.b; y: gota.by }
            PathCubic {
                control1X: trazo.sx - gota.b; control1Y: gota.by - trazo.k2
                control2X: trazo.sx - gota.m; control2Y: gota.wy + trazo.k2
                x: trazo.sx - gota.m; y: gota.wy
            }
            PathCubic {
                control1X: trazo.sx - gota.m; control1Y: gota.wy - trazo.k1
                control2X: trazo.sx - gota.a * 0.5; control2Y: trazo.sy
                x: trazo.sx - gota.a; y: gota.ty
            }
            PathLine { x: trazo.sx + gota.a; y: gota.ty }
        }
    }
}
