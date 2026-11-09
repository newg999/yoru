// ============================================================================
//  Bloqueo — la pantalla de bloqueo de Yoru (en lugar de swaylock)
//
//  La pide niri/scripts/bloquear.sh (Mod+BackSpace, swayidle, al suspender):
//      qs -c yoru ipc call bloqueo bloquear
//  Usa el bloqueo seguro de Wayland (ext-session-lock): hasta que la
//  contraseña sea correcta, niri no enseña nada más. La contraseña la
//  comprueba PAM con la misma regla que swaylock (/etc/pam.d/swaylock).
//
//  Por inactividad, antes de bloquear la pantalla se va oscureciendo poco a
//  poco (swayidle lo pide unos segundos antes); si tocas algo, vuelve:
//      qs -c yoru ipc call bloqueo atenuar     (y despertar)
//
//  Vista previa (sin bloquear de verdad; «Salir» o la contraseña la cierran):
//      qs -c yoru ipc call bloqueo probar
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
    signal exito()          // contraseña buena: las pantallas hacen su salida

    // Vista previa: lo mismo, en una ventana encima de todo
    property bool probando: false

    function bloquear() {
        if (activo)
            return;
        escrito = "";
        mensaje = "";
        error = false;
        fallos = 0;
        probando = false;
        activo = true;
        Quickshell.execDetached(["touch", marca]);
    }

    function comprobar(contrasena) {
        if (pam.active)
            return;
        pendiente = contrasena;
        mensaje = "";
        // Fuera el rojo del intento anterior: si esta es la buena, no debe
        // verse rojo mientras se abre (si vuelve a fallar, se pone otra vez)
        error = false;
        pam.start();
    }
    property string pendiente: ""

    Timer {
        id: abrir
        interval: Ajustes.animaciones ? 860 : 0
        onTriggered: {
            bloqueo.activo = false;
            bloqueo.probando = false;
            Quickshell.execDetached(["rm", "-f", bloqueo.marca]);
        }
    }

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
                // Primero la salida (el candado se abre y todo sube), luego
                // se desbloquea de verdad
                bloqueo.exito();
                abrir.restart();
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
    onActivoChanged: {
        if (activo)
            leerTeclado.running = true;
        else
            quitarOscuro();
    }

    // ------------------------------------------- Atenuar antes de bloquear
    // Una capa negra encima de todo que se va oscureciendo (15 s, lo que
    // falta para que swayidle bloquee). No coge clics ni teclas: al tocar
    // algo, swayidle lo nota y pide «despertar»
    property real oscuro: 0
    function atenuar() {
        if (activo)
            return;
        aclarar.stop();
        oscurecer.start();
    }
    function despertar() {
        oscurecer.stop();
        aclarar.start();
    }
    function quitarOscuro() {
        oscurecer.stop();
        aclarar.stop();
        oscuro = 0;
    }
    NumberAnimation {
        id: oscurecer
        target: bloqueo
        property: "oscuro"
        to: 0.9
        duration: 15000
        easing.type: Easing.InOutSine
    }
    NumberAnimation {
        id: aclarar
        target: bloqueo
        property: "oscuro"
        to: 0
        duration: 250
        easing.type: Easing.OutCubic
    }
    Variants {
        model: bloqueo.oscuro > 0 ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yoru-atenuar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            color: Qt.rgba(0, 0, 0, bloqueo.oscuro)
        }
    }

    // Lo que se ve, igual en el bloqueo de verdad y en la vista previa
    component Pantalla: Cerradura {
        id: cerradura
        anchors.fill: parent
        animar: Ajustes.animaciones
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
            function onExito() {
                cerradura.salir();
            }
        }

        // En medio, lo que suena y las notificaciones (abiertas hasta un
        // clic fuera o Esc); arriba a la derecha, la red, el bluetooth, el
        // volumen y la batería
        abajo: CentroBloqueo { id: centro }
        onToque: centro.cerrar()
        arriba: EstadoBloqueo {}
    }


    // Vista previa: la misma pantalla en una capa encima de todo, sin
    // bloquear de verdad («Salir», abajo a la derecha, o la contraseña la cierran)
    LazyLoader {
        active: bloqueo.probando
        PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yoru-bloqueo-prueba"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            // Transparente: al acertar se ve el escritorio aparecer debajo
            color: "transparent"
            Pantalla {
                Text {
                    text: "Vista previa · Salir"
                    color: salirZona.containsMouse ? Tema.blanco : Tema.gris
                    font.family: Tema.fuente
                    font.pixelSize: 12
                    font.bold: true
                    MouseArea {
                        id: salirZona
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bloqueo.probando = false
                    }
                }
            }
        }
    }

    WlSessionLock {
        id: cerrojo
        locked: bloqueo.activo

        WlSessionLockSurface {
            id: superficie
            color: Tema.oscuro

            Pantalla {}
        }
    }

    IpcHandler {
        target: "bloqueo"

        function bloquear(): void {
            bloqueo.bloquear();
        }
        // La vista previa (ver arriba)
        function probar(): void {
            if (!bloqueo.activo) {
                bloqueo.escrito = "";
                bloqueo.mensaje = "";
                bloqueo.error = false;
                bloqueo.probando = !bloqueo.probando;
            }
        }
        // Para bloquear.sh: no termina hasta que niri confirma el bloqueo
        // (si no, al suspender se vería el escritorio un instante al volver)
        function bloqueada(): bool {
            return cerrojo.secure;
        }
        // Para inactividad.sh: oscurecer poco a poco antes de bloquear, y
        // volver si tocas algo
        function atenuar(): void {
            bloqueo.atenuar();
        }
        function despertar(): void {
            bloqueo.despertar();
        }
    }
}
