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

    readonly property var todos: Mpris.players.values
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
}
