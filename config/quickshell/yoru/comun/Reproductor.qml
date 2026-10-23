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
        if (elegido && todos.includes(elegido))
            return elegido;
        return todos.find(p => p.isPlaying)
            ?? todos.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }

    // Carátula. Si el reproductor no la manda (Elisa), se saca la que lleva
    // dentro el archivo, o un cover.jpg / folder.jpg de su carpeta; en la
    // misma caché que el dock (~/.cache/quickshell/caratulas)
    function caratula(p) {
        if (!p)
            return "";
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
        if (!ventana)
            return "";
        // Quita « — Elisa», « - Elisa»... del final
        const t = ventana.title.replace(new RegExp("\\s+[—–-]\\s+" + (p.identity ?? "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"), "");
        return t === p.identity ? "" : t;
    }
}
