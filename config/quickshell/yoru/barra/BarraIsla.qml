// ============================================================================
//  BarraIsla — una sola isla, una píldora como las de Yoru, arriba en el
//  centro: en reposo, la lunita y la hora. Al abrirla se transforma (sin
//  rebotes) en sus páginas; cuando pasa algo, cambia de forma un momento
//  para enseñarlo. (Ajustes › Barra y dock › Isla)
//
//    reposo     ( ◕‿◕  18:42 )                   (grabando: un punto rojo)
//
//    abierta    ╭──────────────────────────────╮
//               │  Sistema ‹  Menú  › Segundo  │  tres páginas: se pasa de
//               │          plano               │  una a otra deslizando
//               │   ◕‿◕  18:42                 │
//               │        jueves, 13 de nov.    │  Menú: buscar, la canción,
//               │  [󰍉 Buscar             ]     │  volumen, brillo y botones
//               │  [████ 󰕾 ──────── 80%]       │  Sistema: CPU, memoria,
//               │   ⏺   ⧉   ▦   󰅍            │  temperatura, encendido
//               │          •  ●  •             │  Segundo plano: la bandeja
//               ╰──────────────────────────────╯
//
//    Gestos (touchpad, rueda o arrastrando con el ratón):
//      clic · Mod+X · deslizar abajo   abrir (en el Menú)
//      rueda del ratón (cerrada)       escritorio anterior / siguiente
//      deslizar a la derecha           Sistema
//      deslizar a la izquierda         Segundo plano
//      abierta: de lado = otra página · hacia arriba, Esc o clic fuera = cerrar
//
//    Un momento, al pasar algo:
//      aviso      ( [icono]  TELEGRAM · Ana · ¿bajas ya? )  4,5 s (ratón encima: espera)
//      volumen    ( 󰕾  ━━━━━━━━━━━○──────  45% )           1,5 s (brillo y micro igual)
//      canción    ( [carátula]  Título · Artista   ılıl )    3 s al empezar una
//      cargador   ( 󰂄  Cargando · 54% )                      2,5 s
//
//  La luna (Personaje.qml): contenta con música, se asusta un poco con cada
//  aviso, suda con poca batería, se duerme si no usas el equipo y te sigue
//  con la mirada. Clic en ella: juega · pasarle el ratón de lado a lado:
//  mimos · mira hacia el escritorio al que vas · chispas con el cargador. Los paneles que se abren desde fuera (calendario, wifi...)
//  cuelgan de la isla (Paneles.islaUnica).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs.comun

