pragma Singleton

// ============================================================================
//  Tocadiscos — el cerebro de «Música de Yoru» (paneles/VentanaMusica.qml)
//
//  La biblioteca: ~/.cache/yoru/musica/indice.json, que escribe
//  scripts/musica.py. Se lee al momento (lo que había) y el script la pone
//  al día en segundo plano al abrir la ventana (si hace más de 10 min).
//
//  El sonido: un mpv sin ventana, aparte de Quickshell (systemd-run
//  --user, unidad «yoru-musica»): la música no se corta al recargar la
//  barra ni al cerrar la ventana. Se le habla por su socket JSON
//  ($XDG_RUNTIME_DIR/yoru-musica.sock). La cola es su playlist. Con el
//  plugin mpv-mpris sale por MPRIS: la isla, la pestaña Multimedia y las
//  teclas multimedia lo ven como cualquier otro reproductor.
//
//    Tocadiscos.reproducir(rutas, desde)   Tocadiscos.anadir(rutas)
//    Tocadiscos.despues(rutas)             Tocadiscos.pausa() / siguiente() / ...
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: musica

    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/yoru/musica"
    readonly property string run: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string rutaSocket: run + "/yoru-musica.sock"

    // ------------------------------------------------------- Biblioteca
    property var canciones: []
    property var discos: []
    property var porRuta: ({})          // ruta → canción
    property var porDisco: ({})         // id → disco
    property var sinMontar: []
    property int fecha: 0
    property bool escaneando: false
    property int leidas: 0              // etiquetas leídas en este escaneo

    // Artistas y géneros, con cuántos discos tienen
    readonly property var artistas: agrupar("artista")
    readonly property var generos: agrupar("genero")
    function agrupar(campo) {
        const m = {};
        for (const d of discos) {
            const k = d[campo] || "Desconocido";
            m[k] = (m[k] ?? 0) + 1;
        }
        return Object.keys(m).sort((a, b) => a.localeCompare(b, "es", {sensitivity: "base"}))
            .map(k => ({nombre: k, discos: m[k]}));
    }

    FileView {
        id: indice
        path: musica.cache + "/indice.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                const r = {}, p = {};
                for (const c of d.canciones) r[c.ruta] = c;
                for (const x of d.discos) p[x.id] = x;
                musica.porRuta = r;
                musica.porDisco = p;
                musica.canciones = d.canciones;
                musica.discos = d.discos;
                musica.sinMontar = d.sinMontar ?? [];
                musica.fecha = d.fecha ?? 0;
            } catch (e) {
                console.warn("Tocadiscos: índice ilegible:", e);
            }
        }
    }

    Process {
        id: escaner
        command: ["python3", Quickshell.shellDir + "/scripts/musica.py"]
        onRunningChanged: musica.escaneando = running
        stdout: SplitParser {
            onRead: linea => {
                try {
                    const d = JSON.parse(linea);
                    musica.leidas = d.leidas ?? musica.leidas;
                } catch (e) {}
            }
        }
    }
    function escanear() {
        if (!escaner.running) {
            leidas = 0;
            escaner.running = true;
        }
    }
    // Al abrir la ventana: si el índice tiene más de 10 minutos
    function ponerAlDia() {
        if (Date.now() / 1000 - fecha > 600)
            escanear();
    }

    // ------------------------------------------- Dónde dejaste la ventana
    // Tamaño, posición y si era flotante, para abrirla igual la próxima vez
    // (paneles/VentanaMusica.qml lo guarda al moverla o cambiarla de tamaño)
    property alias sitio: sitioGuardado
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/yoru/musica.json"
        printErrors: false
        atomicWrites: true
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: sitioGuardado
            property int ancho: 1240
            property int alto: 800
            property int x: -1          // -1: niri la centra
            property int y: -1
            property bool flotante: true
        }
    }

    // ------------------------------------------------------- Estado de mpv
    property bool conectado: false
    property bool pausado: true
    property string ruta: ""            // la que suena
    property real posicion: 0
    property real duracion: 0
    property real volumen: 100
    property int indiceCola: -1
    property var cola: []               // [{ruta, actual}]
    property string repetir: "no"       // "no" | "todo" | "una"
    property bool aleatorio: false
    readonly property bool sonando: conectado && ruta !== "" && !pausado
    readonly property var actual: porRuta[ruta] ?? (ruta ? {titulo: ruta.split("/").pop(), artista: "", album: "", ruta: ruta} : null)
    readonly property var discoActual: actual ? porDisco[actual.disco_id] ?? null : null

    // Lo que se manda antes de que mpv esté listo espera aquí
    property var pendientes: []

    Socket {
        id: socket
        path: musica.rutaSocket
        connected: false
        onConnectionStateChanged: {
            musica.conectado = connected;
            if (connected) {
                // Lo que interesa, que mpv lo avise solo al cambiar
                const obs = ["pause", "path", "duration", "volume", "playlist", "playlist-pos", "loop-playlist", "loop-file"];
                obs.forEach((p, i) => musica.mandar(["observe_property", i + 1, p]));
                const p = musica.pendientes;
                musica.pendientes = [];
                p.forEach(c => musica.mandar(c));
            } else {
                musica.ruta = "";
                musica.pausado = true;
                musica.cola = [];
                musica.indiceCola = -1;
            }
        }
        onError: musica.conectado = false
        parser: SplitParser {
            onRead: linea => musica.recibir(linea)
        }
    }

    function recibir(linea) {
        let m;
        try { m = JSON.parse(linea); } catch (e) { return; }
        if (m.request_id === 99 && m.error === "success")         // la posición
            posicion = m.data ?? 0;
        if (m.event !== "property-change")
            return;
        const v = m.data;
        switch (m.name) {
        case "pause": pausado = v === true; break;
        case "path": ruta = v ?? ""; posicion = 0; break;
        case "duration": duracion = v ?? 0; break;
        case "volume": volumen = v ?? 100; break;
        case "playlist":
            cola = (v ?? []).map(x => ({ruta: x.filename, actual: x.current === true}));
            break;
        case "playlist-pos": indiceCola = v ?? -1; break;
        case "loop-file": if (v === "inf" || v === true) repetir = "una"; else if (repetir === "una") repetir = "no"; break;
        case "loop-playlist": if (v === "inf" || v === true) repetir = "todo"; else if (repetir === "todo") repetir = "no"; break;
        }
    }

    // La posición, cada medio segundo mientras suena (observarla mandaría
    // decenas de avisos por segundo)
    Timer {
        interval: 500
        repeat: true
        running: musica.conectado && musica.ruta !== ""
        triggeredOnStart: true
        onTriggered: musica.mandar(["get_property", "time-pos"], 99)
    }

    function mandar(cmd, id) {
        if (!conectado) {
            pendientes = pendientes.concat([cmd]);
            arrancar();
            return;
        }
        const o = {command: cmd};
        if (id !== undefined)
            o.request_id = id;
        socket.write(JSON.stringify(o) + "\n");
        socket.flush();
    }

    // ------------------------------------------------------- Arrancar mpv
    // Si el socket no contesta, se lanza el mpv y se reintenta conectar
    Process {
        id: lanzador
        command: [Quickshell.shellDir + "/scripts/musica-mpv.sh", musica.rutaSocket]
    }
    property int intentos: 0
    Timer {
        id: reintento
        interval: 150
        repeat: true
        onTriggered: {
            if (musica.conectado || ++musica.intentos > 40) {
                stop();
                return;
            }
            socket.connected = true;
        }
    }
    function arrancar() {
        if (conectado || reintento.running)
            return;
        intentos = 0;
        lanzador.running = true;
        reintento.start();
    }
    // Al cargar Quickshell: si ya había un mpv sonando, engancharse a él
    Component.onCompleted: socket.connected = true

    // ------------------------------------------------------- Órdenes
    // Una lista para mpv: un .m3u en $XDG_RUNTIME_DIR (mandar miles de
    // «loadfile» seguidos tarda)
    property int nLista: 0
    function lista(rutas) {
        const f = run + "/yoru-musica-" + (nLista++ % 4) + ".m3u";
        escritor.path = f;
        escritor.setText("#EXTM3U\n" + rutas.join("\n") + "\n");
        return f;
    }
    FileView { id: escritor; blockWrites: true; printErrors: false }

    function reproducir(rutas, desde) {
        if (!rutas || rutas.length === 0)
            return;
        const f = lista(rutas);
        mandar(["set_property", "playlist-start", String(desde ?? 0)]);
        mandar(["loadlist", f, "replace"]);
        mandar(["set_property", "pause", false]);
        if (aleatorio)
            mandar(["playlist-shuffle"]);
    }
    function anadir(rutas) {
        if (!rutas || rutas.length === 0)
            return;
        if (!conectado || cola.length === 0) {
            reproducir(rutas, 0);
            return;
        }
        mandar(["loadlist", lista(rutas), "append"]);
    }
    // Detrás de la que suena (al revés, para que queden en orden)
    function despues(rutas) {
        if (!conectado || cola.length === 0) {
            reproducir(rutas, 0);
            return;
        }
        for (let i = rutas.length - 1; i >= 0; i--)
            mandar(["loadfile", rutas[i], "insert-next"]);
    }
    function pausa() {
        if (!conectado || ruta === "") {
            // Nada en marcha: suena todo, en orden
            reproducir(canciones.map(c => c.ruta), 0);
            return;
        }
        mandar(["cycle", "pause"]);
    }
    function siguiente() { mandar(["playlist-next", "weak"]); }
    function anterior() {
        // Como en todos: si ya va por la mitad, vuelve al principio
        if (posicion > 4)
            mandar(["seek", 0, "absolute"]);
        else
            mandar(["playlist-prev", "weak"]);
    }
    function ir(segundos) {
        posicion = segundos;
        mandar(["seek", segundos, "absolute"]);
    }
    function avanzar(segundos) { mandar(["seek", segundos, "relative"]); }
    function ponerVolumen(v) {
        volumen = Math.max(0, Math.min(100, v));
        mandar(["set_property", "volume", volumen]);
    }
    function saltar(i) { mandar(["playlist-play-index", i]); mandar(["set_property", "pause", false]); }
    function quitar(i) { mandar(["playlist-remove", i]); }
    function vaciar() { mandar(["playlist-clear"]); mandar(["playlist-remove", "current"]); }
    function alternarAleatorio() {
        aleatorio = !aleatorio;
        if (conectado && cola.length > 1)
            mandar([aleatorio ? "playlist-shuffle" : "playlist-unshuffle"]);
    }
    function alternarRepetir() {
        const sig = {no: "todo", todo: "una", una: "no"}[repetir];
        repetir = sig;
        mandar(["set_property", "loop-playlist", sig === "todo" ? "inf" : "no"]);
        mandar(["set_property", "loop-file", sig === "una" ? "inf" : "no"]);
    }

    // Las canciones de un disco, de un artista o de un género (en orden)
    function rutasDe(discosElegidos) {
        return [].concat(...discosElegidos.map(d => d.canciones));
    }

    function tiempo(s) {
        s = Math.max(0, Math.round(s || 0));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(x).padStart(2, "0");
    }
}
