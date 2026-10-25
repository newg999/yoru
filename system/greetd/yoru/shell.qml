// ============================================================================
//  Pantalla de inicio de sesión de Yoru (Quickshell, como usuario greetd)
//
//  niri-greeter.kdl la arranca:  qs -p /etc/greetd/yoru
//  Se ve igual que la pantalla de bloqueo: usa el mismo Cerradura.qml
//  (install.sh lo copia aquí desde config/quickshell/yoru/bloqueo/).
//
//  Lo que no puede leer de tu carpeta personal (el usuario greetd no entra
//  en ella) lo deja tu sesión en /usr/share/backgrounds/yoru/:
//    inicio        tu fondo, ya desenfocado (niri/scripts/wallpaper.sh)
//    inicio.json   colores y letra (bloqueo/Bloqueo.qml, al cambiarlos)
//
//  Si hay varios usuarios, ‹ › (junto al nombre) pasa al siguiente.
//  Abajo a la derecha: la sesión (Niri, Plasma...); abajo a la izquierda, ⏻
//  para suspender, reiniciar y apagar.
//  Si esto falla, niri-greeter.kdl abre gtkgreet en su lugar.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: raiz

    readonly property string carpeta: "/usr/share/backgrounds/yoru/"

    // ------------------------------------------- Colores y letra (o los de serie)
    property var estilo: ({texto: "#e5e9f0", gris: "#8a8f98", blanco: "#ffffff",
                           fondo: "#1a1b1e", rojo: "#bf616a", fuente: "Noto Sans"})
    FileView {
        path: raiz.carpeta + "inicio.json"
        printErrors: false
        onLoaded: {
            try {
                raiz.estilo = Object.assign({}, raiz.estilo, JSON.parse(text()));
            } catch (e) {}
        }
    }

    // ------------------------------------------------------- Usuarios
    // Los de verdad: UID de 1000 en adelante y con un shell para entrar
    property var usuarios: []
    property int elegido: 0
    readonly property var usuario: usuarios[elegido] ?? {nombre: "", visible: ""}
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            raiz.usuarios = text().split("\n").map(l => l.split(":")).filter(c =>
                c.length >= 7 && Number(c[2]) >= 1000 && Number(c[2]) < 60000 && !/nologin|false$/.test(c[6])
            ).map(c => ({nombre: c[0], visible: c[4].split(",")[0] || c[0]}));
        }
    }

    // -------------------------------------------------------- Sesiones
    // Las de /etc/greetd/environments (una orden por línea, la primera es la
    // de siempre); el botón «Sesión» de abajo pasa a la siguiente
    property var sesiones: [["niri-session"]]
    property int sesion: 0
    function nombreSesion(orden) {
        const s = orden.join(" ");
        return /niri/.test(s) ? "Niri" : /plasma/.test(s) ? "Plasma" : /gnome/.test(s) ? "GNOME"
            : /sway/.test(s) ? "Sway" : orden[0].split("/").pop();
    }
    FileView {
        path: "/etc/greetd/environments"
        printErrors: false
        onLoaded: {
            const lista = text().split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#")).map(l => l.split(/\s+/));
            if (lista.length)
                raiz.sesiones = lista;
        }
    }

    // --------------------------------------------------- Iniciar sesión
    property string escrito: ""
    property string mensaje: ""
    property bool error: false
    property bool entrando: false
    property string pendiente: ""
    signal fallo()

    function entrar(contrasena) {
        if (entrando || usuario.nombre === "")
            return;
        pendiente = contrasena;
        mensaje = "";
        entrando = true;
        Greetd.createSession(usuario.nombre);
    }

    function fallar(texto) {
        Greetd.cancelSession();
        escrito = "";
        entrando = false;
        error = true;
        mensaje = texto;
        fallo();
    }

    Connections {
        target: Greetd
        function onAuthMessage(texto, esError, hayQueResponder, verRespuesta) {
            if (hayQueResponder) {
                Greetd.respond(raiz.pendiente);
                raiz.pendiente = "";
            } else if (esError) {
                raiz.mensaje = texto;
            }
        }
        function onAuthFailure(texto) {
            raiz.fallar("Contraseña incorrecta");
        }
        function onError(texto) {
            raiz.fallar("No se pudo entrar: " + texto);
        }
        function onReadyToLaunch() {
            raiz.mensaje = "Entrando…";
            Greetd.launch(raiz.sesiones[raiz.sesion]);
        }
    }

    // ------------------------------------------------------- Pantallas
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ventana
            required property ShellScreen modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: raiz.estilo.fondo

            Cerradura {
                id: cerradura
                anchors.fill: parent
                fondo: "file://" + raiz.carpeta + "inicio"
                colorTexto: raiz.estilo.texto
                colorGris: raiz.estilo.gris
                colorAcento: raiz.estilo.blanco
                colorOscuro: raiz.estilo.fondo
                colorRojo: raiz.estilo.rojo
                fuente: raiz.estilo.fuente
                nombre: raiz.usuario.visible
                mensaje: raiz.mensaje
                error: raiz.error
                ocupada: raiz.entrando
                texto: raiz.escrito
                onTextoChanged: raiz.escrito = texto
                onEnviar: t => raiz.entrar(t)
                Component.onCompleted: campo.forceActiveFocus()

                Connections {
                    target: raiz
                    function onFallo() {
                        cerradura.sacudir();
                        cerradura.campo.forceActiveFocus();
                    }
                }

                fotos: raiz.usuario.nombre ? ["file:///var/lib/AccountsService/icons/" + raiz.usuario.nombre] : []
                onEnergia: accion => Quickshell.execDetached(["systemctl", accion])
                onCambiarTeclado: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])

                // Quién entra; con varios usuarios, ‹ › pasa al siguiente
                encima: Row {
                    spacing: 14
                    Text {
                        visible: raiz.usuarios.length > 1
                        text: "‹"
                        color: raiz.estilo.gris
                        font.family: raiz.estilo.fuente
                        font.pixelSize: 18
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: raiz.elegido = (raiz.elegido + raiz.usuarios.length - 1) % raiz.usuarios.length
                        }
                    }
                    Text {
                        text: raiz.usuario.visible
                        color: raiz.estilo.texto
                        font.family: raiz.estilo.fuente
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        visible: raiz.usuarios.length > 1
                        text: "›"
                        color: raiz.estilo.gris
                        font.family: raiz.estilo.fuente
                        font.pixelSize: 18
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: raiz.elegido = (raiz.elegido + 1) % raiz.usuarios.length
                        }
                    }
                }

                // Abajo a la derecha: qué sesión arranca (si hay más de una)
                Rectangle {
                    visible: raiz.sesiones.length > 1
                    width: etiqueta.implicitWidth + 28
                    height: 36
                    radius: 18
                    color: zona.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                    Text {
                        id: etiqueta
                        anchors.centerIn: parent
                        text: "Sesión: " + raiz.nombreSesion(raiz.sesiones[raiz.sesion])
                        color: raiz.estilo.texto
                        font.family: raiz.estilo.fuente
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: raiz.sesion = (raiz.sesion + 1) % raiz.sesiones.length
                    }
                }
            }
        }
    }
}
