// ============================================================================
//  Personaje — Hotaru (蛍, luciérnaga), la luna de Yoru (夜, «noche»):
//  vive en la isla y reacciona
//  a lo que pasa. Dibujada con formas, en una rejilla de 24×24 que escala.
//  Seria y algo siniestra: gris hueso, media cara en sombra (un eclipse),
//  cráteres hondos y una cicatriz, cejas en V y una brasa en cada ojo.
//
//        ╭───────╮
//      ╭─╯ °  ░░░╰─╮        un disco gris con su sombra, que respira
//      │  ╲▬   ▬╱░░│        cejas fruncidas; ojos entornados con brasa:
//      │         ░░│        parpadean, miran alrededor y siguen al ratón
//      ╰─╮     °░╭─╯
//        ╰───────╯
//
//    Seria: nada de corazones, rubor ni saltitos.
//    contento     hay música: sin sonreír, con su cara seria, cabecea
//                 despacio (baja la cabeza y vuelve)
//    dormido      el equipo lleva un rato sin usarse: ojos cerrados y «z z»
//    preocupado   poca batería: una gota de sudor
//    sorpresa()   llega un aviso: un respingo con los ojos muy abiertos
//    guino()      guiña un ojo
//    jugar()      al hacerle clic: guiña o se enciende (la brasa y el aura)
//    bostezar()   al despertar (y de madrugada, de vez en cuando)
//    mirarHacia() mira un momento a un sitio (al cambiar de escritorio)
//    apretar()    ojos > < un momento (el volumen muy alto)
//    chispas()    unas chispitas (al enchufar el cargador)
//    De madrugada (0-6 h) tiene sueño: ojos entornados.
//    aura         un halo de brasa detrás y una corona de eclipse que asoma
//                 por el lado oscuro: late con su respiración; con música,
//                 al ritmo y más fuerte; dormido, casi apagada
//    pantalla     con ella, mira siempre al cursor (comun/Raton.qml)
//    mirada       si no: hacia dónde mira (-1..1 en x e y); «siguiendo» = la
//                 manda quien lo usa; si no, mira por su cuenta
// ============================================================================
import QtQuick
import QtQuick.Shapes
import qs.comun