PanelWindow {
    id: barra
    required property ShellScreen modelData
    screen: modelData

    // Del alto de la pantalla (transparente): así un clic fuera la cierra.
    // Anclada arriba y a los lados (con los cuatro, niri no respeta la
    // franja reservada). Solo reserva lo de la barra
    anchors { top: true; left: true; right: true }
    implicitHeight: modelData.height
    exclusiveZone: Tema.zonaBarra
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: abierta ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Qué recibe clics: la isla; abierta, toda la pantalla (un clic fuera
    // la cierra); con otro panel abierto, la franja de arriba (un clic al
    // lado de la isla lo cierra, como con las islas de siempre)
    mask: Niri.overview ? vacia : abierta ? regionTodo : algoAbierto ? regionFranja : region
    Region { id: vacia }
    Region { id: region; item: isla }
    Region { id: regionFranja; item: franja }
    Region { id: regionTodo; item: todo }
    readonly property bool algoAbierto: Paneles.abierto !== ""
    Item { id: todo; anchors.fill: parent }
    Item {
        id: franja
        width: parent.width
        height: Tema.margenBarra + Tema.altoBarra
    }
    MouseArea {
        anchors.fill: parent
        enabled: barra.abierta || barra.algoAbierto
        onClicked: barra.abierta ? (barra.abierta = false) : Paneles.cerrar()
    }
    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : desenfoque
    Region { id: desenfoque; item: isla; radius: isla.radius }

    // La cafeína (Despierto) se agarra a una ventana visible: esta
    IdleInhibitor {
        window: barra
        enabled: Despierto.activo && barra.backingWindowVisible
    }
    // Sin usar el equipo un rato: la luna se duerme
    IdleMonitor {
        id: reposo
        timeout: 180
        respectInhibitors: true
    }

    // Los paneles cuelgan de la isla
    Component.onCompleted: Paneles.islaUnica = Object.assign({}, Paneles.islaUnica, {[modelData.name]: isla})

    readonly property bool enfocada: (Niri.escritorios.find(e => e.is_focused)?.output ?? modelData.name) === modelData.name
    readonly property bool panelAbierto: algoAbierto && Paneles.pantalla === modelData

    // ------------------------------------------------- Abierta y páginas
    // 0 = Sistema · 1 = Menú · 2 = Segundo plano
    property bool abierta: false
    property int pagina: 1
    readonly property var nombresPaginas: ["Sistema", "Menú", "Segundo plano"]
    function abrir(p) {
        terminar();
        if (algoAbierto)
            Paneles.cerrar();
        pagina = p ?? 1;
        abierta = true;
    }
    function pasar(paso) {
        pagina = Math.max(0, Math.min(2, pagina + paso));
    }
    // El teclado, con la página que se ve (en el Menú, al buscador)
    onPaginaChanged: if (abierta) enfocar()
    function enfocar() {
        if (pagina === 1)
            buscar.forceActiveFocus();
        else
            cajaPaginas.forceActiveFocus();
    }
    onAbiertaChanged: {
        if (abierta) {
            buscar.text = "";
            enfocar();
            Sesion.leerEncendido();
            luna.guino();
        }
    }
    Connections {
        target: Paneles
        function onMenuIsla(pantalla, pagina) {
            if (pantalla !== barra.modelData.name)
                return;
            // Abierta en esa página: se cierra; en otra: se pasa a ella
            if (barra.abierta && barra.pagina === pagina)
                barra.abierta = false;
            else if (barra.abierta)
                barra.pagina = pagina;
            else
                barra.abrir(pagina);
        }
    }
    // Al abrir un panel (o los Ajustes), la isla se cierra
    onAlgoAbiertoChanged: if (algoAbierto) abierta = false
    function hacer(f) {
        abierta = false;
        f();
    }

    // Gestos con el touchpad o la rueda: se suma lo deslizado y, al pasar
    // de un tanto, cuenta como un gesto (y espera un poco antes del
    // siguiente, para que un deslizamiento largo no pase dos páginas)
    property real _dx: 0
    property real _dy: 0
    Timer { id: calma; interval: 380 }
    Timer { id: olvido; interval: 200; onTriggered: { barra._dx = 0; barra._dy = 0; } }
    function gesto(e) {
        // La rueda del ratón (saltos fijos, sin pixelDelta) sobre la isla
        // cerrada: escritorio anterior / siguiente. Lo demás (el touchpad,
        // que manda desplazamientos finos) son gestos
        const touchpad = e.pixelDelta.x !== 0 || e.pixelDelta.y !== 0;
        if (!touchpad && !abierta && e.angleDelta.x === 0) {
            Niri.accion(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down");
            return;
        }
        if (calma.running)
            return;
        const d = touchpad ? Qt.point(e.pixelDelta.x * 2.5, e.pixelDelta.y * 2.5) : e.angleDelta;
        _dx += d.x;
        _dy += d.y;
        olvido.restart();
        const umbral = 110;
        if (Math.abs(_dx) >= umbral && Math.abs(_dx) > Math.abs(_dy)) {
            const derecha = _dx > 0;
            _dx = 0; _dy = 0;
            calma.restart();
            if (abierta) pasar(derecha ? -1 : 1);
            else abrir(derecha ? 0 : 2);
        } else if (Math.abs(_dy) >= umbral) {
            const abajo = _dy < 0;
            _dx = 0; _dy = 0;
            calma.restart();
            if (!abierta && abajo) abrir(1);
            else if (abierta && !abajo) abierta = false;
        }
    }
    // Arrastrar con el ratón: lo mismo
    function arrastre(dx, dy) {
        if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) {
            if (abierta) pasar(dx > 0 ? -1 : 1);
            else abrir(dx > 0 ? 0 : 2);
            return true;
        }
        if (Math.abs(dy) > 24) {
            if (!abierta && dy > 0) abrir(1);
            else if (abierta && dy < 0) abierta = false;
            return true;
        }
        return false;
    }

    // ------------------------------------------------------- Estado
    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [barra.salida, barra.entrada] }
    readonly property real volumen: salida?.audio?.volume ?? 0
    readonly property bool mudo: salida?.audio?.muted ?? true

    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria && bateria.isLaptopBattery
    readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
    readonly property bool cargando: hayBateria
        && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)

    readonly property var musica: Reproductor.actual
    readonly property bool sonando: musica?.isPlaying ?? false

    // ------------------------------------------------------- Actividades
    // Lo que enseña un momento (cerrada): "" · "aviso" · "volumen" · "micro"
    // · "brillo" · "cancion" · "cargador"
    property string actividad: ""
    property var aviso: null            // la entrada de Notificaciones
    function mostrar(que, ms) {
        // Al arrancar, todo «cambia» de golpe: eso no cuenta. Abierta o con
        // un panel abierto, tampoco (ya se ve ahí)
        if (!listo || !enfocada || panelAbierto || abierta)
            return;
        actividad = que;
        fin.interval = ms;
        fin.restart();
    }
    Timer {
        id: fin
        // Con el ratón encima de un aviso, espera
        onTriggered: {
            if (barra.actividad === "aviso" && raton.containsMouse) {
                restart();
                return;
            }
            barra.terminar();
        }
    }
    function terminar() {
        if (actividad === "aviso" && aviso)
            Notificaciones.ocultar(aviso);
        actividad = "";
        aviso = null;
    }
    onPanelAbiertoChanged: if (panelAbierto) terminar()

    property bool listo: false
    Timer { interval: 2500; running: true; onTriggered: barra.listo = true }

    // Avisos: el más nuevo
    Connections {
        target: Notificaciones
        function onEmergentesChanged() {
            const e = Notificaciones.emergentes[0];
            if (!e || e === barra.aviso)
                return;
            luna.sorpresa();
            if (!barra.listo || !barra.enfocada || barra.panelAbierto || barra.abierta) {
                // No se enseña: que no se quede pendiente para siempre
                if (barra.listo && barra.enfocada)
                    Notificaciones.ocultar(e);
                return;
            }
            barra.aviso = e;
            barra.mostrar("aviso", 4500);
        }
    }
    // Volumen, micrófono y brillo
    Connections {
        target: barra.salida?.audio ?? null
        function onVolumeChanged() {
            barra.mostrar("volumen", 1500);
            if (barra.listo && barra.volumen >= 0.95)
                luna.apretar();
        }
        function onMutedChanged() { barra.mostrar("volumen", 1500); }
    }
    Connections {
        target: barra.entrada?.audio ?? null
        function onVolumeChanged() { barra.mostrar("micro", 1500); }
        function onMutedChanged() { barra.mostrar("micro", 1500); }
    }
    Connections {
        target: Brillo
        function onCambiadoConTecla() { barra.mostrar("brillo", 1500); }
    }
    // La canción, al empezar una (sin pisar un aviso)
    readonly property string cancion: musica ? (musica.trackTitle ?? "") + "·" + (musica.trackArtist ?? "") : ""
    onCancionChanged: if (sonando && musica?.trackTitle && actividad !== "aviso") mostrar("cancion", 3200)
    // El cargador
    onCargandoChanged: {
        if (hayBateria && actividad !== "aviso")
            mostrar("cargador", 2500);
        if (cargando && listo)
            luna.chispas();
    }
    // Al cambiar de escritorio, la luna mira hacia donde vas (arriba o abajo)
    readonly property int escritorio: Niri.escritorios.find(e => e.output === modelData.name && e.is_active)?.idx ?? 0
    property int _escritorioAntes: 0
    onEscritorioChanged: {
        if (listo && _escritorioAntes > 0)
            luna.mirarHacia(0, escritorio > _escritorioAntes ? 1 : -1);
        _escritorioAntes = escritorio;
    }

    // ------------------------------------------------------- La isla
    // Cómo se transforma: suave, sin rebote (como el resto de Yoru)
    component Suave: NumberAnimation { duration: Tema.ms(380); easing.type: Easing.OutQuint }
    // Lo de dentro: al llegar, espera a que la isla casi tenga su forma y
    // aparece; al irse, se va enseguida (si no, se veía recortado por los
    // lados mientras crecía, o suelto en medio de una isla que encogía)
    component Aparecer: SequentialAnimation {
        property bool activa: false
        PauseAnimation { duration: activa ? Tema.ms(190) : 0 }
        NumberAnimation { duration: activa ? Tema.normal : Tema.rapida; easing.type: Easing.OutCubic }
    }
    // El tamaño (Ajustes › Barra y dock › Tamaño de la isla): todo lo de
    // dentro se mide por él (sin «scale», que deja la letra borrosa)
    readonly property real k: Ajustes.tamIsla
    function m(n) { return Math.round(n * k); }

    Rectangle {
        id: isla
        readonly property bool reposando: barra.actividad === "" && !barra.abierta
        // Lo que se enseña ahora; la isla toma su tamaño
        readonly property Item contenido: barra.abierta ? cajaPaginas
            : barra.actividad === "aviso" ? cajaAviso
            : ["volumen", "micro", "brillo"].includes(barra.actividad) ? cajaNivel
            : barra.actividad === "cancion" ? cajaCancion
            : barra.actividad === "cargador" ? cajaCargador
            : cajaReposo
        readonly property int relleno: reposando ? 12 : barra.m(16)
        width: Math.round(contenido.implicitWidth + 2 * relleno)
        height: contenido.altoIsla
        x: Math.round((barra.width - width) / 2)
        y: Tema.margenBarra
        // Una píldora; lo alto, con las esquinas de los paneles
        radius: Math.min(height / 2, Tema.radioPanel + 10)
        // Creciendo queda encima de las ventanas: casi opaca, para leerse
        color: reposando ? Tema.isla : Tema.sombra(Math.max(0.96, Ajustes.opacidadIslas))
        border.width: Tema.borde(1)
        border.color: Tema.islaBorde
        // Sin recortar solo con la píldora ya en su sitio (así los corazones
        // y las notas de la luna salen por encima); mientras encoge, sí: si
        // no, lo que se iba se dibujaba fuera de ella
        readonly property bool asentada: reposando
            && Math.abs(width - (cajaReposo.implicitWidth + 2 * relleno)) < 1
            && Math.abs(height - Tema.altoBarra) < 1
        clip: !asentada
        Behavior on width { Suave {} }
        Behavior on height { Suave {} }
        Behavior on color { ColorAnimation { duration: Tema.normal } }

        // Para Panel.qml (las islas de siempre se funden; esta, no)
        function aportar(clave, cuanto) {}
        readonly property bool vacia: false

        // Clic, gestos y arrastres sobre la isla · el ratón encima: la luna
        // lo sigue con la mirada
        MouseArea {
            id: raton
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property point desde: Qt.point(0, 0)
            property bool gastado: false
            onPressed: e => { desde = Qt.point(e.x, e.y); gastado = false; }
            onPositionChanged: e => {
                if (pressed && !gastado)
                    gastado = barra.arrastre(e.x - desde.x, e.y - desde.y);
            }
            onClicked: e => {
                if (gastado)
                    return;
                // Clic en la luna: juega (en reposo o en la cabecera del menú)
                const sobre = l => {
                    const p = l.mapFromItem(raton, e.x, e.y);
                    return l.visible && p.x >= -2 && p.y >= -2 && p.x <= l.width + 2 && p.y <= l.height + 2;
                };
                if (barra.abierta) {
                    if (barra.pagina === 1 && sobre(lunaGrande))
                        lunaGrande.jugar();
                    return;
                }
                if (isla.reposando && e.button === Qt.LeftButton && sobre(luna)) {
                    luna.jugar();
                    return;
                }
                if (barra.actividad === "aviso" && barra.aviso) {
                    const a = barra.aviso;
                    barra.terminar();
                    if (e.button === Qt.LeftButton)
                        Notificaciones.abrir(a);
                    return;
                }
                if (barra.actividad === "cancion") {
                    barra.terminar();
                    Paneles.abrirPagina(barra.modelData, "multimedia", "centro");
                    return;
                }
                barra.abrir(1);
            }
            onWheel: e => barra.gesto(e)
        }

        // ------------------------------------------------- Reposo
        Row {
            id: cajaReposo
            readonly property int altoIsla: Tema.altoBarra
            readonly property bool activa: isla.contenido === cajaReposo
            anchors.centerIn: parent
            height: Tema.altoBarra
            spacing: 9
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Aparecer { activa: cajaReposo.activa } }

            Personaje {
                id: luna
                anchors.verticalCenter: parent.verticalCenter
                tam: Tema.altoBarra - (barra.k > 1 ? 6 : 8)
                interactivo: true
                contento: barra.sonando
                dormido: reposo.isIdle
                preocupado: barra.hayBateria && !barra.cargando && barra.carga <= 15
                siguiendo: raton.containsMouse
                mirada: {
                    const p = luna.mapFromItem(isla, raton.mouseX, raton.mouseY);
                    return Qt.point(Math.max(-1, Math.min(1, (p.x - luna.width / 2) / 60)),
                                    Math.max(-1, Math.min(1, (p.y - luna.height / 2) / 14)));
                }
            }
            // Grabando: punto rojo y lo que lleva
            Row {
                visible: Grabacion.grabando
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: Tema.rojo
                    SequentialAnimation on opacity {
                        running: Grabacion.grabando && Ajustes.animaciones
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Grabacion.tiempo
                    font.pixelSize: Tema.letra - 1
                    color: Tema.rojo
                }
            }
            SystemClock { id: reloj; precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(reloj.date, Ajustes.relojSegundos ? "HH:mm:ss" : "HH:mm")
                font.pixelSize: Tema.letra + (barra.k > 1 ? 1 : 0)
                color: Tema.blanco
            }
        }

        // ------------------------------------------------- Piezas
        // Un botón redondo con su nombre debajo
        component BotonMenu: Item {
            id: boton
            property string icono: ""
            property string texto: ""
            property bool encendido: false
            property bool peligro: false
            property string imagen: ""        // un icono de app (la bandeja)
            signal pulsar()
            signal menu()
            width: barra.m(72)
            height: barra.m(62)
            Rectangle {
                id: circulo
                anchors.horizontalCenter: parent.horizontalCenter
                width: barra.m(40); height: width
                radius: width / 2
                color: boton.encendido ? Tema.blanco
                    : botonRaton.containsMouse ? (boton.peligro ? Tema.conAlfa(Tema.rojo, 0.22) : Tema.cajaHover)
                    : Tema.caja
                scale: botonRaton.pressed ? 0.92 : 1
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
                Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                Texto {
                    visible: boton.imagen === ""
                    anchors.centerIn: parent
                    text: boton.icono
                    font.pixelSize: barra.m(17)
                    color: boton.encendido ? Tema.oscuro
                        : boton.peligro && botonRaton.containsMouse ? Tema.rojo : Tema.texto
                }
                IconImage {
                    visible: boton.imagen !== ""
                    anchors.centerIn: parent
                    implicitSize: barra.m(22)
                    source: boton.imagen
                }
            }
            Texto {
                anchors { top: circulo.bottom; topMargin: 5; horizontalCenter: parent.horizontalCenter }
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: boton.texto
                font.bold: boton.encendido
                font.pixelSize: barra.m(10)
                color: boton.encendido ? Tema.blanco : Tema.gris
            }
            MouseArea {
                id: botonRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? boton.menu() : boton.pulsar()
            }
        }
        // Una barra gruesa: arrastrar, clic o rueda. El relleno lleva el icono
        component NivelMenu: Rectangle {
            id: barraNivel
            property real valor: 0
            property string icono: ""
            property bool apagada: false
            signal mover(real v)
            height: barra.m(34)
            radius: height / 2
            color: Tema.caja
            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(1, barraNivel.valor))
                height: parent.height
                radius: parent.radius
                color: barraNivel.apagada ? Tema.tenue : Tema.blanco
                Behavior on width { enabled: !nivelRaton.pressed; NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                Texto {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: barraNivel.icono
                    font.pixelSize: barra.m(15)
                    color: Tema.oscuro
                }
            }
            Texto {
                id: porcentaje
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: Math.round(barraNivel.valor * 100) + "%"
                font.pixelSize: barra.m(11)
                // Oscuro en cuanto el relleno le llega (si no, medio tapado)
                color: barraNivel.width * barraNivel.valor > porcentaje.x + 2 ? Tema.oscuro : Tema.gris
            }
            MouseArea {
                id: nivelRaton
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function poner(mx) { barraNivel.mover(Math.max(0, Math.min(1, mx / width))); }
                onPressed: e => poner(e.x)
                onPositionChanged: e => { if (pressed) poner(e.x); }
                onWheel: e => barraNivel.mover(Math.max(0, Math.min(1, barraNivel.valor + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        // Un anillo con su % dentro (Sistema)
        component Anillo: Item {
            id: anillo
            property real valor: 0          // 0..1
            property string titulo: ""
            property string detalle: ""
            width: barra.m(112)
            height: barra.m(128)
            Canvas {
                id: lienzo
                width: barra.m(96); height: width
                anchors.horizontalCenter: parent.horizontalCenter
                property real v: anillo.valor
                Behavior on v { NumberAnimation { duration: Tema.ms(600); easing.type: Easing.OutCubic } }
                onVChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const r = width / 2 - 6;
                    c.lineWidth = 8;
                    c.lineCap = "round";
                    c.strokeStyle = Tema.caja;
                    c.beginPath();
                    c.arc(width / 2, height / 2, r, 0, 2 * Math.PI);
                    c.stroke();
                    if (v > 0.005) {
                        c.strokeStyle = v > 0.85 ? Tema.rojo : Tema.blanco;
                        c.beginPath();
                        c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.min(1, v));
                        c.stroke();
                    }
                }
                Texto {
                    anchors.centerIn: parent
                    text: Math.round(anillo.valor * 100) + "%"
                    font.pixelSize: barra.m(18)
                    color: Tema.blanco
                }
            }
            Column {
                anchors { top: lienzo.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: anillo.titulo
                    font.pixelSize: barra.m(12)
                }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: anillo.detalle
                    font.bold: false
                    font.pixelSize: barra.m(10)
                    color: Tema.gris
                }
            }
        }
        // Una línea de dato: icono · nombre ........ valor
        component Dato: Item {
            id: dato
            property string icono: ""
            property string nombre: ""
            property string valor: ""
            height: barra.m(30)
            Texto { x: 4; anchors.verticalCenter: parent.verticalCenter; text: dato.icono; font.pixelSize: barra.m(15); color: Tema.gris }
            Texto { x: barra.m(30); anchors.verticalCenter: parent.verticalCenter; text: dato.nombre; font.bold: false; font.pixelSize: barra.m(12) }
            Texto {
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                text: dato.valor
                font.pixelSize: barra.m(12)
                color: Tema.blanco
            }
        }

        // ------------------------------------------------- Las páginas
        Item {
            id: cajaPaginas
            readonly property bool activa: isla.contenido === cajaPaginas
            readonly property int ancho: 4 * barra.m(72) + 3 * barra.m(6)
            readonly property Item actual: [paginaSistema, paginaMenu, paginaBandeja][barra.pagina]
            // Lo de la página + los puntitos de abajo
            readonly property int altoIsla: actual.implicitHeight + barra.m(14) + 12 + puntos.height + barra.m(12)
            implicitWidth: ancho
            width: ancho
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Aparecer { activa: cajaPaginas.activa } }
            Keys.onEscapePressed: barra.abierta = false
            Keys.onLeftPressed: barra.pasar(-1)
            Keys.onRightPressed: barra.pasar(1)

            // Las tres, una al lado de otra; se ve la elegida
            Item {
                id: carril
                y: barra.m(14)
                width: parent.width
                height: cajaPaginas.actual.implicitHeight
                property real desplazado: barra.pagina
                Behavior on desplazado { Suave {} }

                // ---------------------------------------- Sistema
                Column {
                    id: paginaSistema
                    width: parent.width
                    // Solo la que se ve recibe clics (las otras siguen ahí, fuera de la isla)
                    enabled: barra.pagina === 0
                    visible: opacity > 0.01
                    x: (0 - carril.desplazado) * (parent.width + 40)
                    opacity: 1 - Math.min(1, Math.abs(0 - carril.desplazado))
                    spacing: 12
                    Texto {
                        text: "Sistema"
                        font.pixelSize: barra.m(15)
                        color: Tema.blanco
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16
                        Anillo {
                            valor: Sistema.cpu / 100
                            titulo: "CPU"
                            detalle: Sistema.temperatura > 0 ? Sistema.temperatura + " °C" : ""
                        }
                        Anillo {
                            valor: Sistema.memoria / 100
                            titulo: "Memoria"
                            detalle: Sistema.memUsada.toFixed(1) + " de " + Sistema.memTotal.toFixed(0) + " GB"
                        }
                    }
                    Column {
                        width: parent.width
                        Dato {
                            width: parent.width
                            icono: "󰔏"; nombre: "Temperatura"
                            valor: Sistema.temperatura > 0 ? Sistema.temperatura + " °C" : "—"
                        }
                        Dato {
                            width: parent.width
                            visible: barra.hayBateria
                            icono: barra.cargando ? "󰂄" : "󰁹"; nombre: "Batería"
                            valor: barra.carga + "%" + (barra.cargando ? " · cargando" : "")
                        }
                        Dato {
                            width: parent.width
                            icono: "󰔟"; nombre: "Encendido"
                            valor: Sesion.encendido
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: barra.m(34)
                        radius: height / 2
                        color: monitorRaton.containsMouse ? Tema.cajaHover : Tema.caja
                        Texto {
                            anchors.centerIn: parent
                            text: "󰍛  Monitor del sistema"
                            font.pixelSize: barra.m(12)
                        }
                        MouseArea {
                            id: monitorRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barra.hacer(() => Paneles.alternar("monitor", barra.modelData, "procesos"))
                        }
                    }
                }

                // ---------------------------------------- Menú
                Column {
                    id: paginaMenu
                    width: parent.width
                    // Solo la que se ve recibe clics (las otras siguen ahí, fuera de la isla)
                    enabled: barra.pagina === 1
                    visible: opacity > 0.01
                    x: (1 - carril.desplazado) * (parent.width + 40)
                    opacity: 1 - Math.min(1, Math.abs(1 - carril.desplazado))
                    spacing: 12

                    // La luna (grande), la hora y la fecha
                    Row {
                        spacing: 12
                        Personaje {
                            id: lunaGrande
                            anchors.verticalCenter: parent.verticalCenter
                            tam: barra.m(40)
                            interactivo: true
                            contento: barra.sonando
                            preocupado: barra.hayBateria && !barra.cargando && barra.carga <= 15
                            siguiendo: menuHover.hovered
                            mirada: Qt.point(Math.max(-1, Math.min(1, (menuHover.point.position.x - 36) / 120)),
                                             Math.max(-1, Math.min(1, (menuHover.point.position.y - 34) / 80)))
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Texto {
                                text: Qt.formatTime(reloj.date, "HH:mm")
                                font.pixelSize: barra.m(24)
                                color: Tema.blanco
                            }
                            Texto {
                                readonly property var dias: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
                                readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                                    "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
                                text: dias[reloj.date.getDay()] + ", " + reloj.date.getDate() + " de " + meses[reloj.date.getMonth()]
                                font.bold: false
                                font.pixelSize: barra.m(11)
                                color: Tema.gris
                            }
                        }
                    }

                    // Buscar: lo que escribas abre el lanzador con ello
                    Rectangle {
                        width: parent.width
                        height: barra.m(36)
                        radius: height / 2
                        color: Tema.caja
                        border.width: 1
                        border.color: buscar.activeFocus ? Tema.claro(0.18) : "transparent"
                        Texto {
                            id: lupa
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.pixelSize: barra.m(14)
                            color: Tema.gris
                        }
                        TextInput {
                            id: buscar
                            anchors { left: lupa.right; leftMargin: 8; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            color: Tema.texto
                            font.family: Tema.fuente
                            font.pixelSize: barra.m(13)
                            clip: true
                            onTextChanged: {
                                if (text === "" || !barra.abierta)
                                    return;
                                Paneles.textoLanzador = text;
                                barra.hacer(() => Paneles.alternar("lanzador", barra.modelData, ""));
                            }
                            onAccepted: barra.hacer(() => Paneles.alternar("lanzador", barra.modelData, ""))
                            Keys.onEscapePressed: barra.abierta = false
                            // (las flechas, para pasar de página si no hay nada escrito)
                            Keys.onLeftPressed: e => { if (text === "") barra.pasar(-1); else e.accepted = false; }
                            Keys.onRightPressed: e => { if (text === "") barra.pasar(1); else e.accepted = false; }
                            Texto {
                                visible: buscar.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Buscar"
                                font.bold: false
                                font.pixelSize: barra.m(13)
                                color: Tema.gris
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: barra.hacer(() => Paneles.alternar("lanzador", barra.modelData, ""))
                        }
                    }

                    // La canción (si suena algo)
                    Rectangle {
                        visible: barra.musica !== null
                        width: parent.width
                        height: barra.m(56)
                        radius: Tema.esquina(16)
                        color: Tema.caja
                        ClippingRectangle {
                            id: caratula
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: barra.m(40); height: width
                            radius: Tema.esquina(10)
                            color: Tema.cajaHover
                            Image {
                                anchors.fill: parent
                                source: barra.musica ? Reproductor.caratula(barra.musica) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(80, 80)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: barra.hacer(() => Paneles.abrirPagina(barra.modelData, "multimedia", "centro"))
                            }
                        }
                        Column {
                            anchors { left: caratula.right; leftMargin: 10; right: mandos.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            spacing: 1
                            Texto {
                                width: parent.width
                                elide: Text.ElideRight
                                text: barra.musica?.trackTitle || Reproductor.nombre(barra.musica)
                                textFormat: Text.PlainText
                                font.pixelSize: barra.m(12)
                                color: Tema.blanco
                            }
                            Texto {
                                width: parent.width
                                elide: Text.ElideRight
                                text: barra.musica?.trackArtist ?? ""
                                textFormat: Text.PlainText
                                font.bold: false
                                font.pixelSize: barra.m(10)
                                color: Tema.gris
                            }
                        }
                        Row {
                            id: mandos
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            Repeater {
                                model: [
                                    {icono: "󰒮", hacer: () => Reproductor.anterior(barra.musica)},
                                    {icono: barra.sonando ? "󰏤" : "󰐊", hacer: () => barra.musica?.togglePlaying()},
                                    {icono: "󰒭", hacer: () => Reproductor.siguiente(barra.musica)}
                                ]
                                Item {
                                    required property var modelData
                                    width: barra.m(28); height: width
                                    Texto {
                                        anchors.centerIn: parent
                                        text: parent.modelData.icono
                                        font.pixelSize: barra.m(16)
                                        color: mandoRaton.containsMouse ? Tema.blanco : Tema.texto
                                    }
                                    MouseArea {
                                        id: mandoRaton
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.modelData.hacer()
                                    }
                                }
                            }
                        }
                    }

                    // Volumen y brillo
                    NivelMenu {
                        width: parent.width
                        valor: barra.volumen
                        apagada: barra.mudo
                        icono: barra.mudo ? "󰖁" : barra.volumen < 0.34 ? "󰕿" : barra.volumen < 0.67 ? "󰖀" : "󰕾"
                        onMover: v => {
                            if (!barra.salida?.audio)
                                return;
                            barra.salida.audio.muted = false;
                            barra.salida.audio.volume = v;
                        }
                    }
                    NivelMenu {
                        visible: Brillo.pantallas.length > 0
                        width: parent.width
                        readonly property var pantalla: Brillo.pantallas[0] ?? null
                        valor: pantalla?.valor ?? 0
                        icono: valor < 0.35 ? "󰃞" : valor < 0.7 ? "󰃟" : "󰃠"
                        onMover: v => { if (pantalla) Brillo.poner(pantalla.id, v); }
                    }

                    // Los botones
                    Grid {
                        columns: 4
                        columnSpacing: barra.m(6)
                        rowSpacing: 6
                        BotonMenu {
                            icono: Grabacion.grabando ? "󰓛" : "󰑊"
                            texto: Grabacion.grabando ? "Detener" : "Grabar"
                            encendido: Grabacion.grabando
                            onPulsar: barra.hacer(() => Grabacion.alternar())
                        }
                        BotonMenu {
                            icono: "󰹑"
                            texto: "Captura"
                            onPulsar: barra.hacer(() => Niri.accion("screenshot"))
                        }
                        BotonMenu {
                            icono: "󰕰"
                            texto: "Escritorios"
                            onPulsar: barra.hacer(() => Niri.accion("toggle-overview"))
                        }
                        BotonMenu {
                            icono: "󰅍"
                            texto: "Portapapeles"
                            onPulsar: barra.hacer(() => Paneles.alternar("portapapeles", barra.modelData, ""))
                        }
                        BotonMenu {
                            icono: "󰆍"
                            texto: "Terminal"
                            onPulsar: barra.hacer(() => Niri.lanzar(["kitty"]))
                        }
                        BotonMenu {
                            icono: "󰖟"
                            texto: "Navegador"
                            onPulsar: barra.hacer(() => Niri.lanzar(["sh", "-c", 'gtk-launch "$(xdg-settings get default-web-browser)"']))
                        }
                        BotonMenu {
                            icono: "󰉋"
                            texto: "Archivos"
                            onPulsar: barra.hacer(() => Niri.lanzar(["nautilus"]))
                        }
                        BotonMenu {
                            icono: "󰶐"
                            texto: "Pantalla off"
                            onPulsar: barra.hacer(() => Niri.accion("power-off-monitors"))
                        }
                        BotonMenu {
                            icono: "󰍃"
                            texto: "Cerrar sesión"
                            peligro: true
                            onPulsar: barra.hacer(() => { Paneles.sesionElegida = "Cerrar sesión"; Paneles.alternar("apagado", barra.modelData, ""); })
                        }
                        BotonMenu {
                            icono: "󰜉"
                            texto: "Reiniciar"
                            peligro: true
                            onPulsar: barra.hacer(() => { Paneles.sesionElegida = "Reiniciar"; Paneles.alternar("apagado", barra.modelData, ""); })
                        }
                        BotonMenu {
                            icono: "󰐥"
                            texto: "Apagar"
                            peligro: true
                            onPulsar: barra.hacer(() => { Paneles.sesionElegida = "Apagar"; Paneles.alternar("apagado", barra.modelData, ""); })
                        }
                        BotonMenu {
                            icono: "󰒓"
                            texto: "Ajustes"
                            onPulsar: barra.hacer(() => Paneles.alternarAjustes(""))
                        }
                    }
                }

                // ---------------------------------------- Segundo plano
                Column {
                    id: paginaBandeja
                    width: parent.width
                    // Solo la que se ve recibe clics (las otras siguen ahí, fuera de la isla)
                    enabled: barra.pagina === 2
                    visible: opacity > 0.01
                    x: (2 - carril.desplazado) * (parent.width + 40)
                    opacity: 1 - Math.min(1, Math.abs(2 - carril.desplazado))
                    spacing: 12
                    readonly property var apps: SystemTray.items.values.filter(i => i.status !== Status.Passive)
                    Texto {
                        text: "Segundo plano"
                        font.pixelSize: barra.m(15)
                        color: Tema.blanco
                    }
                    Grid {
                        visible: paginaBandeja.apps.length > 0
                        columns: 4
                        columnSpacing: barra.m(6)
                        rowSpacing: 6
                        Repeater {
                            model: paginaBandeja.apps
                            BotonMenu {
                                required property var modelData
                                imagen: modelData.icon
                                texto: modelData.tooltipTitle || modelData.title || modelData.id
                                onPulsar: barra.hacer(() => bandeja.abrir(modelData))
                                onMenu: {
                                    if (modelData.hasMenu)
                                        barra.hacer(() => Paneles.alternar("bandeja", barra.modelData, modelData.id));
                                }
                            }
                        }
                    }
                    Vacio {
                        visible: paginaBandeja.apps.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        icono: "󰂜"
                        titulo: "Nada en segundo plano"
                        detalle: "Las apps que se quedan en la bandeja (Telegram, Discord...) salen aquí"
                        ancho: 240
                    }
                    Texto {
                        visible: paginaBandeja.apps.length > 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Clic: abrir · clic derecho: su menú"
                        font.bold: false
                        font.pixelSize: 10
                        color: Tema.claro(0.35)
                    }
                    // (la lógica de abrir de la bandeja de siempre, sin enseñarla)
                    Bandeja {
                        id: bandeja
                        visible: false
                        ventana: barra
                    }
                }
            }

            // Los puntitos: en qué página estás (clic = ir a ella)
            Row {
                id: puntos
                anchors.horizontalCenter: parent.horizontalCenter
                y: carril.y + carril.height + 12
                height: 8
                spacing: 6
                Behavior on y { Suave {} }
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property bool elegida: barra.pagina === index
                        anchors.verticalCenter: parent.verticalCenter
                        width: elegida ? 18 : 6
                        height: 6
                        radius: 3
                        color: elegida ? Tema.blanco : Tema.claro(0.25)
                        Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: barra.pagina = parent.index
                        }
                    }
                }
            }
        }
        // Para que la luna grande siga al ratón por todo el menú (un
        // HoverHandler no le quita el ratón a los botones)
        HoverHandler { id: menuHover; enabled: barra.abierta }

        // ------------------------------------------------- Un aviso
        Item {
            id: cajaAviso
            readonly property int altoIsla: Math.max(barra.m(60), textosAviso.implicitHeight + barra.m(24))
            readonly property bool activa: isla.contenido === cajaAviso
            readonly property var n: barra.aviso?.n ?? null
            anchors.centerIn: parent
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Aparecer { activa: cajaAviso.activa } }
            implicitWidth: Math.min(barra.m(440), Math.max(barra.m(260), barra.m(40) + 12 + textosAviso.implicitWidth))
            implicitHeight: filaAviso.implicitHeight
            width: implicitWidth
            height: implicitHeight
          Row {
            id: filaAviso
            spacing: 12

            Rectangle {
                width: barra.m(40); height: width
                anchors.verticalCenter: parent.verticalCenter
                radius: Tema.esquina(12)
                color: Tema.caja
                IconImage {
                    id: iconoAviso
                    anchors.centerIn: parent
                    implicitSize: barra.m(26)
                    source: cajaAviso.n ? Notificaciones.imagen(cajaAviso.n) : ""
                    // Sin icono (o uno que no existe): la campana
                    visible: source !== "" && status === Image.Ready
                }
                Texto {
                    visible: !iconoAviso.visible
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.pixelSize: barra.m(18)
                    color: Tema.blanco
                }
            }
            Column {
                id: textosAviso
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, barra.m(440) - barra.m(52))
                spacing: 2
                // La app, en mayúsculas pequeñas (como las tarjetas de avisos)
                Texto {
                    visible: text !== ""
                    width: Math.min(implicitWidth, barra.m(388))
                    elide: Text.ElideRight
                    text: (cajaAviso.n?.appName ?? "").toUpperCase()
                    textFormat: Text.PlainText
                    font.pixelSize: barra.m(9)
                    font.letterSpacing: 1.2
                    color: Tema.gris
                }
                Texto {
                    width: Math.min(implicitWidth, barra.m(388))
                    elide: Text.ElideRight
                    text: cajaAviso.n ? (cajaAviso.n.summary || cajaAviso.n.appName || "Aviso") : ""
                    textFormat: Text.PlainText
                    font.pixelSize: barra.m(13)
                    color: Tema.blanco
                }
                Texto {
                    width: Math.min(implicitWidth, barra.m(388))
                    visible: text !== ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    text: cajaAviso.n ? (cajaAviso.n.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""
                    textFormat: Text.PlainText
                    font.bold: false
                    font.pixelSize: barra.m(12)
                    color: Tema.gris
                }
            }
          }
        }

        // ---------------------------------- Volumen, micrófono o brillo
        Row {
            id: cajaNivel
            readonly property int altoIsla: Tema.altoBarra + 6
            readonly property bool activa: isla.contenido === cajaNivel
            readonly property string tipo: ["volumen", "micro", "brillo"].includes(barra.actividad) ? barra.actividad : tipoAntes
            property string tipoAntes: "volumen"
            onTipoChanged: tipoAntes = tipo
            readonly property var nodo: tipo === "micro" ? barra.entrada : barra.salida
            readonly property bool mudo: tipo !== "brillo" && (nodo?.audio?.muted ?? true)
            readonly property real valor: tipo === "brillo" ? (Brillo.pantallas[0]?.valor ?? 0) : (nodo?.audio?.volume ?? 0)
            anchors.centerIn: parent
            spacing: 12
            height: Tema.altoBarra
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Aparecer { activa: cajaNivel.activa } }

            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: cajaNivel.tipo === "brillo" ? (cajaNivel.valor < 0.35 ? "󰃞" : cajaNivel.valor < 0.7 ? "󰃟" : "󰃠")
                    : cajaNivel.tipo === "micro" ? (cajaNivel.mudo ? "󰍭" : "󰍬")
                    : cajaNivel.mudo ? "󰖁" : cajaNivel.valor < 0.34 ? "󰕿" : cajaNivel.valor < 0.67 ? "󰖀" : "󰕾"
                font.pixelSize: Tema.letra + 4
                color: cajaNivel.mudo ? Tema.tenue : Tema.blanco
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: barra.m(190); height: 6; radius: 3
                color: Tema.claro(0.12)
                Rectangle {
                    width: parent.width * Math.min(1, cajaNivel.valor)
                    height: parent.height; radius: 3
                    color: cajaNivel.mudo ? Tema.tenue : Tema.blanco
                    Behavior on width { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                }
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                horizontalAlignment: Text.AlignRight
                text: cajaNivel.mudo ? "No" : Math.round(cajaNivel.valor * 100) + "%"
                color: Tema.texto
            }
        }

        // -------------------------------------------- Empieza una canción
        Row {
            id: cajaCancion
            readonly property int altoIsla: barra.m(58)
            readonly property bool activa: isla.contenido === cajaCancion
            anchors.centerIn: parent
            spacing: 12
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Aparecer { activa: cajaCancion.activa } }

            ClippingRectangle {
                width: barra.m(40); height: width
                anchors.verticalCenter: parent.verticalCenter
                radius: Tema.esquina(10)
                color: Tema.caja
                Image {
                    anchors.fill: parent
                    source: barra.musica ? Reproductor.caratula(barra.musica) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(80, 80)
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Texto {
                    width: Math.min(implicitWidth, barra.m(260))
                    elide: Text.ElideRight
                    text: barra.musica?.trackTitle ?? ""
                    textFormat: Text.PlainText
                    font.pixelSize: barra.m(13)
                    color: Tema.blanco
                }
                Texto {
                    width: Math.min(implicitWidth, barra.m(260))
                    elide: Text.ElideRight
                    text: barra.musica?.trackArtist ?? ""
                    textFormat: Text.PlainText
                    font.bold: false
                    font.pixelSize: barra.m(12)
                    color: Tema.gris
                }
            }
            // Unas barritas que bailan
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        id: barrita
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; radius: 1.5
                        height: 6
                        color: Tema.blanco
                        SequentialAnimation on height {
                            running: cajaCancion.activa && Ajustes.animaciones
                            loops: Animation.Infinite
                            NumberAnimation { to: 6 + (barrita.index % 2 ? 10 : 14); duration: 260 + barrita.index * 70; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 5; duration: 260 + barrita.index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------ El cargador
        Row {
            id: cajaCargador
            readonly property int altoIsla: Tema.altoBarra + 6
            readonly property bool activa: isla.contenido === cajaCargador
            anchors.centerIn: parent
            spacing: 10
            height: Tema.altoBarra
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Aparecer { activa: cajaCargador.activa } }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: barra.cargando ? "󰂄" : "󰁹"
                font.pixelSize: Tema.letra + 4
                color: barra.cargando ? Tema.bateria(barra.carga / 100, true) : Tema.texto
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: (barra.cargando ? "Cargando" : "Sin cargador") + "  " + Tema.suave(barra.carga + "%")
                textFormat: Text.StyledText
                color: Tema.blanco
            }
        }
    }
}
