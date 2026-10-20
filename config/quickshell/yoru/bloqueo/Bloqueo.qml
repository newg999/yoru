// ============================================================================
//  Bloqueo — la pantalla de bloqueo de Yoru (en lugar de swaylock)
//
//  La pide niri/scripts/bloquear.sh (Mod+BackSpace, swayidle, al suspender):
//      qs -c yoru ipc call bloqueo bloquear
//  Usa el bloqueo seguro de Wayland (ext-session-lock): hasta que la
//  contraseña sea correcta, niri no enseña nada más. La contraseña la
//  comprueba PAM con la misma regla que swaylock (/etc/pam.d/swaylock).
//
//  Si la barra se cae con la pantalla bloqueada, niri la deja bloqueada (en
//  negro). Al volver a arrancar, la barra ve $XDG_RUNTIME_DIR/yoru-bloqueado
//  y bloquea otra vez, para poder entrar. Si aun así no vuelve: Ctrl+Alt+F3,
//  entra y ejecuta «systemctl --user restart yoru-shell».
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.comun

Scope {
    id: bloqueo

    property bool activo: false
    property string escrito: ""           // lo tecleado (igual en todas las pantallas)
    property string mensaje: ""
    property bool error: false
    property int fallos: 0
    readonly property string marca: Quickshell.env("XDG_RUNTIME_DIR") + "/yoru-bloqueado"

    signal fallo()

    function bloquear() {
        if (activo)
            return;
        escrito = "";
        mensaje = "";
        error = false;
        fallos = 0;
        activo = true;
        Quickshell.execDetached(["touch", marca]);
    }

    function comprobar(contrasena) {
        if (pam.active)
            return;
        pendiente = contrasena;
        mensaje = "";
        pam.start();
    }
    property string pendiente: ""

    PamContext {
        id: pam
        config: "swaylock"
        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(bloqueo.pendiente);
            bloqueo.pendiente = "";
        }
        onCompleted: resultado => {
            bloqueo.escrito = "";
            if (resultado === PamResult.Success) {
                bloqueo.activo = false;
                Quickshell.execDetached(["rm", "-f", bloqueo.marca]);
                return;
            }
            bloqueo.fallos++;
            bloqueo.error = true;
            bloqueo.mensaje = bloqueo.fallos > 1 ? `Contraseña incorrecta (${bloqueo.fallos} intentos)` : "Contraseña incorrecta";
            bloqueo.fallo();
        }
        onError: e => {
            bloqueo.escrito = "";
            bloqueo.error = true;
            bloqueo.mensaje = "No se pudo comprobar la contraseña";
        }
    }

    // La pantalla de inicio de sesión (system/greetd/yoru) no puede leer tu
    // carpeta: se le dejan aquí tus colores y tu letra (si install.sh ha
    // creado el archivo y es tuyo; si no, usa los de serie)
    // (con sh y solo si el archivo es tuyo: así nunca falla ni se queja)
    readonly property string estiloInicio: JSON.stringify({
        texto: String(Tema.texto), gris: String(Tema.gris), blanco: String(Tema.blanco),
        fondo: String(Tema.oscuro), rojo: String(Tema.rojo),
        // La Nerd Font está en tu ~/.local: allí, su versión del sistema
        fuente: Tema.fuente === "JetBrainsMono Nerd Font" ? "JetBrains Mono" : Tema.fuente
    })
    onEstiloInicioChanged: guardarEstilo.restart()
    Timer {
        id: guardarEstilo
        interval: 2000
        onTriggered: Quickshell.execDetached(["sh", "-c", 'f=/usr/share/backgrounds/yoru/inicio.json; [ -w "$f" ] && printf %s "$1" > "$f"', "_", bloqueo.estiloInicio])
    }

    // ¿Se quedó bloqueada antes de que la barra se reiniciara?
    FileView {
        path: bloqueo.marca
        printErrors: false
        onLoaded: bloqueo.bloquear()
    }

    // Distribución del teclado (niri), para el botón 󰌌 de la contraseña
    property var teclados: []
    property int tecladoActual: 0
    readonly property string teclado: abreviar(teclados[tecladoActual] ?? "")
    function abreviar(nombre) {
        const conocidos = {"Spanish": "ES", "English (US)": "US", "English (UK)": "UK", "Portuguese": "PT",
                           "French": "FR", "German": "DE", "Italian": "IT", "Catalan": "CA"};
        return conocidos[nombre] ?? nombre.slice(0, 2).toUpperCase();
    }
    Process {
        id: leerTeclado
        command: ["niri", "msg", "-j", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    bloqueo.teclados = d.names;
                    bloqueo.tecladoActual = d.current_idx;
                } catch (e) {}
            }
        }
    }
    onActivoChanged: if (activo) leerTeclado.running = true

    WlSessionLock {
        id: cerrojo
        locked: bloqueo.activo

        WlSessionLockSurface {
            id: superficie
            color: Tema.oscuro

            Cerradura {
                id: cerradura
                anchors.fill: parent
                fondo: "file://" + Quickshell.env("HOME") + "/.cache/fondo-bloqueo-borroso.jpg"
                colorTexto: Tema.texto
                colorGris: Tema.gris
                colorAcento: Tema.blanco
                colorOscuro: Tema.oscuro
                colorRojo: Tema.rojo
                fuente: Tema.fuente
                nombre: Quickshell.env("USER") ?? ""
                fotos: ["file://" + Quickshell.env("HOME") + "/.face",
                        "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER")]
                teclado: bloqueo.teclados.length > 1 ? bloqueo.teclado : ""
                mensaje: bloqueo.mensaje
                error: bloqueo.error
                ocupada: pam.active
                texto: bloqueo.escrito
                onTextoChanged: bloqueo.escrito = texto
                onEnviar: t => bloqueo.comprobar(t)
                onEnergia: accion => Quickshell.execDetached(["systemctl", accion])
                onCambiarTeclado: {
                    Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
                    if (bloqueo.teclados.length)
                        bloqueo.tecladoActual = (bloqueo.tecladoActual + 1) % bloqueo.teclados.length;
                }
                Component.onCompleted: campo.forceActiveFocus()

                Connections {
                    target: bloqueo
                    function onFallo() {
                        cerradura.sacudir();
                        cerradura.campo.forceActiveFocus();
                    }
                }

                // Arriba a la derecha: lo que suena, el tiempo, la red, el
                // bluetooth, el volumen y la batería
                arriba: EstadoBloqueo {}
            }
        }
    }

    IpcHandler {
        target: "bloqueo"

        function bloquear(): void {
            bloqueo.bloquear();
        }
        // Para bloquear.sh: no termina hasta que niri confirma el bloqueo
        // (si no, al suspender se vería el escritorio un instante al volver)
        function bloqueada(): bool {
            return cerrojo.secure;
        }
    }
}
