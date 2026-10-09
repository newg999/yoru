pragma Singleton

// ============================================================================
//  Reproductor — qué reproductor (Spotify, Brave, mpv...) muestran la barra
//  y los paneles. Por defecto, el que está sonando; si eliges uno en la
//  pestaña Multimedia, se queda ese mientras siga abierto.
// ============================================================================
import QtQuick
import Quickshell
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