Item {
    id: yo

    property real tam: 22
    property bool contento: false
    property bool dormido: false
    property bool preocupado: false
    property bool siguiendo: false
    property point mirada: Qt.point(0, 0)
    // Acepta mimos (pasarle el ratón por encima de lado a lado)
    property bool interactivo: false

    // Gris hueso frío (más apagado que el texto), tinta casi negra y la
    // brasa de los ojos
    property color luna: Qt.darker(Tema.texto, 1.32)
    property color tinta: "#0b0c10"
    property color brasa: "#ff5a48"
    property bool animado: Ajustes.animaciones
    readonly property string nombre: "Hotaru"

    width: tam
    height: tam
    readonly property real u: tam / 24

    // ------------------------------------------------------------ Mirada
    // La de verdad (suave): la que manda quien lo usa o la suya propia
    property point ojeada: Qt.point(0, 0)
    // Con «pantalla» (la ShellScreen donde está), mira siempre al cursor
    // (comun/Raton.qml): en su dirección, y más de lado cuanto más lejos
    property var pantalla: null
    property real alcance: tam * 8      // a esta distancia, ya del todo de lado
    readonly property bool conRaton: pantalla !== null && Raton.pos !== null
    property int _tic: 0                // la luna se mueve (la isla se abre...)
    Timer {
        running: yo.conRaton && yo.visible
        repeat: true
        interval: 100
        onTriggered: yo._tic++
    }
    readonly property point miradaRaton: {
        _tic;
        const p = Raton.pos;
        if (!conRaton)
            return Qt.point(0, 0);
        const c = yo.mapToItem(null, width / 2, height / 2);
        const dx = p.x - (pantalla.x + c.x), dy = p.y - (pantalla.y + c.y);
        const d = Math.hypot(dx, dy);
        if (d < 1)
            return Qt.point(0, 0);
        const k = Math.min(1, d / alcance);
        return Qt.point(dx / d * k, dy / d * k);
    }
    readonly property point objetivo: dormido ? Qt.point(0, 0.3) : conRaton ? miradaRaton : siguiendo ? mirada : ojeada
    property real mx: objetivo.x
    property real my: objetivo.y
    Behavior on mx { NumberAnimation { duration: (yo.siguiendo || yo.conRaton) ? 90 : 420; easing.type: Easing.OutCubic } }
    Behavior on my { NumberAnimation { duration: (yo.siguiendo || yo.conRaton) ? 90 : 420; easing.type: Easing.OutCubic } }
    // Por su cuenta: de vez en cuando mira a algún lado y vuelve al frente
    Timer {
        running: yo.animado && !yo.dormido && !yo.siguiendo && !yo.conRaton && yo.visible
        repeat: true
        interval: 3500
        onTriggered: {
            interval = 2800 + Math.random() * 5200;
            yo.ojeada = Math.random() < 0.4 ? Qt.point(0, 0)
                : Qt.point(Math.random() * 2 - 1, Math.random() * 1.2 - 0.5);
        }
    }

    function mirarHacia(x, y) {
        if (!animado || dormido)
            return;
        ojeada = Qt.point(x, y);
        volverAlFrente.restart();
    }
    Timer { id: volverAlFrente; interval: 900; onTriggered: yo.ojeada = Qt.point(0, 0) }

    // ---------------------------------------------------------- Párpados
    property real parpado: 1            // 1 abierto · 0 cerrado
    property real guinando: 1           // el derecho, al guiñar
    SequentialAnimation {
        id: parpadeo
        NumberAnimation { target: yo; property: "parpado"; to: 0.08; duration: 70 }
        NumberAnimation { target: yo; property: "parpado"; to: 1; duration: 110 }
    }
    Timer {
        running: yo.animado && !yo.dormido && yo.visible
        repeat: true
        interval: 3000
        onTriggered: {
            interval = 2200 + Math.random() * 4300;
            parpadeo.restart();
            // A veces, dos seguidos
            if (Math.random() < 0.2)
                otroParpadeo.start();
        }
    }
    Timer { id: otroParpadeo; interval: 260; onTriggered: parpadeo.restart() }

    // ----------------------------------------------------- Saltos y gestos
    property real salto: 0              // en unidades, hacia arriba
    property real asombro: 0            // 0..1: ojos más grandes
    function sorpresa() {
        if (!animado || dormido)
            return;
        animSorpresa.restart();
    }
    function guino() {
        if (!animado)
            return;
        animGuino.restart();
    }
    SequentialAnimation {
        id: animSorpresa
        ParallelAnimation {
            NumberAnimation { target: yo; property: "salto"; to: 1.5; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: yo; property: "asombro"; to: 1; duration: 110 }
        }
        NumberAnimation { target: yo; property: "salto"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: yo; property: "asombro"; to: 0; duration: 300 }
    }
    SequentialAnimation {
        id: animGuino
        NumberAnimation { target: yo; property: "guinando"; to: 0.08; duration: 90 }
        PauseAnimation { duration: 420 }
        NumberAnimation { target: yo; property: "guinando"; to: 1; duration: 140 }
    }

    // Jugar (clic): guiña o se enciende, una cada vez
    property bool _guinoAntes: false
    function jugar() {
        if (!animado)
            return;
        if (dormido) {
            bostezar();
            return;
        }
        _guinoAntes = !_guinoAntes;
        (_guinoAntes ? animGuino : animEncender).restart();
    }
    property real giro: 0               // grados de más
    property real sacudida: 0           // -1..1
    property real ojosX: 0              // 0..1: ojos > <
    // Encenderse: la brasa de los ojos y el aura suben y se apagan despacio
    property real encendido: 0          // 0..1
    SequentialAnimation {
        id: animEncender
        NumberAnimation { target: yo; property: "encendido"; to: 1; duration: 180; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: yo; property: "encendido"; to: 0; duration: 900; easing.type: Easing.InOutSine }
    }
    // El volumen muy alto: ojos apretados un momento
    function apretar() {
        if (!animado || dormido || animApretar.running)
            return;
        animApretar.restart();
    }
    SequentialAnimation {
        id: animApretar
        NumberAnimation { target: yo; property: "ojosX"; to: 1; duration: 80 }
        PauseAnimation { duration: 700 }
        NumberAnimation { target: yo; property: "ojosX"; to: 0; duration: 150 }
    }

    // Bostezo: ojos cerrados, la boca abierta y un estirón
    property real bostezo: 0
    function bostezar() {
        if (!animado || animBostezo.running)
            return;
        animBostezo.restart();
    }
    SequentialAnimation {
        id: animBostezo
        NumberAnimation { target: yo; property: "bostezo"; to: 1; duration: 600; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 700 }
        NumberAnimation { target: yo; property: "bostezo"; to: 0; duration: 450; easing.type: Easing.InOutSine }
    }
    // Al despertar: bosteza
    onDormidoChanged: if (!dormido && animado) bostezar()

    // De madrugada tiene sueño: ojos entornados y algún bostezo
    property bool trasnoche: false
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: {
            const h = new Date().getHours();
            yo.trasnoche = h < 6;
            if (yo.trasnoche && !yo.dormido && Math.random() < 0.25)
                yo.bostezar();
        }
    }

    // Chispitas (el cargador)
    function chispas() {
        if (!animado)
            return;
        soltar("✦", Tema.amarillo, 3);
    }
    // Respirar (más despacio dormido) y mecerse con la música
    property real respiro: 0
    SequentialAnimation on respiro {
        running: yo.animado && yo.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: yo.dormido ? 2600 : 1700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: yo.dormido ? 2600 : 1700; easing.type: Easing.InOutSine }
    }
    // Con música, cabecea despacio: baja la cabeza, vuelve y espera un poco
    property real cabeceo: 0            // 0..1 (1 = abajo)
    SequentialAnimation on cabeceo {
        running: yo.animado && yo.contento && !yo.dormido && yo.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 900; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 180 }
    }
    onContentoChanged: if (!contento) cabeceo = 0

    // --------------------------------------------------------- El dibujo
    Item {
        id: cuerpo
        width: yo.tam
        height: yo.tam
        y: (-yo.salto + yo.cabeceo * 1.3) * yo.u
        x: yo.sacudida * 0.9 * yo.u
        rotation: inclinado + yo.giro
        readonly property real inclinado: yo.dormido ? -12 : yo.sacudida * 6
        transform: Scale {
            origin.x: cuerpo.width / 2
            origin.y: cuerpo.height
            xScale: 1 + yo.respiro * 0.015 - yo.bostezo * 0.04
            yScale: 1 + yo.respiro * 0.035 + yo.bostezo * 0.09 - yo.cabeceo * 0.06
        }

        // El aura: la brasa de dentro que se escapa (un halo detrás) y la
        // corona del eclipse, que asoma por el lado de la sombra
        Item {
            id: aura
            anchors.fill: parent
            z: -1
            // 0..1: en calma respira; con música, golpea al ritmo
            property real fuerza: yo.dormido ? 0.15
                : yo.contento ? 0.6 + yo.cabeceo * 0.4
                : 0.35 + yo.respiro * 0.25 + yo.encendido * 0.65 + yo.asombro * 0.3
            Behavior on fuerza { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Shape {
                anchors.fill: parent
                opacity: aura.fuerza
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 12 * yo.u; centerY: 12.5 * yo.u; centerRadius: (15 + aura.fuerza * 2) * yo.u
                        focalX: 12 * yo.u; focalY: 12.5 * yo.u
                        GradientStop { position: 0.58; color: Qt.rgba(yo.brasa.r, yo.brasa.g, yo.brasa.b, 0.85) }
                        GradientStop { position: 0.76; color: Qt.rgba(yo.brasa.r, yo.brasa.g, yo.brasa.b, 0.32) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    startX: 12 * yo.u; startY: (12.5 - 17) * yo.u
                    PathArc { x: 12 * yo.u; y: (12.5 + 17) * yo.u; radiusX: 17 * yo.u; radiusY: 17 * yo.u }
                    PathArc { x: 12 * yo.u; y: (12.5 - 17) * yo.u; radiusX: 17 * yo.u; radiusY: 17 * yo.u }
                }
            }
            // La corona: un filo de luz por la derecha, detrás del disco
            Shape {
                anchors.fill: parent
                opacity: 0.35 + aura.fuerza * 0.65
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.lighter(yo.brasa, 1.25)
                    strokeWidth: (0.7 + aura.fuerza * 0.6) * yo.u
                    fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: 13.5 * yo.u; startY: 1.85 * yo.u
                    PathArc { x: 13.5 * yo.u; y: 23.15 * yo.u; radiusX: 10.7 * yo.u; radiusY: 10.7 * yo.u }
                }
            }
        }

        // La luna
        Rectangle {
            id: disco
            x: 2 * yo.u; y: 2.5 * yo.u
            width: 20 * yo.u; height: width
            radius: width / 2
            color: yo.luna
            opacity: yo.dormido ? 0.8 : 1
            Behavior on opacity { NumberAnimation { duration: 800 } }
        }
        // La sombra: media luna a oscuras por la derecha (un eclipse), sin
        // salirse del disco: el borde del disco y, de vuelta, una curva
        Shape {
            anchors.fill: parent
            opacity: yo.dormido ? 0.8 : 1
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.32)
                startX: 12 * yo.u; startY: 2.5 * yo.u
                PathArc { x: 12 * yo.u; y: 22.5 * yo.u; radiusX: 10 * yo.u; radiusY: 10 * yo.u }
                PathArc { x: 12 * yo.u; y: 2.5 * yo.u; radiusX: 4.2 * yo.u; radiusY: 10 * yo.u; direction: PathArc.Counterclockwise }
            }
        }
        // Cráteres, hondos
        Rectangle {
            x: 5.2 * yo.u; y: 5.6 * yo.u
            width: 3 * yo.u; height: width; radius: width / 2
            color: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.26)
        }
        Rectangle {
            x: 15.6 * yo.u; y: 17.2 * yo.u
            width: 2.2 * yo.u; height: width; radius: width / 2
            color: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.24)
        }
        Rectangle {
            x: 10.4 * yo.u; y: 19.4 * yo.u
            width: 1.3 * yo.u; height: width; radius: width / 2
            color: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.2)
        }

        // La cicatriz: un tajo con sus puntos, en la mejilla izquierda
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.5
            ShapePath {
                strokeColor: yo.tinta; strokeWidth: 0.8 * yo.u
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 4.8 * yo.u; startY: 14.6 * yo.u
                PathLine { x: 7.8 * yo.u; y: 18.4 * yo.u }
                PathMove { x: 5.3 * yo.u; y: 16.6 * yo.u }
                PathLine { x: 6.6 * yo.u; y: 15.6 * yo.u }
                PathMove { x: 6.3 * yo.u; y: 17.9 * yo.u }
                PathLine { x: 7.6 * yo.u; y: 16.9 * yo.u }
            }
        }

        // Las cejas, en V (fruncidas); preocupado, al revés. Siguen a la
        // mirada un poco y se esconden con los ojos cerrados
        Shape {
            id: cejas
            visible: !yo.cerrados
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real dx: yo.mx * 1.2
            readonly property real dy: yo.my * 0.8 - yo.asombro * 1.4 + yo.cabeceo * 0.9
            // 1 = ceño · -1 = preocupado · con música, casi rectas
            readonly property real ceno: yo.preocupado ? -0.8 : yo.felices ? 0.35 : 1
            ShapePath {
                strokeColor: yo.tinta; strokeWidth: 1.5 * yo.u
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: (6.6 + cejas.dx) * yo.u; startY: (9.6 + cejas.dy - cejas.ceno * 0.6) * yo.u
                PathLine { x: (10.8 + cejas.dx) * yo.u; y: (9.6 + cejas.dy + cejas.ceno * 1.2) * yo.u }
                PathMove { x: (17.4 + cejas.dx) * yo.u; y: (9.6 + cejas.dy - cejas.ceno * 0.6) * yo.u }
                PathLine { x: (13.2 + cejas.dx) * yo.u; y: (9.6 + cejas.dy + cejas.ceno * 1.2) * yo.u }
            }
        }

        // Los ojos abiertos (óvalos), salvo contento o dormido
        Repeater {
            model: [9, 15]
            Rectangle {
                id: ojo
                required property real modelData
                required property int index
                readonly property real abre: yo.parpado * (index === 1 ? yo.guinando : 1) * (yo.trasnoche ? 0.6 : 1)
                readonly property real crece: 1 + yo.asombro * 0.45
                visible: !yo.felices && !yo.cerrados && yo.ojosX < 0.5
                // Entornados (más anchos que altos), salvo con el susto
                width: 2.9 * yo.u * crece
                height: Math.max(0.5 * yo.u, (2.4 + yo.asombro * 1.4) * yo.u * crece * abre)
                radius: height / 2
                x: (modelData + yo.mx * 2.2) * yo.u - width / 2
                y: (13 + yo.my * 1.8 + yo.cabeceo * 0.9 + (yo.preocupado ? 0.6 : 0)) * yo.u - height / 2
                color: yo.tinta
                // La brasa: un punto rojo que late despacio
                Rectangle {
                    visible: ojo.abre > 0.45
                    anchors.centerIn: parent
                    width: Math.max(1.5, parent.width * (0.36 + yo.encendido * 0.2)); height: Math.min(width, parent.height * 0.7); radius: width / 2
                    color: yo.encendido > 0.3 ? Qt.lighter(yo.brasa, 1 + yo.encendido * 0.25) : yo.brasa
                    opacity: Math.min(1, 0.75 + yo.respiro * 0.25 + yo.encendido)
                }
            }
        }

        // Contento o con mimos: ojos de «tranquilo» (medio cerrados, con su
        // brasa debajo) y media sonrisa ladeada
        Shape {
            visible: yo.felices
            anchors.fill: parent
            transform: Translate { y: yo.cabeceo * 0.9 * yo.u }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: yo.tinta; strokeWidth: 1.5 * yo.u
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 7.4 * yo.u; startY: 13.2 * yo.u
                PathLine { x: 10.6 * yo.u; y: 13.2 * yo.u }
                PathMove { x: 13.4 * yo.u; y: 13.2 * yo.u }
                PathLine { x: 16.6 * yo.u; y: 13.2 * yo.u }
                // La media sonrisa: plana a la izquierda, sube a la derecha
                PathMove { x: 10 * yo.u; y: 17 * yo.u }
                PathQuad { x: 14.6 * yo.u; y: 15.6 * yo.u; controlX: 13 * yo.u; controlY: 17.4 * yo.u }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: yo.brasa
                startX: 7.9 * yo.u; startY: 13.9 * yo.u
                PathArc { x: 10.1 * yo.u; y: 13.9 * yo.u; radiusX: 1.1 * yo.u; radiusY: 0.8 * yo.u; direction: PathArc.Counterclockwise }
                PathLine { x: 7.9 * yo.u; y: 13.9 * yo.u }
                PathMove { x: 13.9 * yo.u; y: 13.9 * yo.u }
                PathArc { x: 16.1 * yo.u; y: 13.9 * yo.u; radiusX: 1.1 * yo.u; radiusY: 0.8 * yo.u; direction: PathArc.Counterclockwise }
                PathLine { x: 13.9 * yo.u; y: 13.9 * yo.u }
            }
        }

        // Dormido o bostezando: ojos cerrados (‿ ‿)
        Shape {
            visible: yo.cerrados
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: yo.tinta; strokeWidth: 1.3 * yo.u
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 7.4 * yo.u; startY: 13.6 * yo.u
                PathArc { x: 10.6 * yo.u; y: 13.6 * yo.u; radiusX: 1.8 * yo.u; radiusY: 1.3 * yo.u; direction: PathArc.Counterclockwise }
                PathMove { x: 13.4 * yo.u; y: 13.6 * yo.u }
                PathArc { x: 16.6 * yo.u; y: 13.6 * yo.u; radiusX: 1.8 * yo.u; radiusY: 1.3 * yo.u; direction: PathArc.Counterclockwise }
            }
        }

        // Risita o apretando: ojos > < (con una sonrisa abierta)
        Shape {
            visible: yo.ojosX >= 0.5 && !yo.cerrados
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: yo.tinta; strokeWidth: 1.4 * yo.u
                fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                startX: 7.6 * yo.u; startY: 11.8 * yo.u
                PathLine { x: 10.2 * yo.u; y: 13.3 * yo.u }
                PathLine { x: 7.6 * yo.u; y: 14.8 * yo.u }
                PathMove { x: 16.4 * yo.u; y: 11.8 * yo.u }
                PathLine { x: 13.8 * yo.u; y: 13.3 * yo.u }
                PathLine { x: 16.4 * yo.u; y: 14.8 * yo.u }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: yo.tinta
                startX: 10.4 * yo.u; startY: 16.2 * yo.u
                PathLine { x: 13.6 * yo.u; y: 16.2 * yo.u }
                PathArc { x: 10.4 * yo.u; y: 16.2 * yo.u; radiusX: 1.6 * yo.u; radiusY: 1.5 * yo.u }
            }
        }

        // Bostezo: la boca abierta (una «o»)
        Rectangle {
            visible: yo.bostezo > 0.05 && !yo.dormido
            width: (1.4 + yo.bostezo * 1.4) * yo.u
            height: (1.2 + yo.bostezo * 2.4) * yo.u
            radius: width / 2
            x: 12 * yo.u - width / 2
            y: 17.4 * yo.u - height / 2
            color: yo.tinta
        }

        // Preocupado: boca recta y una gota de sudor
        Rectangle {
            visible: yo.preocupado && !yo.felices && !yo.cerrados && yo.ojosX < 0.5 && yo.bostezo < 0.05
            x: 10.8 * yo.u; y: 17 * yo.u
            width: 2.4 * yo.u; height: 1.1 * yo.u; radius: height / 2
            color: yo.tinta
        }
        Rectangle {
            visible: yo.preocupado && !yo.dormido
            x: 18.6 * yo.u; y: (5.5 + gota.baja * 3) * yo.u
            width: 2.2 * yo.u; height: 3 * yo.u
            radius: width / 2
            topLeftRadius: width * 0.1
            rotation: 20
            color: "#8ecbf0"
            opacity: 1 - gota.baja * 0.6
            QtObject { id: gota; property real baja: 0 }
            SequentialAnimation {
                running: yo.preocupado && !yo.dormido && yo.animado && yo.visible
                loops: Animation.Infinite
                NumberAnimation { target: gota; property: "baja"; from: 0; to: 1; duration: 1600; easing.type: Easing.InQuad }
                PauseAnimation { duration: 700 }
            }
        }
    }

    // Qué ojos lleva (de más a menos importante)
    readonly property bool cerrados: dormido || bostezo > 0.5
    // (con música no sonríe: sigue con su cara seria y solo cabecea)
    readonly property bool felices: false

    // Partículas (las chispas del cargador) suben y se desvanecen
    property int _siguiente: 0
    function soltar(simbolo, color, cuantas) {
        for (let i = 0; i < cuantas; i++) {
            particulas.itemAt(_siguiente)?.lanzar(simbolo, color, i * 160);
            _siguiente = (_siguiente + 1) % 6;
        }
    }
    Repeater {
        id: particulas
        model: 6
        Texto {
            id: particula
            property real sube: 0
            property real lado: 0
            visible: sube > 0 && sube < 1
            x: (12 + lado * 9 + lado * sube * 3) * yo.u - width / 2
            y: (3 - sube * 9) * yo.u - height / 2
            font.pixelSize: Math.max(8, 6.5 * yo.u)
            opacity: Math.sin(sube * Math.PI)
            scale: 0.7 + sube * 0.5
            function lanzar(simbolo, color, retraso) {
                text = simbolo;
                particula.color = color;
                lado = Math.random() * 2 - 1;
                espera.duration = retraso;
                vuelo.restart();
            }
            SequentialAnimation {
                id: vuelo
                PauseAnimation { id: espera; duration: 0 }
                NumberAnimation { target: particula; property: "sube"; from: 0.001; to: 0.999; duration: 1300; easing.type: Easing.OutQuad }
                PropertyAction { target: particula; property: "sube"; value: 0 }
            }
        }
    }

    // Dormido: las «z» suben y se desvanecen, una detrás de otra
    Repeater {
        model: 2
        Texto {
            id: zeta
            required property int index
            visible: yo.dormido && yo.animado
            property real sube: 0
            x: (19 + sube * 3) * yo.u
            y: (4 - sube * 7) * yo.u
            text: "z"
            font.pixelSize: Math.max(7, (5 + sube * 3) * yo.u)
            color: yo.luna
            opacity: Math.sin(sube * Math.PI) * 0.9
            SequentialAnimation on sube {
                running: zeta.visible && yo.visible
                loops: Animation.Infinite
                PauseAnimation { duration: zeta.index * 1300 }
                NumberAnimation { from: 0; to: 1; duration: 2600 }
                PauseAnimation { duration: (1 - zeta.index) * 1300 }
            }
        }
    }
}
