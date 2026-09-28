// ============================================================================
//  Bloqueo — pantalla de bloqueo de Yoru (protocolo ext-session-lock: mientras
//  está puesta, niri no enseña nada más ni deja usar el escritorio).
//
//  Se bloquea con ~/.config/niri/scripts/bloquear.sh (Mod+BackSpace, al
//  suspender, a los 5 min sin usar el equipo...), que a su vez hace:
//     qs -c yoru ipc call bloqueo bloquear
//  y, si Quickshell no contesta, usa swaylock para que nunca quede sin bloquear.
//
//  La contraseña se comprueba con PAM (la misma configuración que «login»).
//
//  Si Quickshell se cae con la pantalla bloqueada, niri sigue bloqueado y
//  systemd lo vuelve a arrancar: al arrancar ve la marca que se deja en
//  $XDG_RUNTIME_DIR y vuelve a poner el bloqueo.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.comun

Scope {
    id: bloqueo

    property bool bloqueada: false
    property bool comprobando: false
    property string error: ""
    property string _clave: ""
    signal fallo()

    readonly property string marca: Quickshell.env("XDG_RUNTIME_DIR") + "/yoru-bloqueado"

    function bloquear() {
        if (bloqueada)
            return;
        error = "";
        bloqueada = true;
        Quickshell.execDetached(["touch", marca]);
        Paneles.cerrar();
    }

    function comprobar(clave) {
        if (comprobando || clave === "")
            return;
        _clave = clave;
        error = "";
        comprobando = true;
        if (!pam.start()) {
            comprobando = false;
            _clave = "";
            error = "No se pudo comprobar la contraseña";
            fallo();
        }
    }

    function desbloquear() {
        bloqueada = false;
        Quickshell.execDetached(["rm", "-f", marca]);
    }

    PamContext {
        id: pam
        // config: "login" (el valor por defecto; swaylock usa lo mismo)

        onPamMessage: {
            if (responseRequired)
                respond(bloqueo._clave);
            else if (messageIsError)
                bloqueo.error = message;
        }
        onCompleted: result => {
            bloqueo.comprobando = false;
            bloqueo._clave = "";
            if (result === PamResult.Success) {
                bloqueo.desbloquear();
                return;
            }
            bloqueo.error = result === PamResult.MaxTries ? "Demasiados intentos: espera un poco"
                : "Contraseña incorrecta";
            bloqueo.fallo();
        }
        onError: e => {
            bloqueo.comprobando = false;
            bloqueo._clave = "";
            bloqueo.error = "No se pudo comprobar: " + PamError.toString(e);
            bloqueo.fallo();
        }
    }

    WlSessionLock {
        id: sesion
        locked: bloqueo.bloqueada

        WlSessionLockSurface {
            color: Tema.oscuro

            PantallaBloqueo {
                anchors.fill: parent
                bloqueo: bloqueo
                Component.onCompleted: enfocar()
            }
        }
    }

    // Al arrancar: ¿se cayó Quickshell con la pantalla bloqueada?
    Process {
        running: true
        command: ["test", "-e", bloqueo.marca]
        onExited: codigo => {
            if (codigo === 0)
                bloqueo.bloquear();
        }
    }

    //   qs -c yoru ipc call bloqueo bloquear
    //   qs -c yoru ipc call bloqueo bloqueada    → true cuando niri ya lo ha puesto
    IpcHandler {
        target: "bloqueo"

        function bloquear(): void {
            bloqueo.bloquear();
        }
        function bloqueada(): bool {
            return sesion.secure;
        }
    }
}
