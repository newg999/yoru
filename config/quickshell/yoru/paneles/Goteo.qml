// ============================================================================
//  Goteo — los avisos que gotean de la campana (Avisos.qml, con «Gota» en
//  Ajustes › Notificaciones y la barra de islas arriba)
//
//  Cada aviso nace como una gota bajo la isla de la campana: se hincha,
//  cae colgando de un cuello que se estira, se suelta (el resto del cuello
//  vuelve a la campana) y se ensancha hasta ser la tarjeta. Al irse hace lo
//  mismo al revés: se encoge en gota y la campana se la vuelve a tragar.
//  Si ya hay avisos, el nuevo gotea del de encima, en cadena (como mucho
//  3; el más viejo se va primero).
//
//        ( 󰂚 )         la campana (la pinta la barra)
//          ╲╱          el cuello
//          ●           la gota
//     ╭──────────╮
//     │  aviso   │     la tarjeta
//     ╰──────────╯
//
//  Gota, cuello y tarjetas van en una sola capa («goo») pintada opaca y
//  luego con la transparencia de las islas: así, donde se tocan no se ve
//  más oscuro, todo es una sola mancha del mismo color que la campana. Lo
//  que cae encima de la campana se recorta («hueco»): ella ya está pintada.
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.comun

Item {
    id: goteo

    // Las notificaciones a la vista, de la más vieja a la más nueva
    property var modelo: []
    // La campana, en coordenadas de este Item: su centro y su radio
    property real origenX: width / 2
    property real origenY: 15
    property real origenR: 15
    // El ancho de las tarjetas, y lo que sobra a cada lado (para el rebote
    // al ensancharse, que se pasa un poco)
    property int ancho: 380
    readonly property int pad: 12
    // De la campana a la primera tarjeta, y entre tarjetas
    property int huecoArriba: 12
    property int separacion: 8
    // Con el ratón encima o el panel abierto, no corre el tiempo
    property bool activo: true

    readonly property int r0: 13                // la gota
    readonly property int radioTarjeta: 20      // la tarjeta, ya ensanchada
    readonly property real faseGota: 0.42       // hasta aquí, gota; luego, tarjeta
    readonly property real faseCorte: 0.78      // (de la parte de gota) se suelta

    readonly property bool ocupado: lista.length > 0
    // El alto de la ventana: crece al llegar uno, pero no encoge mientras
    // se van (redimensionar la ventana a cada fotograma la hacía ir a
    // trompicones); vuelve a lo justo cuando ya no queda ninguno
    readonly property real altoAhora: col.y + col.height + 24
    property real altoTotal: altoAhora
    onAltoAhoraChanged: if (altoAhora > altoTotal || !ocupado) altoTotal = altoAhora
    onOcupadoChanged: if (!ocupado) altoTotal = altoAhora
    readonly property Item zona: col

    implicitWidth: ancho + 2 * pad

    // ------------------------------------------------- Lo que está a la vista
    // lista: las que se ven (también las que se están yendo)
    property var lista: []
    property var saliendo: []
    onModeloChanged: sincronizar()
    Component.onCompleted: sincronizar()
    function sincronizar() {
        const l = lista.slice();
        let s = saliendo.filter(e => !modelo.includes(e));
        for (const e of l)
            if (!modelo.includes(e) && !s.includes(e))
                s.push(e);
        for (const e of modelo)
            if (!l.includes(e))
                l.push(e);
        lista = l;
        saliendo = s;
    }
    function quitar(e) {
        lista = lista.filter(x => x !== e);
        saliendo = saliendo.filter(x => x !== e);
    }

    // ------------------------------------------------------ Curvas de tiempo
    function cl(t) { return Math.max(0, Math.min(1, t)); }
    function suave(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }

    // ------------------------------------------------------------ La mancha
    Item {
        anchors.fill: parent
        opacity: Ajustes.opacidadIslas
        Item {
            id: goo
            anchors.fill: parent
            layer.enabled: goteo.ocupado
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: hueco
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.1
            }
        }
    }
    // Lo que tapa la campana (no se pinta encima de ella)
    Item {
        id: hueco
        anchors.fill: parent
        visible: false
        layer.enabled: goteo.ocupado
        Rectangle {
            x: goteo.origenX - goteo.origenR
            y: goteo.origenY - goteo.origenR
            width: 2 * goteo.origenR
            height: width
            radius: width / 2
            color: "black"
        }
    }

    // ------------------------------------------------------------ Las tarjetas
    Column {
        id: col
        x: goteo.pad
        y: goteo.origenY + goteo.origenR + goteo.huecoArriba
        width: goteo.ancho

        Repeater {
            id: repe
            model: ScriptModel { values: goteo.lista }

            delegate: Item {
                id: gota
                required property var modelData
                required property int index

                readonly property bool sale: goteo.saliendo.includes(modelData)
                readonly property real alto: tarjeta.implicitHeight
                // 0 = gota sin nacer · 1 = tarjeta entera
                property real f: 0

                width: col.width
                // Al irse, su sitio se cierra al final (las de abajo suben)
                height: (alto + goteo.separacion) * (sale ? goteo.suave(goteo.cl(f / 0.35)) : 1)

                // De dónde gotea: la campana o la tarjeta de encima
                readonly property Item previa: index > 0 ? repe.itemAt(index - 1) : null
                readonly property bool deCampana: previa === null
                readonly property real sx: deCampana ? goteo.origenX : col.x + col.width / 2
                readonly property real sy: deCampana ? goteo.origenY + goteo.origenR
                    : col.y + previa.y + previa.alto
                readonly property real y0: col.y + y

                // La gota (comun/Gota.qml), pintada en la mancha
                Gota {
                    id: forma
                    capa: goo
                    f: gota.f
                    sx: gota.sx
                    sy: gota.sy
                    fuenteR: gota.deCampana ? goteo.origenR : 0
                    y0: gota.y0
                    xFin: col.x
                    anchoFin: col.width
                    altoFin: gota.alto
                    r0: goteo.r0
                    radioFin: goteo.radioTarjeta
                    faseGota: goteo.faseGota
                    faseCorte: goteo.faseCorte
                }

                TarjetaAviso {
                    id: tarjeta
                    entrada: gota.modelData
                    width: parent.width
                    lineas: 3
                    // El fondo es la mancha; aquí, solo un toque al pasar el ratón
                    color: hover ? Tema.claro(0.05) : "transparent"
                    radius: goteo.radioTarjeta
                    border.width: urgente ? 2 : 0
                    border.color: Tema.rojo
                    opacity: goteo.cl((forma.pB - 0.55) / 0.45)
                    enabled: !gota.sale
                    // Lo que le queda: la raya de abajo
                    property real resta: 1
                    tiempo: duracion > 0 ? resta : -1
                    readonly property int duracion: n?.expireTimeout > 0 ? n.expireTimeout * 1000
                        : urgente ? 0 : Ajustes.avisosSegundos * 1000
                }

                NumberAnimation {
                    id: cuenta
                    target: tarjeta
                    property: "resta"
                    from: 1; to: 0
                    duration: tarjeta.duracion
                    paused: running && (tarjeta.hover || !goteo.activo)
                    onFinished: Notificaciones.ocultar(gota.modelData)
                }
                NumberAnimation {
                    id: entra
                    target: gota
                    property: "f"
                    to: 1
                    duration: Tema.rebote * 2.4
                    onFinished: if (tarjeta.duracion > 0 && !gota.sale) cuenta.start()
                }
                NumberAnimation {
                    id: va
                    target: gota
                    property: "f"
                    to: 0
                    // (se fija al empezar: atada a «f», cambiaba en plena
                    // animación y la gota subía a trompicones)
                    onFinished: goteo.quitar(gota.modelData)
                }
                Component.onCompleted: if (sale) goteo.quitar(modelData); else entra.start()
                onSaleChanged: {
                    if (sale) {
                        entra.stop();
                        cuenta.stop();
                        va.duration = Tema.rebote * 1.8 * Math.max(0.3, f);
                        va.restart();
                    } else {
                        va.stop();
                        entra.restart();
                    }
                }
            }
        }
    }
}
