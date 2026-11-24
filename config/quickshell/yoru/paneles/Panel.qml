// ============================================================================
//  Panel — recuadro que se despliega bajo la barra (como los de DMS)
//  Con la barra a la izquierda, sale a su derecha: «izquierda» arriba,
//  «centro» en medio y «derecha» abajo (donde quedan sus botones). Con la
//  barra de tareas (abajo), sube encima de ella.
//
//  La ventana ocupa la pantalla entera pero es invisible: así un clic fuera
//  del recuadro lo cierra.
//  Esc también lo cierra.
//
//    Panel {
//        nombre: "conexion"     // el que abre Paneles.alternar("conexion", ...)
//        lado: "derecha"        // "izquierda", "centro", "derecha"
//                               // o "medio" (en mitad de la pantalla)
//        MiContenido {}
//    }
//
//  Con las islas en píldoras, cuelga de la isla que lo abre (Paneles.islaDe):
//  la isla pierde sus esquinas de abajo, unas curvas unen los dos y el panel
//  baja desde ella como una persiana.
//  Con la barra de Windows (fundido), todos se pegan a ella, sin hueco ni
//  borde entre los dos, y suben desde ella como una persiana.
//
//  Con las islas, sale bajo su isla, suelto (con un pequeño hueco y todas
//  sus esquinas redondas: la isla no cambia), y se despliega hacia abajo.
//  Con «Paneles que salen de su isla» (Ajustes.panelesDesdeIsla), la isla
//  SE CONVIERTE en el panel: se ensancha hacia los lados hasta su ancho
//  (Isla.ensanchar; las islas que tapa se desvanecen), pierde sus esquinas
//  de abajo y toma su color, y el panel crece pegado debajo, como una sola
//  pieza. Los iconos de la isla siguen arriba: pulsar otro cambia de página
//  sin cerrar. Al cerrarse, lo mismo al revés. Si la página nueva cuelga de
//  otra isla, el panel se cierra y se abre desde ella (Paneles.abrirPagina).
//  Con «Gotean de su isla» (Ajustes.panelesGota), como los avisos: bajo la
//  isla nace una gota que cuelga de un cuello, se suelta y se ensancha
//  hasta ser el panel, suelto bajo ella; al cerrarse, la isla se la traga
//  (comun/Gota.qml).
// ============================================================================
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    property string nombre: ""
    property string lado: "derecha"
    property int ancho: 420
    // {x, ancho}: justo debajo de una isla y de su ancho (Paneles.ancla)
    property var ancla: null
    property bool fundido: Ajustes.windows
    default property alias contenido: interior.data

    readonly property bool abierto: Paneles.abierto === nombre && Paneles.pantalla === modelData

    // La isla de la que cuelga (islas en píldoras). Se toma al abrirse (o al
    // cambiar de página) y se guarda al cerrarse, para volver a ella
    property Item isla: null
    // La isla se transforma al ritmo del panel (Isla.aportar)
    readonly property string clave: nombre + "@" + modelData.name
    function tomarIsla() {
        if (!abierto)
            return;
        const nueva = vertical || lado === "medio" ? null : Paneles.islaDe(modelData, nombre, Paneles.seccion);
        if (isla && isla !== nueva) {
            isla.aportar(clave, 0);
            isla.irse(clave, 0);
            isla.ensanchar(clave, 0, 0);
        }
        isla = nueva;
        // La nueva se funde ya (si el panel ya estaba abierto, el progreso
        // no cambia y no se enteraba: se quedaba con sus esquinas y suelta)
        isla?.aportar(clave, fusion());
        isla?.irse(clave, ida);
        ensancharIsla();
    }
    onAbiertoChanged: {
        // Si la ventana ya está puesta (se estaba cerrando), arranca ya
        if (abierto)
            pintado = backingWindowVisible;
        tomarIsla();
        // Y otra vez enseguida: la isla puede estar apareciendo justo ahora
        // (la campana sin avisos nuevos) y aún no contar como visible
        Qt.callLater(tomarIsla);
        if (abierto && Tema.normal > 0 && pintado)
            animSubida.restart();
    }
    // La isla pierde sus esquinas de abajo enseguida al abrirse y no las
    // recupera hasta que el panel casi se ha ido (al ritmo del panel
    // asomaba el fondo entre los dos en la esquina)
    // (sin «salen de su isla» no se funden: el panel va suelto bajo la
    // isla, con su hueco y sus esquinas, y la isla se queda como está)
    function fusion() {
        return desdeIsla ? Math.min(1, progreso * 6) * cerca : 0;
    }
    // Al pasar de una isla a otra, el panel se desliza hasta ella: la isla
    // nueva se funde (y salen las curvas) según llega, no antes (si no,
    // la isla se quedaba sin esquinas y las curvas sueltas a medio camino)
    readonly property real cerca: {
        const lejos = Math.abs(islaX - islaXReal) + Math.abs(islaAncho - islaAnchoReal) / 2;
        return lejos < 1.5 ? 1 : 1 - Math.min(1, lejos / 40);
    }
    onCercaChanged: isla?.aportar(clave, fusion())
    onProgresoChanged: isla?.aportar(clave, fusion())
    Connections {
        target: Paneles
        function onSeccionChanged() {
            // Navegando desde dentro (del centro de control al wifi), el
            // panel se queda en su isla: no salta a la del wifi
            if (ventana.abierto && !(Paneles.anterior && ventana.isla))
                ventana.tomarIsla();
        }
    }
    Component.onDestruction: {
        isla?.aportar(clave, 0);
        isla?.irse(clave, 0);
        isla?.ensanchar(clave, 0, 0);
        Paneles.tapar(clave, null, 0, 0, 0);
    }
    // Dónde está (en la pantalla) y qué ancho tiene
    readonly property real islaXReal: {
        const it = isla;
        if (!it)
            return 0;
        // Se suma el x de todos sus padres: así se entera aunque se mueva un
        // padre (la isla de la hora va centrada y se corre cuando otra cambia
        // de ancho). Y a mano, no con mapToItem: ese cuenta la escala y, con
        // la isla encogida por el clic, el panel se quedaba un poco corrido
        // y nunca terminaba de fundirse con ella
        let x = 0;
        for (let p = it; p; p = p.parent)
            x += p.x;
        return x;
    }
    readonly property real islaAnchoReal: isla?.width ?? 0
    // Lo mismo, pero si el panel ya abierto pasa a otra isla (de la hora al
    // centro de control, p. ej.) se desliza hasta ella en vez de saltar
    readonly property bool asentado: abierto && progreso >= 1
    property real islaX: islaXReal
    property real islaAncho: islaAnchoReal
    Behavior on islaX {
        enabled: ventana.asentado
        NumberAnimation { duration: Tema.normal > 0 ? 460 : 0; easing.type: Easing.OutQuint }
    }
    Behavior on islaAncho {
        enabled: ventana.asentado
        NumberAnimation { duration: Tema.normal > 0 ? 460 : 0; easing.type: Easing.OutQuint }
    }
    // Y su ancho (la página nueva pide otro): se ensancha o estrecha a la vez
    property real anchoSuave: ancho
    Behavior on anchoSuave {
        enabled: ventana.asentado
        NumberAnimation { duration: Tema.normal > 0 ? 460 : 0; easing.type: Easing.OutQuint }
    }
    readonly property int bajoIslas: Tema.margenBarra + Tema.altoBarra
    // El hueco entre la isla y el panel que cuelga de ella
    readonly property int separacion: 6
    readonly property bool vertical: Ajustes.vertical
    readonly property bool abajo: Ajustes.abajo

    // Alto máximo del recuadro en ESTA pantalla (bajo la barra, con margen).
    // Los paneles con listas largas las acortan con esto para caber también
    // en monitores pequeños (1080p, portátiles de 768...)
    readonly property int altoMax: modelData.height - (vertical ? 2 * Tema.margenLados + 12 : Tema.hueco) - 12

    // 0 = cerrado · 1 = abierto. La ventana sigue visible hasta que termina
    // la animación de cierre.
    // Al abrirse, con rebote (como el dock): se pasa un poco de 1 y vuelve,
    // así crece de más y se asienta (colgando de una isla, se ensancha de
    // más). Pegado a la minimalista, sin rebote: baja como una persiana.
    // Al cerrarse, rápido y sin rebote
    property real progreso: abierto && pintado ? 1 : 0
    // La ventana del panel se crea al abrirlo y su primer fotograma tarda
    // (medido: ~70 ms, con el contenido): la animación ya iba por el 15 %
    // cuando se veía y daba un tirón al empezar. Se espera a que la ventana
    // esté en pantalla y haya pintado dos fotogramas, y entonces arranca
    property bool pintado: false
    property int _fotogramas: 0
    FrameAnimation {
        running: ventana.abierto && !ventana.pintado && ventana.backingWindowVisible
        onRunningChanged: ventana._fotogramas = 0
        // (goteando, con uno basta: lo primero que sale es una gota diminuta)
        onTriggered: if (++ventana._fotogramas >= (ventana.puedeGota ? 1 : 2)) ventana.pintado = true
    }
    // (por si acaso: nunca más de 150 ms esperando)
    Timer {
        running: ventana.abierto && !ventana.pintado
        interval: 150
        onTriggered: ventana.pintado = true
    }
    Behavior on progreso {
        NumberAnimation {
            duration: Tema.normal === 0 ? 0
                // (de un panel a otro, deprisa: Paneles.rapido)
                : ventana.puedeGota ? (ventana.abierto ? ventana.durGota : (Paneles.rapido ? 240 : 320))
                : ventana.puedeDesdeIsla ? (ventana.abierto ? ventana.durAbrir : (Paneles.rapido ? 160 : 260))
                : !ventana.abierto ? 170 : ventana.persiana ? ventana.durPersiana : caja.pegado ? 300 : 380
            easing.type: ventana.puedeGota || ventana.puedeDesdeIsla || (ventana.abierto && ventana.persiana) ? Easing.Linear
                : !ventana.abierto ? Easing.InCubic : caja.pegado ? Easing.OutQuint : Easing.OutBack
            easing.overshoot: 1.4
        }
    }

    // ------------------------------------- La isla se convierte en el panel
    // Sobre el mismo progreso (aquí lineal), las dos cosas A LA VEZ (antes
    // iban casi una detrás de otra y el movimiento se paraba a medias), cada
    // una con un muelle, como la Dynamic Island: arranca suave, se pasa un
    // poco y se posa, sin la cola quieta de las curvas Bézier
    //   ensancha  muelle sin rebote (0,36 s): la isla se abre a los lados
    //             hasta el ancho del panel (si rebotara, se bambolearía)
    //   crece     muelle con un 2 % de rebote (0,42 s; 25 ms después): el
    //             panel baja pegado a ella, se pasa unos px y se posa
    //   contenido entra pronto y lo va descubriendo la caja al crecer
    //             (antes salía al 80 %: caja vacía y luego todo de golpe)
    // Al cerrarse, el progreso va de 1 a 0: primero sube el panel y luego la
    // isla vuelve a su ancho
    // (la duración se decide al empezar a abrirse, cuando aún no se sabe de
    // qué isla cuelga: por eso va con lo que ya se sabe, el estilo de barra)
    readonly property bool puedeDesdeIsla: Ajustes.panelesDesdeIsla && !Ajustes.panelesGota && Tema.normal > 0
        && Ajustes.pildoras && !Ajustes.minimalista && !vertical && !abajo && lado !== "medio"
    // «Gotean de su isla»: el progreso (lineal) es el de la gota (Gota.qml)
    readonly property bool puedeGota: Ajustes.panelesGota && Tema.normal > 0
        && Ajustes.pildoras && !Ajustes.minimalista && !vertical && !abajo && lado !== "medio"
    readonly property bool gota: puedeGota && caja.colgado
    readonly property int durGota: Paneles.rapido ? 360 : 480
    // El hueco entre la isla y el panel que ha goteado de ella
    readonly property int huecoGota: 10
    // De dónde gotea: bajo el icono de la página abierta (en la isla de la
    // derecha: el wifi, el volumen...: la ficha «elegida»), o del centro de
    // la isla. Si pulsas otro icono de la misma isla, se va hasta él, y al
    // cerrar la gota vuelve ahí (por eso no cambia mientras se cierra)
    function buscarElegida(it) {
        for (const c of it.children) {
            if (!c.visible)
                continue;
            if (c.elegida === true)
                return c;
            const d = buscarElegida(c);
            if (d)
                return d;
        }
        return null;
    }
    readonly property real fuenteXAhora: {
        const f = isla ? buscarElegida(isla) : null;
        if (!f)
            return islaX + islaAncho / 2;
        let x = f.width / 2;
        for (let p = f; p; p = p.parent)
            x += p.x;
        return x;
    }
    property real fuenteX: fuenteXAhora
    onFuenteXAhoraChanged: if (abierto) fuenteX = fuenteXAhora
    Behavior on fuenteX {
        enabled: ventana.asentado
        NumberAnimation { duration: Tema.normal * 1.4; easing.type: Easing.OutCubic }
    }
    readonly property bool desdeIsla: puedeDesdeIsla && caja.colgado
    function tramo(p, a, b) { return Math.max(0, Math.min(1, (p - a) / (b - a))); }
    // Muelle amortiguado: dónde está a los t segundos (respuesta = lo que
    // tarda una oscilación; amortiguación 1 = sin rebote, < 1 = rebota)
    function muelle(t, respuesta, amort) {
        if (t <= 0)
            return 0;
        const w = 2 * Math.PI / respuesta;
        if (amort >= 1)
            return 1 - Math.exp(-w * t) * (1 + w * t);
        const wd = w * Math.sqrt(1 - amort * amort);
        return 1 - Math.exp(-amort * w * t) * (Math.cos(wd * t) + amort * w / wd * Math.sin(wd * t));
    }
    readonly property int durAbrir: Paneles.rapido ? 320 : 420
    // (al llegar al final, justo 1: el muelle se queda a un pelo)
    function enMuelle(p, retraso, respuesta, amort) {
        return p >= 1 ? 1 : muelle(p * durAbrir / 1000 - retraso, respuesta * durAbrir / 560, amort);
    }
    // Al cerrar, otras curvas (t²): se recoge en cuanto haces clic y se posa
    // con suavidad en la isla
    function cierre(t) { return t * t; }
    // Barra minimalista: el panel baja pegado a ella como una persiana. El
    // mismo muelle, pero sin rebote (pegado a la barra, pasarse quedaba
    // raro) y sin ensanchar: antes OutQuint en 300 ms, que arrancaba de golpe
    readonly property bool persiana: caja.pegado && caja.comoDock && !desdeIsla
    readonly property int durPersiana: Paneles.rapido ? 260 : 340
    readonly property real fPersiana: !abierto || progreso >= 1 ? progreso
        : muelle(progreso * durPersiana / 1000, 0.36 * durPersiana / 440, 1)
    readonly property real fAncho: abierto ? enMuelle(progreso, 0, 0.36, 1) : cierre(tramo(progreso, 0, 0.4))
    readonly property real fAlto: abierto ? enMuelle(progreso, 0.025, 0.42, 0.78) : cierre(tramo(progreso, 0.3, 1))
    // Lo que el panel sobresale de la isla a cada lado (ya abierto)
    readonly property real sobraIzq: Math.max(0, islaX - caja.xFinal)
    readonly property real sobraDer: Math.max(0, caja.xFinal + caja.anchoFinal - islaX - islaAncho)
    // Lo que se ha ensanchado ahora
    readonly property real ensancheIzq: desdeIsla ? sobraIzq * fAncho : 0
    readonly property real ensancheDer: desdeIsla ? sobraDer * fAncho : 0
    function ensancharIsla() {
        isla?.ensanchar(clave, ensancheIzq, ensancheDer);
        Paneles.tapar(clave, isla, islaX - sobraIzq, islaX + islaAncho + sobraDer, desdeIsla ? fAncho : 0);
    }
    onPintadoChanged: if (pintado && abierto && Tema.normal > 0) animSubida.restart()
    onEnsancheIzqChanged: ensancharIsla()
    onEnsancheDerChanged: ensancharIsla()
    onFAnchoChanged: ensancharIsla()
    // Lo que la caja sube por encima del recorte (que la corta justo bajo la
    // barra): así no se ven ni su borde ni sus esquinas de arriba, y sigue
    // recta desde la isla
    readonly property int tapa: Tema.radioPanel + 4
    // (la isla ya no se va: se queda arriba, convertida en la cabeza del panel)
    readonly property real ida: 0
    onIdaChanged: isla?.irse(clave, ida)
    // El progreso sin pasarse de 1: para lo que no debe rebotar (el sitio
    // bajo la barra o la isla y la transparencia)
    readonly property real hasta1: Math.min(1, progreso)

    // Al abrirse, el contenido baja desde un poco más arriba (1 → 0) tras
    // un momento, mientras la caja se despliega de arriba abajo
    property real subida: 0
    SequentialAnimation {
        id: animSubida
        PropertyAction { target: ventana; property: "subida"; value: 1 }
        PauseAnimation { duration: Tema.ms(60) }
        NumberAnimation { target: ventana; property: "subida"; to: 0; duration: Tema.ms(400); easing.type: Easing.OutCubic }
    }

    screen: modelData
    visible: abierto || progreso > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-panel"
    WlrLayershell.layer: WlrLayer.Top
    // Teclado para Esc y para escribir contraseñas
    // Si se cierra porque se abre otro (del wifi al Inicio), lo sigue
    // teniendo mientras se va: si lo soltaba al momento, el teclado volvía un
    // instante a la ventana de detrás y su borde de foco destellaba en blanco
    WlrLayershell.keyboardFocus: abierto || (progreso > 0 && Paneles.abierto !== "")
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Sin desenfoque detrás del recuadro (las islas de la barra sí lo
    // tienen): el de niri no se puede desvanecer, y al ponerse al final de
    // la animación el panel cambiaba de golpe de tono (parecía un parpadeo).

    // Clic fuera = cerrar. Menos en la franja de la barra: ahí los clics
    // pasan a la barra, así que pulsar otro botón con un panel abierto lo
    // abre a la primera (antes el primer clic solo cerraba este)
    mask: Region {
        item: entera
        Region { item: franjaBarra; intersection: Intersection.Subtract }
    }
    Item { id: entera; anchors.fill: parent }
    Item {
        id: franjaBarra
        width: ventana.vertical ? Tema.margenBarra + Tema.anchoBarra : parent.width
        y: ventana.abajo ? parent.height - height : 0
        height: ventana.vertical ? parent.height
            : ventana.abajo ? Tema.altoTareas
            : Ajustes.minimalista ? Tema.altoBarra + 2 : Tema.margenBarra + Tema.altoBarra
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Paneles.cerrar()
    }

    // «Gotean de su isla»: la gota y su cuello, en una capa opaca con la
    // transparencia de los paneles encima; lo que cae sobre la isla se
    // recorta. Ya abierto no se ve: la caja toma su fondo en el mismo sitio.
    // Las capas se preparan en cuanto la ventana sale (mientras espera a
    // estar pintada), no al arrancar la gota: crearlas entonces costaba
    // ~100 ms y la gota salía con un tirón. Y solo del alto que hace falta
    readonly property real altoGoo: Math.min(height, bajoIslas + huecoGota + caja.altoFinal + 24)
    Item {
        width: parent.width
        height: ventana.altoGoo
        visible: ventana.gota
        // Con la transparencia del panel ya abierto (no la de la isla): la
        // gota es el panel desde el principio. Al terminar, la caja toma
        // su fondo justo donde estaba la gota, del mismo color: no se nota
        opacity: ventana.progreso > 0 && ventana.progreso < 1 ? Ajustes.opacidadPaneles : 0
        Item {
            id: gooPanel
            anchors.fill: parent
            layer.enabled: ventana.gota && ventana.visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: huecoIsla
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.1
            }
        }
    }
    Item {
        id: huecoIsla
        width: parent.width
        height: ventana.altoGoo
        visible: false
        layer.enabled: ventana.gota && ventana.visible
        Rectangle {
            x: ventana.islaX
            y: Tema.margenBarra
            width: ventana.islaAncho
            height: ventana.isla?.height ?? Tema.altoBarra
            radius: Tema.radioIsla
            color: "black"
        }
    }
    Gota {
        id: formaPanel
        capa: gooPanel
        f: ventana.gota ? Math.min(1, ventana.progreso) : 0
        sx: ventana.fuenteX
        sy: Tema.margenBarra + (ventana.isla?.height ?? Tema.altoBarra)
        fuenteR: (ventana.isla?.height ?? Tema.altoBarra) / 2
        y0: ventana.bajoIslas + ventana.huecoGota
        xFin: caja.xFinal
        anchoFin: caja.anchoFinal
        altoFin: caja.height
        radioFin: Tema.radioPanel
        r0: 14
        faseGota: 0.4
    }

    // Con la minimalista, el panel baja desde la barra como una persiana: se
    // recorta justo por debajo de ella para no pintarse encima mientras baja.
    // Fundido con la de abajo, igual pero subiendo (y tapando su línea de arriba)
    Item {
        id: recorte
        anchors.fill: parent
        anchors.topMargin: Ajustes.minimalista ? Tema.altoBarra + 2 : caja.colgado ? ventana.bajoIslas : 0
        anchors.bottomMargin: ventana.fundido ? Tema.altoTareas - 1 : 0
        clip: Ajustes.minimalista || ventana.fundido || caja.colgado

        Rectangle {
            id: caja

            readonly property bool anclado: ventana.ancla !== null && !ventana.vertical
            // Colgando de una isla: debajo de ella y al menos de su ancho
            readonly property bool colgado: ventana.isla !== null && !enMedio
            // Colgando, nace del ancho de la isla y se ensancha hasta el suyo
            readonly property real anchoFinal: colgado ? Math.max(anclado ? ventana.ancla.ancho : ventana.anchoSuave, ventana.islaAncho)
                : anclado ? ventana.ancla.ancho : ventana.ancho
            // El ancho al que va (sin animar): el contenido toma ya este y
            // queda centrado mientras la caja se desliza y cambia de ancho
            // (si siguiera el ancho animado, el texto se recolocaba a cada paso)
            readonly property real anchoMeta: colgado ? Math.max(anclado ? ventana.ancla.ancho : ventana.ancho, ventana.islaAnchoReal)
                : anchoFinal
            readonly property real xFinal: Math.round(Math.max(Tema.margenLados, Math.min(parent.width - anchoFinal - Tema.margenLados,
                ventana.islaX + (ventana.islaAncho - anchoFinal) / 2)))
            // Saliendo de la isla: nace de su ancho y se ensancha a la vez que ella
            width: ventana.desdeIsla
                ? Math.round(ventana.islaAncho + ventana.ensancheIzq + ventana.ensancheDer)
                : anchoFinal
            // Lo que sobresale a cada lado de la isla (ahí van las curvas)
            readonly property real sobraIzquierda: colgado ? ventana.islaX - x : 0
            readonly property real sobraDerecha: colgado ? x + width - ventana.islaX - ventana.islaAncho : 0
            // Con las islas, como los paneles del dock: nace sin alto bajo la
            // isla (o la barra) y se estira con rebote (progreso pasa de 1)
            readonly property real altoFinal: interior.implicitHeight + 32
            height: ventana.gota ? altoFinal
                : ventana.desdeIsla
                ? ventana.tapa + Math.max(0, Math.round(altoFinal * ventana.fAlto))
                : comoDock ? Math.max(0, altoFinal * (ventana.persiana ? ventana.fPersiana : ventana.progreso)) : altoFinal
            // (la minimalista también: pegado a su franja, se despliega igual)
            readonly property bool comoDock: colgado || (Ajustes.conPildoras && (!pegado || Ajustes.minimalista) && !enMedio && !ventana.vertical && !ventana.abajo)
            readonly property bool enMedio: ventana.lado === "medio"
            // Con la barra minimalista, pegado a ella: sin hueco, esquinas
            // rectas, su mismo fondo y un borde fino
            readonly property bool pegado: (Ajustes.minimalista || ventana.fundido) && !enMedio
            readonly property bool fundido: ventana.fundido && !enMedio
            readonly property string sitio: ventana.lado

            // Al abrirse se desliza un poco desde la barra (abajo: hacia arriba)
            readonly property real deslizar: (1 - ventana.hasta1) * 14

            x: enMedio ? Math.round((parent.width - width) / 2)
                // Centrado bajo la isla, sin salirse de la pantalla
                : ventana.desdeIsla ? Math.round(ventana.islaX - ventana.ensancheIzq)
                : colgado ? xFinal
                : anclado ? ventana.ancla.x
                : ventana.vertical ? Tema.hueco - deslizar
                // Pegado al borde de la pantalla, su borde de ese lado queda
                // fuera (si no, se veía una línea fina contra el borde)
                : sitio === "izquierda" ? (pegado ? -border.width : Tema.margenLados)
                : sitio === "centro" ? (parent.width - width) / 2
                : parent.width - width - (pegado ? -border.width : Tema.margenLados)
            // (en el recorte, que con la minimalista empieza bajo la barra)
            y: enMedio ? Math.round((ventana.height - height) / 2) - recorte.y
                // Fundido con la de abajo, como los de Windows 11: todos suben
                // lo mismo (un tramo corto, saliendo de detrás de la barra) y se
                // funden; antes subían todo su alto en el mismo tiempo, y el
                // Inicio (alto) iba mucho más rápido que el centro de control
                : fundido ? parent.height - height + (1 - ventana.hasta1) * 56
                : ventana.desdeIsla ? -ventana.tapa
                : ventana.gota ? ventana.huecoGota
                : colgado ? ventana.separacion
                : comoDock ? (pegado ? 0 : Tema.hueco)
                : pegado ? -(1 - ventana.hasta1) * height
                : ventana.abajo ? parent.height - height - Tema.hueco + deslizar
                : !ventana.vertical ? Tema.hueco - deslizar
                : sitio === "izquierda" ? Tema.margenLados + 6
                : sitio === "centro" ? Math.round((parent.height - height) / 2)
                : parent.height - height - Tema.margenLados - 6

            // Pegado a la barra baja como una persiana (ver «recorte»), sin
            // fundido ni encoger (se despegaría de ella)
            // (con las islas, al cerrarse se funde en el último tramo: si no,
            // quedaba una franja oscura bajo la isla en los últimos fotogramas)
            // (goteando: aparece encima de la gota cuando ya casi es él)
            opacity: ventana.gota ? formaPanel.cl((formaPanel.pB - 0.5) / 0.5)
                : ventana.desdeIsla ? 1
                : comoDock ? (ventana.abierto ? 1 : Math.min(1, ventana.progreso * 2.5))
                : fundido ? Math.min(1, ventana.hasta1 * 1.6)
                : pegado ? 1 : ventana.hasta1
            scale: pegado || comoDock ? 1 : (enMedio ? 0.94 : 0.96) + (enMedio ? 0.06 : 0.04) * ventana.progreso
            transformOrigin: enMedio ? Item.Center : ventana.vertical ? Item.Left : ventana.abajo ? Item.Bottom : Item.Top

            radius: ventana.desdeIsla ? Math.min(Tema.radioPanel, Math.max(0, (height - ventana.tapa) / 2)) : Tema.radioPanel
            // Pegado a la barra minimalista: todo recto, como ella
            // (fundido con la de abajo: redondo arriba, recto contra ella y
            // contra el borde de la pantalla)
            // (colgado de una isla: recto donde sigue su borde)
            topLeftRadius: pegado && (!fundido || sitio === "izquierda") ? 0 : radius
            topRightRadius: pegado && (!fundido || sitio === "derecha") ? 0 : radius
            bottomLeftRadius: pegado ? 0 : radius
            bottomRightRadius: pegado ? 0 : radius
            // (goteando, su fondo es la gota hasta que termina: si los dos se
            // fundían, a medias se veía más oscuro o más claro)
            color: ventana.gota && ventana.progreso < 1 ? "transparent" : Tema.panel
            border.width: pegado ? Tema.borde(1) : Tema.borde(2)
            border.color: pegado ? Tema.claro(0.08) : Tema.panelBorde
            clip: true

            // Como el dock: un brillo suave del acento arriba (colgando de
            // una isla, no: se notaba la costura con ella y con las curvas)
            Rectangle {
                // (saliendo de la isla, tampoco: el cuerpo quedaba más claro
                // que la isla, que es su cabeza)
                visible: caja.comoDock && !caja.pegado && !ventana.desdeIsla
                anchors.fill: parent
                topLeftRadius: caja.topLeftRadius
                topRightRadius: caja.topRightRadius
                bottomLeftRadius: caja.bottomLeftRadius
                bottomRightRadius: caja.bottomRightRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Tema.claro(0.10) }
                    GradientStop { position: Math.min(1, 140 / Math.max(1, caja.altoFinal)); color: "transparent" }
                }
            }

            // Pegado: sin borde del lado de la barra (se funde con ella)
            Rectangle {
                visible: caja.pegado && caja.border.width > 0
                x: caja.border.width
                y: caja.fundido ? parent.height - height : 0
                width: parent.width - 2 * caja.border.width
                height: caja.border.width
                color: caja.color
                z: 1
            }

            // Solo con el panel ya abierto (al cambiar de sección o página): al
            // abrirse toma su tamaño directamente, sin arrastrar el de la última vez
            Behavior on height {
                enabled: ventana.abierto && ventana.progreso === 1 && !animSubida.running
                NumberAnimation { duration: Tema.rebote * 0.75; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            }

            // Los clics dentro del recuadro no lo cierran
            MouseArea {
                anchors.fill: parent
            }

            FocusScope {
                id: foco
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Paneles.atras()

                // Colgando, el contenido no se mueve ni se recoloca mientras el
                // recuadro se ensancha: está ya en su sitio y aparece con un fundido
                Item {
                    id: interior
                    x: 16 + (caja.colgado ? caja.xFinal - caja.x + Math.round((caja.anchoFinal - caja.anchoMeta) / 2) : 0)
                    // (saliendo de la isla, la caja empieza «tapa» más arriba, bajo la barra)
                    y: 16 + (ventana.desdeIsla ? ventana.tapa : 0)
                    width: caja.anchoMeta - 32
                    implicitHeight: childrenRect.height
                    // El contenido llega mientras la caja se despliega hacia
                    // abajo: se funde y baja un poco desde arriba (ventana.subida)
                    // (la opacidad no depende de «subida»: al cambiar en cada
                    // fotograma reiniciaba el fundido y el contenido no llegaba
                    // hasta que la caja se paraba)
                    readonly property bool mostrar: ventana.abierto && ventana.progreso > (ventana.desdeIsla ? 0.3 : 0.2)
                    opacity: !caja.comoDock || mostrar ? 1 : 0
                    Behavior on opacity {
                        enabled: caja.comoDock
                        NumberAnimation { duration: interior.mostrar ? (ventana.desdeIsla ? 220 : 260) : 90; easing.type: Easing.OutCubic }
                    }
                    transform: Translate {
                        y: caja.comoDock ? -ventana.subida * (ventana.desdeIsla ? 10 : 14) : 0
                    }
                }
            }
        }
    }

    // Las curvas que unen la isla con el panel, a cada lado de la isla donde
    // el panel sobresale (crecen con él al abrirse)
    component Curva: Shape {
        property bool derecha: false
        property real r: 0
        visible: false      // (ya no se funde con la isla)
        // Se funden con la caja al cerrarse (si no, quedaban las esquinas)
        opacity: caja.opacity
        y: ventana.bajoIslas - r
        width: r
        height: r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: caja.color
            strokeWidth: -1
            // La esquina de abajo pegada a la isla, hacia fuera un cuarto de círculo
            startX: derecha ? 0 : r; startY: 0
            PathLine { x: derecha ? 0 : r; y: r }
            PathLine { x: derecha ? r : 0; y: r }
            PathArc {
                x: derecha ? 0 : r; y: 0
                radiusX: r; radiusY: r
                direction: derecha ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }
    // (al llegar de otra isla, solo cuando el panel ya está bajo ella)
    readonly property real crece: cerca
    Curva {
        r: Math.min(12, Math.max(0, caja.sobraIzquierda / 2)) * ventana.crece
        x: ventana.islaX - r
    }
    Curva {
        derecha: true
        r: Math.min(12, Math.max(0, caja.sobraDerecha / 2)) * ventana.crece
        x: ventana.islaX + ventana.islaAncho
    }
}
