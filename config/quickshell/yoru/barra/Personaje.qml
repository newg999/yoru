// ============================================================================
//  Personaje — la lunita de Yoru (夜, «noche»): vive en la isla y reacciona
//  a lo que pasa. Dibujada con formas, en una rejilla de 24×24 que escala.
//
//        ╭───────╮
//      ╭─╯ °     ╰─╮        un disco claro con dos cráteres, que respira
//      │   ●   ●   │        ojos: parpadean, miran alrededor y, con el
//      │     ‿     │        ratón encima, lo siguen
//      ╰─╮     ° ╭─╯
//        ╰───────╯
//
//    contento     hay música: ojos ^ ^, mofletes, sonrisa y se mece al ritmo
//    dormido      el equipo lleva un rato sin usarse: ojos cerrados y «z z»
//    preocupado   poca batería: una gota de sudor
//    sorpresa()   llega un aviso: un saltito con los ojos muy abiertos
//    guino()      guiña un ojo y da un brinco
//    jugar()      al hacerle clic: cada vez una cosa (guiño, saltitos, una
//                 vuelta entera o una risita con los ojos > <)
//    mimos        pasarle el ratón por encima de lado a lado (interactivo):
//                 cierra los ojos contenta, se sonroja y suelta corazones
//    bostezar()   al despertar (y de madrugada, de vez en cuando)
//    mirarHacia() mira un momento a un sitio (al cambiar de escritorio)
//    apretar()    ojos > < un momento (el volumen muy alto)
//    chispas()    unas chispitas (al enchufar el cargador)
//    De madrugada (0-6 h) tiene sueño: ojos entornados. Con música, de vez
//    en cuando le sale una notita.
//    mirada       hacia dónde mira (-1..1 en x e y); «siguiendo» = la manda
//                 quien lo usa (el ratón); si no, mira por su cuenta
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

    property color luna: Tema.texto
    property color tinta: Tema.oscuro
    property bool animado: Ajustes.animaciones

    width: tam
    height: tam
    readonly property real u: tam / 24

    // ------------------------------------------------------------ Mirada
    // La de verdad (suave): la que manda quien lo usa o la suya propia
    property point ojeada: Qt.point(0, 0)
    readonly property point objetivo: dormido ? Qt.point(0, 0.3) : siguiendo ? mirada : ojeada
    property real mx: objetivo.x
    property real my: objetivo.y
    Behavior on mx { NumberAnimation { duration: yo.siguiendo ? 90 : 420; easing.type: Easing.OutCubic } }
    Behavior on my { NumberAnimation { duration: yo.siguiendo ? 90 : 420; easing.type: Easing.OutCubic } }
    // Por su cuenta: de vez en cuando mira a algún lado y vuelve al frente
    Timer {
        running: yo.animado && !yo.dormido && !yo.siguiendo && yo.visible
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
            NumberAnimation { target: yo; property: "salto"; to: 4.5; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: yo; property: "asombro"; to: 1; duration: 150 }
        }
        NumberAnimation { target: yo; property: "salto"; to: 0; duration: 420; easing.type: Easing.OutBounce }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: yo; property: "asombro"; to: 0; duration: 300 }
    }
    SequentialAnimation {
        id: animGuino
        ParallelAnimation {
            NumberAnimation { target: yo; property: "guinando"; to: 0.08; duration: 90 }
            NumberAnimation { target: yo; property: "salto"; to: 2.5; duration: 140; easing.type: Easing.OutQuad }
        }
        NumberAnimation { target: yo; property: "salto"; to: 0; duration: 260; easing.type: Easing.OutBounce }
        PauseAnimation { duration: 220 }
        NumberAnimation { target: yo; property: "guinando"; to: 1; duration: 140 }
    }

    // Jugar (clic): cada vez una distinta, sin repetir la última
    property int _ultimoJuego: -1
    function jugar() {
        if (!animado)
            return;
        if (dormido) {
            bostezar();
            return;
        }
        let n = Math.floor(Math.random() * 4);
        if (n === _ultimoJuego)
            n = (n + 1) % 4;
        _ultimoJuego = n;
        [animGuino, animSaltitos, animVuelta, animRisita][n].restart();
        if (n === 1)
            soltar("♪", luna, 1);
    }
    property real giro: 0               // grados de más (la vuelta)
    property real sacudida: 0           // -1..1 (la risita)
    property real ojosX: 0              // 0..1: ojos > <
    SequentialAnimation {
        id: animSaltitos
        NumberAnimation { target: yo; property: "salto"; to: 3; duration: 130; easing.type: Easing.OutQuad }
        NumberAnimation { target: yo; property: "salto"; to: 0; duration: 150; easing.type: Easing.InQuad }
        NumberAnimation { target: yo; property: "salto"; to: 2.2; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: yo; property: "salto"; to: 0; duration: 260; easing.type: Easing.OutBounce }
    }
    SequentialAnimation {
        id: animVuelta
        ParallelAnimation {
            NumberAnimation { target: yo; property: "giro"; from: 0; to: 360; duration: 620; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                NumberAnimation { target: yo; property: "salto"; to: 3.5; duration: 310; easing.type: Easing.OutQuad }
                NumberAnimation { target: yo; property: "salto"; to: 0; duration: 310; easing.type: Easing.InQuad }
            }
        }
        PropertyAction { target: yo; property: "giro"; value: 0 }
        ScriptAction { script: yo.mirarHacia(0.6, -0.2) }
    }
    SequentialAnimation {
        id: animRisita
        NumberAnimation { target: yo; property: "ojosX"; to: 1; duration: 80 }
        SequentialAnimation {
            loops: 3
            NumberAnimation { target: yo; property: "sacudida"; to: 1; duration: 70 }
            NumberAnimation { target: yo; property: "sacudida"; to: -1; duration: 140 }
            NumberAnimation { target: yo; property: "sacudida"; to: 0; duration: 70 }
        }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: yo; property: "ojosX"; to: 0; duration: 120 }
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

    // Mimos: ojos ^ ^, mofletes y corazones (mientras siga, se mantiene)
    property real mimado: 0
    function mimar() {
        if (!animado || dormido)
            return;
        if (mimado < 1)
            animMimos.restart();
        soltar("♥", Tema.rojo, 2);
        finMimos.restart();
    }
    NumberAnimation { id: animMimos; target: yo; property: "mimado"; to: 1; duration: 200 }
    Timer { id: finMimos; interval: 1600; onTriggered: animFinMimos.restart() }
    NumberAnimation { id: animFinMimos; target: yo; property: "mimado"; to: 0; duration: 400 }

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
    // Al despertar: bosteza y da un saltito
    onDormidoChanged: if (!dormido && animado) { bostezar(); despertarSalto.start(); }
    Timer { id: despertarSalto; interval: 1800; onTriggered: animSaltitos.restart() }

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
    // Con música, de vez en cuando una notita
    Timer {
        running: yo.animado && yo.contento && !yo.dormido && yo.visible
        repeat: true
        interval: 5000
        onTriggered: {
            interval = 4000 + Math.random() * 5000;
            yo.soltar(Math.random() < 0.5 ? "♪" : "♫", yo.luna, 1);
        }
    }

    // Mimos con el ratón: pasar por encima de lado a lado (tres cambios de
    // sentido seguidos)
    HoverHandler {
        id: mano
        enabled: yo.interactivo
        property real ultimoX: -1
        property int sentido: 0
        property int vueltas: 0
        onPointChanged: {
            const x = point.position.x;
            if (ultimoX < 0 || Math.abs(x - ultimoX) < 1.5) {
                if (ultimoX < 0) ultimoX = x;
                return;
            }
            const s = x > ultimoX ? 1 : -1;
            if (sentido !== 0 && s !== sentido) {
                vueltas++;
                olvidarMimos.restart();
                if (vueltas >= 3) {
                    vueltas = 0;
                    yo.mimar();
                }
            }
            sentido = s;
            ultimoX = x;
        }
        onHoveredChanged: if (!hovered) { ultimoX = -1; sentido = 0; }
    }
    Timer { id: olvidarMimos; interval: 700; onTriggered: mano.vueltas = 0 }

    // Respirar (más despacio dormido) y mecerse con la música
    property real respiro: 0
    SequentialAnimation on respiro {
        running: yo.animado && yo.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: yo.dormido ? 2600 : 1700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: yo.dormido ? 2600 : 1700; easing.type: Easing.InOutSine }
    }
    property real vaiven: 0             // -1..1
    SequentialAnimation on vaiven {
        running: yo.animado && yo.contento && !yo.dormido && yo.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 280; easing.type: Easing.OutSine }
        NumberAnimation { to: 0; duration: 280; easing.type: Easing.InSine }
        NumberAnimation { to: -1; duration: 280; easing.type: Easing.OutSine }
        NumberAnimation { to: 0; duration: 280; easing.type: Easing.InSine }
    }
    onContentoChanged: if (!contento) vaiven = 0

    // --------------------------------------------------------- El dibujo
    Item {
        id: cuerpo
        width: yo.tam
        height: yo.tam
        y: -yo.salto * yo.u + Math.abs(yo.vaiven) * -0.8 * yo.u
        x: yo.sacudida * 0.9 * yo.u
        rotation: inclinado + yo.giro
        readonly property real inclinado: yo.dormido ? -12 : yo.vaiven * 7 + yo.sacudida * 6
        transform: Scale {
            origin.x: cuerpo.width / 2
            origin.y: cuerpo.height
            xScale: 1 + yo.respiro * 0.015 - yo.bostezo * 0.04
            yScale: 1 + yo.respiro * 0.035 + yo.bostezo * 0.09
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
            // Una sombra suave abajo a la derecha: que parezca redonda
            Rectangle {
                x: parent.width * 0.18; y: parent.height * 0.2
                width: parent.width * 0.9; height: width
                radius: width / 2
                color: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.07)
            }
            clip: true
        }
        // Cráteres
        Rectangle {
            x: 5.2 * yo.u; y: 6.6 * yo.u
            width: 2.8 * yo.u; height: width; radius: width / 2
            color: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.12)
        }
        Rectangle {
            x: 16.4 * yo.u; y: 17.4 * yo.u
            width: 1.8 * yo.u; height: width; radius: width / 2
            color: Qt.rgba(yo.tinta.r, yo.tinta.g, yo.tinta.b, 0.1)
        }

        // Los mofletes (contento o sorprendido)
        Repeater {
            model: [6.4, 17.6]
            Rectangle {
                required property real modelData
                x: (modelData - 1.6) * yo.u; y: 15.6 * yo.u
                width: 3.2 * yo.u; height: 1.7 * yo.u
                radius: height / 2
                color: Tema.rojo
                opacity: yo.dormido ? 0 : Math.max(yo.contento ? 0.55 : 0, yo.mimado * 0.75, yo.ojosX * 0.5, yo.asombro * 0.4)
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }

        // Los ojos abiertos (óvalos), salvo contento o dormido
        Repeater {
            model: [9, 15]
            Rectangle {
                id: ojo
                required property real modelData
                required property int index
                readonly property real abre: yo.parpado * (index === 1 ? yo.guinando : 1) * (yo.trasnoche ? 0.55 : 1)
                readonly property real crece: 1 + yo.asombro * 0.35
                visible: !yo.felices && !yo.cerrados && yo.ojosX < 0.5
                width: 2.5 * yo.u * crece
                height: Math.max(0.5 * yo.u, 3.8 * yo.u * crece * abre)
                radius: width / 2
                x: (modelData + yo.mx * 2.2) * yo.u - width / 2
                y: (13 + yo.my * 1.8 + (yo.preocupado ? 0.6 : 0)) * yo.u - height / 2
                color: yo.tinta
                // El brillo del ojo
                Rectangle {
                    visible: yo.tam >= 26 && ojo.abre > 0.5
                    x: parent.width * 0.18; y: parent.height * 0.14
                    width: parent.width * 0.38; height: width; radius: width / 2
                    color: yo.luna
                }
            }
        }

        // Contento o con mimos: ojos ^ ^ y una sonrisa
        Shape {
            visible: yo.felices
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: yo.tinta; strokeWidth: 1.5 * yo.u
                fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 7.2 * yo.u; startY: 13.8 * yo.u
                PathArc { x: 10.8 * yo.u; y: 13.8 * yo.u; radiusX: 1.9 * yo.u; radiusY: 1.9 * yo.u }
                PathMove { x: 13.2 * yo.u; y: 13.8 * yo.u }
                PathArc { x: 16.8 * yo.u; y: 13.8 * yo.u; radiusX: 1.9 * yo.u; radiusY: 1.9 * yo.u }
                PathMove { x: 10.6 * yo.u; y: 16.6 * yo.u }
                PathArc { x: 13.4 * yo.u; y: 16.6 * yo.u; radiusX: 1.7 * yo.u; radiusY: 1.4 * yo.u; direction: PathArc.Counterclockwise }
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
    readonly property bool felices: !cerrados && ojosX < 0.5 && (contento || mimado > 0.5)

    // Partículas: corazones, notas, chispas... suben y se desvanecen
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
