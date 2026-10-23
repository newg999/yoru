pragma Singleton

// ============================================================================
//  Grabacion — grabar la pantalla (scripts/grabar.sh: slurp + wf-recorder)
//
//    alternar()   si no graba, eliges qué grabar (clic = pantalla entera,
//                 arrastrar = zona); mientras eliges, cancela; si graba,
//                 para y guarda
//    grabando     hay una grabación en marcha (la isla roja de la barra)
//    segundos     lo que lleva
//
//  Los vídeos van a ~/Vídeos/Grabaciones. Al parar sale un aviso: clic = verlo.
//  Con sonido (Ajustes.grabarSonido) graba lo que suena; con micrófono
//  (Ajustes.grabarMicro), lo que dices.
//
//  Desde fuera (Mod+Alt+R):  qs -c yoru ipc call grabacion alternar
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: raiz

    property bool grabando: false
    property string archivo: ""
    property int segundos: 0
    readonly property string tiempo: {
        const m = Math.floor(segundos / 60), s = segundos % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function alternar() {
        if (proceso.running) {
            if (grabando)
                proceso.signal(2);   // SIGINT: wf-recorder cierra bien el vídeo
            else
                Quickshell.execDetached(["pkill", "-x", "slurp"]);   // eligiendo zona: cancelar
            return;
        }
        Paneles.cerrar();
        archivo = "";
        segundos = 0;
        proceso.command = [Quickshell.shellPath("scripts/grabar.sh")]
            .concat(Ajustes.grabarSonido ? ["sonido"] : [])
            .concat(Ajustes.grabarMicro ? ["micro"] : []);
        proceso.running = true;
    }

    Process {
        id: proceso
        // La primera línea es el archivo: entonces empieza a grabar
        stdout: SplitParser {
            onRead: linea => {
                if (raiz.archivo !== "")
                    return;
                raiz.archivo = linea;
                raiz.grabando = true;
            }
        }
        onExited: (codigo, estado) => {
            const habia = raiz.grabando;
            raiz.grabando = false;
            if (habia && raiz.archivo !== "")
                raiz.avisar(raiz.archivo);
        }
    }

    Timer {
        interval: 1000
        running: raiz.grabando
        repeat: true
        onTriggered: raiz.segundos++
    }

    // Aviso con «Ver» (clic en el aviso) y «Abrir carpeta»
    function avisar(f) {
        Quickshell.execDetached(["bash", "-c", `
            f="$1"
            [ -s "$f" ] || { notify-send -a Grabación -u critical "No se pudo guardar la grabación"; exit; }
            r=$(notify-send -a Grabación -i video-x-generic -A default=Ver -A carpeta="Abrir carpeta" \\
                "Grabación guardada" "$(basename "$f") · ${raiz.tiempo}")
            case "$r" in
                default) xdg-open "$f" ;;
                carpeta) nautilus --select "$f" 2>/dev/null || xdg-open "$(dirname "$f")" ;;
            esac`, "aviso", f]);
    }

    IpcHandler {
        target: "grabacion"
        function alternar(): void {
            raiz.alternar();
        }
    }
}
