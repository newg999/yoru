// ============================================================================
//  Música/vídeo que suena (Spotify, YouTube en Brave, mpv...)
//  Botones anterior · play/pausa · siguiente y la canción. Sin reproductor
//  (o parado), la isla desaparece.
//  En la canción: clic = pausa · clic derecho = siguiente · clic central = anterior
// ============================================================================
import QtQuick
import Quickshell.Services.Mpris
import qs.comun

Isla {
    id: isla
    property int maximo: 300     // ancho máximo del título (la barra lo sube en monitores grandes)

    // El que está sonando; si no, el primero que esté en pausa
    readonly property var reproductor: {
        const lista = Mpris.players.values;
        return lista.find(p => p.isPlaying)
            ?? lista.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property string cancion: {
        if (!reproductor)
            return "";
        const artista = reproductor.trackArtist ?? "";
        const titulo = reproductor.trackTitle ?? "";
        return artista && titulo ? `${artista} · ${titulo}` : (titulo || artista);
    }

    relleno: 7

    Modulo {
        visible: isla.reproductor !== null
        icono: "󰒮"
        tamIcono: 17
        relleno: 7
        onClic: isla.reproductor.previous()
    }
    Modulo {
        visible: isla.reproductor !== null
        icono: isla.reproductor?.isPlaying ? "󰏤" : "󰐊"
        tamIcono: 20
        relleno: 7
        onClic: isla.reproductor.togglePlaying()
    }
    Modulo {
        visible: isla.reproductor !== null
        icono: "󰒭"
        tamIcono: 17
        relleno: 7
        onClic: isla.reproductor.next()
    }
    Modulo {
        visible: isla.reproductor !== null && isla.cancion !== ""
        icono: "󰝚"
        texto: isla.cancion
        anchoTexto: isla.maximo
        apagado: !isla.reproductor?.isPlaying
        onClic: boton => {
            if (boton === Qt.RightButton)
                isla.reproductor.next();
            else if (boton === Qt.MiddleButton)
                isla.reproductor.previous();
            else
                isla.reproductor.togglePlaying();
        }
    }
}
