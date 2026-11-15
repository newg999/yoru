pragma Singleton

// ============================================================================
//  Reproductor — qué reproductor (Spotify, Brave, mpv...) muestran la barra
//  y los paneles. Por defecto, el que está sonando; si eliges uno en la
//  pestaña Multimedia, se queda ese mientras siga abierto.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: reproductor

    // playerctld no es un reproductor: repite el último que se usó (salía
    // un segundo «Elisa» en la lista)
    readonly property var todos: Mpris.players.values.filter(p => !(p.dbusName ?? "").includes("playerctld"))
    property var elegido: null

    readonly property var actual: {
        // Un reproductor enseñando una vista previa no cuenta (salvo que
        // tape una canción que sonaba: entonces se ve esa, «tapada»)
        const vale = p => !vistaPrevia(p) || tapaCancion(p);
        if (elegido && todos.includes(elegido) && vale(elegido))
            return elegido;
        return todos.find(p => p.isPlaying && vale(p))
            ?? todos.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }

    // ------------------------------------------- Vistas previas de YouTube
    // Al pasar el ratón por encima de un vídeo, YouTube lo reproduce (sin
    // sonido) y Brave lo avisa por MPRIS como si fuera otra canción: la
    // isla cambiaba de canción con cada miniatura. Una vista previa es un
    // vídeo del navegador cuyo título no sale en ninguna ventana mientras
    // hay una ventana en YouTube (la pestaña de la vista previa sigue
    // siendo la portada, la búsqueda u otro vídeo). Lo que sí se ha visto
    // en el título de una ventana, o lleva 20 s sonando seguido (la
    // siguiente canción en una pestaña de detrás), queda «confirmado».
    property var confirmados: ({})
    property var sinConfirmar: ({titulo: "", desde: 0})
    function vistaPrevia(p) {
        if (!p || !p.isPlaying || !esNavegador(p) || (p.trackAlbum ?? "") !== "")
            return false;
        const t = p.trackTitle ?? "";
        if (!t || confirmados[t])
            return false;
        const titulos = Object.values(Niri.ventanas).map(v => v.title ?? "");
        if (titulos.some(v => v.includes(t)))
            return false;
        return titulos.some(v => /YouTube/.test(v) && !/YouTube Music/.test(v));
    }
    // ¿Hay una canción de ese mismo navegador sonando hace nada? (la vista
    // previa la tapa: se sigue enseñando)
    function tapaCancion(p) {
        const c = recordada;
        return c !== null && c.jugador === p && c.titulo !== (p.trackTitle ?? "") && Date.now() - c.cuando < 5000;
    }
    function _confirmar() {
        const titulos = Object.values(Niri.ventanas).map(v => v.title ?? "");
        let nuevos = null;
        for (const p of todos) {
            const t = p.trackTitle ?? "";
            if (!t || !p.isPlaying || !esNavegador(p) || confirmados[t])
                continue;
            let si = titulos.some(v => v.includes(t));
            if (!si) {
                if (sinConfirmar.titulo !== t)
                    sinConfirmar = {titulo: t, desde: Date.now()};
                else if (Date.now() - sinConfirmar.desde >= 20000)
                    si = true;
            }
            if (si) {
                nuevos = nuevos ?? Object.assign({}, confirmados);
                nuevos[t] = true;
            }
        }
        if (nuevos) {
            // Que no crezca sin fin: con muchas, se empieza de nuevo
            if (Object.keys(nuevos).length > 300)
                nuevos = Object.fromEntries(Object.keys(nuevos).slice(-50).map(k => [k, true]));
            confirmados = nuevos;
        }
    }

    // Carátula. Si el reproductor no la manda (Elisa), se saca la que lleva
    // dentro el archivo, o un cover.jpg / folder.jpg de su carpeta; en la
    // misma caché que el dock (~/.cache/quickshell/caratulas)
    function caratula(p) {
        if (!p)
            return "";
        if (p === actual && grande.de === claveYoutube && grande.ruta)
            return grande.ruta;
        if (p.trackArtUrl)
            return p.trackArtUrl;
        return p === actual && extraida.de === archivoActual ? extraida.ruta : "";
    }
    readonly property string archivoActual: actual && !actual.trackArtUrl
        ? String((actual.metadata ?? {})["xesam:url"] ?? "") : ""
    onArchivoActualChanged: if (archivoActual.startsWith("file://")) {
        extraer.running = false;
        extraer.url = archivoActual;
        extraer.running = true;
    }
    // ------------------------------------------- La canción tapada
    // Brave (y Chrome) solo avisan de UNA pestaña: la última que empezó a
    // sonar. Si suena música en YouTube y en otra pestaña o ventana empieza
    // un vídeo (Reddit...), Brave pasa a avisar de ese y la canción
    // desaparecía de la isla. Se recuerda la última canción del navegador y,
    // mientras su pestaña de YouTube siga a la vista en alguna ventana (su
    // título lo dice), la isla la sigue enseñando: «tapada». Los botones no
    // llegan a ella (Brave los manda a la pestaña que avisa), así que la
    // isla los esconde mientras tanto.
    function esNavegador(p) {
        const app = ((p?.desktopEntry ?? "") + " " + (p?.identity ?? "") + " " + (p?.dbusName ?? "")).toLowerCase();
        return navegadores.some(a => app.includes(a));
    }
    property var recordada: null   // {jugador, titulo, artista, caratula}
    function _recordar() {
        const p = actual;
        if (p && p.isPlaying && esNavegador(p) && esMusica(p) && !vistaPrevia(p) && (p.trackTitle ?? "") !== "")
            recordada = {jugador: p, titulo: p.trackTitle, artista: p.trackArtist ?? "", caratula: caratula(p), cuando: Date.now()};
    }
    Timer {
        running: reproductor.todos.some(p => p.isPlaying)
        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            reproductor._confirmar();
            reproductor._recordar();
        }
    }
    readonly property var tapada: {
        const p = actual, c = recordada;
        if (!p || !c || c.jugador !== p || p.trackTitle === c.titulo)
            return null;
        // Una vista previa encima de la canción
        if (vistaPrevia(p))
            return c;
        if (esMusica(p))
            return null;
        const sigue = Object.values(Niri.ventanas).some(v => (v.title ?? "").includes(c.titulo) && /YouTube/.test(v.title ?? ""));
        return sigue ? c : null;
    }

    // YouTube en el navegador: Brave manda una carátula de 150×83 (se ve
    // borrosa). Si la ventana dice que es YouTube, se busca la miniatura
    // grande del vídeo (scripts/caratula_youtube.sh); mientras, la pequeña
    readonly property string claveYoutube: {
        const p = actual;
        if (!p || !navegadores.some(a => ((p.desktopEntry ?? "") + " " + (p.identity ?? "") + " " + (p.dbusName ?? "")).toLowerCase().includes(a)))
            return "";
        const titulo = p.trackTitle ?? "";
        // Sin título, o un vídeo que tapa la canción (no se enseña)
        if (!titulo || tapada)
            return "";
        // Con álbum es música de verdad (Navidrome, YouTube Music...): su
        // carátula ya es buena
        if ((p.trackAlbum ?? "") !== "")
            return "";
        // El título de la ventana es el de la pestaña activa: si se ve la
        // canción, tiene que ser YouTube; si no se ve (la pestaña está
        // detrás), se prueba igual
        const ventanas = Object.values(Niri.ventanas).map(v => v.title ?? "").filter(t => t.includes(titulo));
        if (ventanas.length > 0 && !ventanas.some(t => /YouTube/.test(t) && !/YouTube Music/.test(t)))
            return "";
        return (p.trackArtist ?? "") + "\n" + titulo;
    }
    onClaveYoutubeChanged: if (claveYoutube) {
        buscarGrande.running = false;
        const [artista, titulo] = claveYoutube.split("\n");
        buscarGrande.clave = claveYoutube;
        buscarGrande.command = [Quickshell.shellDir + "/scripts/caratula_youtube.sh", artista, titulo];
        buscarGrande.running = true;
    }
    QtObject {
        id: grande
        property string de: ""
        property string ruta: ""
    }
    Process {
        id: buscarGrande
        property string clave: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const o = text.trim();
                grande.de = buscarGrande.clave;
                grande.ruta = o ? "file://" + o : "";
            }
        }
    }
    QtObject {
        id: extraida
        property string de: ""
        property string ruta: ""
    }
    Process {
        id: extraer
        property string url: ""
        // La ruta de un flatpak (/run/flatpak/doc/…) fuera es /run/user/<uid>/doc/…
        command: ["sh", "-c", 'f=$(python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.argv[1][7:]))" "$1"); ' +
            'case "$f" in /run/flatpak/doc/*) f="$XDG_RUNTIME_DIR/doc/${f#/run/flatpak/doc/}";; esac; ' +
            'c="$HOME/.cache/quickshell/caratulas"; mkdir -p "$c"; o="$c/$(printf %s "$f" | md5sum | cut -c1-16).jpg"; ' +
            '[ -s "$o" ] || ffmpeg -v quiet -y -i "$f" -an -frames:v 1 -vf "scale=300:300:force_original_aspect_ratio=increase" "$o" </dev/null; ' +
            '[ -s "$o" ] && echo "$o" || find "$(dirname "$f")" -maxdepth 1 -type f -iregex ".*/\\(cover\\|folder\\|front\\|album\\)\\.\\(jpe?g\\|png\\)" | head -n1', "sh", url]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = text.trim();
                extraida.de = extraer.url;
                extraida.ruta = o ? "file://" + o : "";
            }
        }
    }

    // ¿Es música? (la luna solo se mece con música, no con cualquier vídeo)
    //  · reproductores de música (Spotify, Elisa...): sí
    //  · mpv, VLC...: según la extensión del archivo
    //  · navegadores (YouTube...): solo si el título o el canal lo parecen
    //    («Video Oficial», «Lyrics», «ft.», «Remix», «- Topic», «VEVO»...)
    readonly property var appsVideo: ["mpv", "vlc", "celluloid", "totem", "showtime", "haruna", "smplayer", "clapper", "kodi"]
    readonly property var navegadores: ["brave", "firefox", "chromium", "chrome", "vivaldi", "opera", "edge", "zen", "librewolf", "epiphany", "falkon", "qutebrowser", "floorp"]
    function esMusica(p) {
        if (!p)
            return false;
        const app = ((p.desktopEntry ?? "") + " " + (p.identity ?? "") + " " + (p.dbusName ?? "")).toLowerCase();
        const md = p.metadata ?? {};
        const url = String(md["xesam:url"] ?? "").toLowerCase();
        if (appsVideo.some(a => app.includes(a))) {
            if (/\.(mp3|flac|ogg|oga|opus|m4a|aac|wav|wma|alac|aiff?|ape|wv)(\?|$)/.test(url))
                return true;
            if (/\.(mkv|mp4|webm|avi|mov|m4v|wmv|flv|ts|mpe?g|3gp)(\?|$)/.test(url))
                return false;
            return (p.trackArtist ?? "") !== "" && (p.trackAlbum ?? "") !== "";
        }
        if (navegadores.some(a => app.includes(a))) {
            if (/music\.youtube\.com|soundcloud\.com|open\.spotify\.com|bandcamp\.com|deezer\.com|tidal\.com/.test(url))
                return true;
            // Con artista y álbum, música (Aonsoku/Navidrome, YouTube Music...
            // en una pestaña: un vídeo normal no manda álbum)
            if ((p.trackArtist ?? "") !== "" && (p.trackAlbum ?? "") !== "")
                return true;
            const titulo = p.trackTitle ?? "";
            const canal = p.trackArtist ?? "";
            if (/(\s-\s*topic$|vevo$|records$|music$)/i.test(canal.trim()))
                return true;
            return /(v[ií]deo\s*(oficial|clip|musical)|official\s*(music\s*)?(video|audio|visualizer|lyric)|music\s*video|lyric|letra|\(audio\)|\[audio\]|visualizer|videoclip|\bft\.|\bfeat\.?\s|\bremix\b|\(prod\.?|\bsped\s*up\b|\bslowed\b|\bacoustic\b|\bac[uú]stico\b|\blive\s*session\b|\bsession\s*#?\d|\bbzrp\b)/i.test(titulo);
        }
        // El resto (Spotify, Elisa, Rhythmbox, Amberol...): reproductores de música
        return true;
    }

    function nombre(p) {
        return p?.identity || p?.desktopEntry || "Reproductor";
    }

    // Título de la canción. Algunos reproductores (Elisa) no lo mandan por
    // MPRIS: entonces se saca del título de su ventana («Canción — Elisa»)
    function titulo(p) {
        if (!p)
            return "";
        if (p.trackTitle)
            return p.trackTitle;
        const app = (p.desktopEntry ?? "").toLowerCase();
        const nombreApp = (p.identity ?? "").toLowerCase();
        const ventana = Object.values(Niri.ventanas).find(v => {
            const id = (v.app_id ?? "").toLowerCase();
            return (app && id === app) || (nombreApp && id.endsWith(nombreApp));
        });
        if (ventana) {
            // Quita « — Elisa», « - Elisa»... del final
            const t = ventana.title.replace(new RegExp("\\s+[—–-]\\s+" + (p.identity ?? "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"), "");
            if (t && t !== p.identity)
                return t;
        }
        // Último recurso: el nombre del archivo (Elisa con un mp3 sin
        // etiquetas deja la ventana en «Elisa» y la barra solo decía eso)
        return nombreArchivo(String((p.metadata ?? {})["xesam:url"] ?? ""));
    }
    function nombreArchivo(url) {
        if (!url)
            return "";
        let n = url.split("/").pop();
        try {
            n = decodeURIComponent(n);
        } catch (e) {}
        return n.replace(/\.[A-Za-z0-9]{2,4}$/, "")      // extensión
            .replace(/_\d+_soundcloud$/i, "")           // «_204992644_soundcloud»
            .replace(/_/g, " ").trim();
    }

    // Siguiente y anterior, también en los navegadores: YouTube en Brave no
    // deja pasar de canción por MPRIS (canGoNext/canGoPrevious a false) y el
    // botón no hacía nada. Entonces, «anterior» vuelve al principio y
    // «siguiente» salta al final, y YouTube pasa solo al siguiente vídeo
    // (con la reproducción automática). Con más de 3 s ya sonados,
    // «anterior» también vuelve al principio, como en cualquier reproductor
    function siguiente(p) {
        if (!p)
            return;
        if (p.canGoNext)
            p.next();
        else if (p.canSeek && p.length > 0)
            p.position = Math.max(0, p.length - 0.5);
    }
    function anterior(p) {
        if (!p)
            return;
        if (p.canGoPrevious && !(p.canSeek && p.position > 3))
            p.previous();
        else if (p.canSeek)
            p.position = 0;
    }
}
