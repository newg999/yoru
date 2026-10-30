//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
// ============================================================================
//  Yoru 夜 · escritorio en Quickshell
//
//  Probar sin instalar:     qs -p ~/dotfiles/config/quickshell/yoru
//  Instalado (enlazado):    qs -c yoru
//  Recargar: se recarga solo al guardar cualquier archivo .qml
//  (si creas un archivo nuevo en comun/, reinicia: systemctl --user restart yoru-shell)
//
//    comun/    tema, piezas reutilizables y servicios (niri, cpu...)
//    barra/    la barra y sus islas
//    paneles/  lo que se despliega al pulsar la barra
//
//  Arriba del todo: menús de la bandeja con estilo Qt y tema de iconos de
//  las apps (el mismo Papirus que install.sh pone en GTK)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.comun
import qs.barra
import qs.paneles
import qs.bloqueo

ShellRoot {
    id: raiz

    // El fondo de pantalla, con transición al cambiarlo (barra/Fondo.qml)
    Variants {
        model: Quickshell.screens
        Fondo {}
    }
    // Para wallpaper.sh: si responde, el fondo lo pone Yoru (si no, swaybg)
    IpcHandler {
        target: "fondo"

        function listo(): bool {
            return true;
        }
    }

    // Captura congelada (niri/scripts/captura-editor.sh): una foto de cada
    // pantalla encima de todo, para que no se mueva nada mientras eliges la
    // zona con slurp. (La captura de niri también congela, pero se acuerda del
    // último rectángulo.)
    //   qs -c yoru ipc call congelar mostrar <carpeta con SALIDA.png>
    //   qs -c yoru ipc call congelar quitar
    property string congelada: ""
    Variants {
        model: raiz.congelada !== "" ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yoru-congelado"
            color: "black"
            Image {
                anchors.fill: parent
                source: raiz.congelada !== "" ? "file://" + raiz.congelada + "/" + modelData.name + ".png" : ""
                cache: false
                smooth: false
            }
        }
    }
    IpcHandler {
        target: "congelar"

        function mostrar(carpeta: string): void {
            raiz.congelada = carpeta;
        }
        function quitar(): void {
            raiz.congelada = "";
        }
    }

    // Una barra y un juego de paneles por pantalla
    Variants {
        model: Quickshell.screens
        Barra {}
    }
    // O el estilo Dock: un Quickshell aparte (config/quickshell/yoru-dock, un
    // port de LeyzS QsDock) que se arranca y se para con el estilo. Al
    // pararlo, se quita el espacio que reservaba en niri
    // (solo con ajustes.json ya leído: antes, el estilo aún es el de serie y
    // se cerraba el dock en cada recarga)
    function estiloDock() {
        if (!Ajustes.leido)
            return;
        if (Ajustes.estiloDock)
            Quickshell.execDetached(["qs", "-c", "yoru-dock", "-n", "-d"]);
        else
            Quickshell.execDetached(["sh", "-c",
                'qs kill -c yoru-dock >/dev/null 2>&1; f="$HOME/.local/state/yoru/niri-dock.kdl"; [ -s "$f" ] && : > "$f"; true']);
    }
    Connections {
        target: Ajustes
        function onEstiloDockChanged() {
            raiz.estiloDock();
        }
        function onLeidoChanged() {
            raiz.estiloDock();
        }
    }
    Component.onCompleted: estiloDock()
    // Las páginas (control, calendario, multimedia, clima...) bajo las
    // islas o la minimalista
    Variants {
        model: Quickshell.screens
        PanelPaginas {}
    }
    // O la barra de píldoras: las islas arriba, o la minimalista (la misma
    // en una franja entera) (barra/BarraIslas.qml). Y los widgets sobre el
    // fondo, con cualquier estilo (barra/Escritorio.qml)
    Variants {
        model: Quickshell.screens
        BarraIslas {}
    }
    // O la barra de tareas abajo, como la de Windows 11
    Variants {
        model: Quickshell.screens
        BarraWindows {}
    }
    Variants {
        model: Quickshell.screens
        Escritorio {}
    }
    // Notas adhesivas en el escritorio (barra/NotasEscritorio.qml), con
    // cualquier estilo de barra
    Variants {
        model: Quickshell.screens
        NotasEscritorio {}
    }
    // Dock de apps abajo (barra/Dock.qml)
    Variants {
        model: Quickshell.screens
        Dock {}
    }
    // Ajustes: una ventana aparte, una sola (no una por pantalla)
    VentanaAjustes {}
    Variants {
        model: Quickshell.screens
        PanelBateria {}
    }
    Variants {
        model: Quickshell.screens
        PanelUso {}
    }
    Variants {
        model: Quickshell.screens
        PanelDiscos {}
    }
    Variants {
        model: Quickshell.screens
        PanelActualizaciones {}
    }
    Variants {
        model: Quickshell.screens
        Lanzador {}
    }
    Variants {
        model: Quickshell.screens
        Monitor {}
    }
    Variants {
        model: Quickshell.screens
        Apagado {}
    }
    Variants {
        model: Quickshell.screens
        Portapapeles {}
    }
    Variants {
        model: Quickshell.screens
        Fondos {}
    }
    Variants {
        model: Quickshell.screens
        Tienda {}
    }
    Variants {
        model: Quickshell.screens
        Velocidad {}
    }
    Variants {
        model: Quickshell.screens
        Osd {}
    }
    // Notificaciones: los avisos que llegan y el panel de la campana
    Variants {
        model: Quickshell.screens
        Avisos {}
    }
    Variants {
        model: Quickshell.screens
        PanelNotificaciones {}
    }

    // Abrir paneles desde fuera (atajos de niri, scripts...):
    //   qs -c yoru ipc call panel alternar pildora control    (o wifi, bluetooth, audio, micro,
    //                                                          calendario, multimedia, clima, sistema...)
    //   qs -c yoru ipc call panel alternar lanzador ""        (o medio: en mitad de la pantalla)
    //   qs -c yoru ipc call panel alternar monitor procesos   (o rendimiento)
    //   qs -c yoru ipc call panel alternar uso cpu            (o memoria)
    //   qs -c yoru ipc call panel alternar apagado ""         (o portapapeles, notificaciones, bateria, fondos, tienda, velocidad)
    //   qs -c yoru ipc call panel alternar ajustes tema       (o fondo, barra, aspecto, pantallas, sonido, raton, teclado, atajos, notificaciones, apps;
    //                                                          abre la ventana de Ajustes en esa sección)
    //   qs -c yoru ipc call panel cerrar
    IpcHandler {
        target: "panel"

        function alternar(nombre: string, seccion: string): void {
            // Se abre en la pantalla que tiene el foco
            const salida = Niri.escritorios.find(e => e.is_focused)?.output;
            const pantalla = Quickshell.screens.find(s => s.name === salida) ?? Quickshell.screens[0];
            // Las páginas: el control y sus listas a la derecha (bajo la
            // conexión), el resto en el centro
            // Con el estilo Dock, lo que el dock tiene lo abre él (se
            // transforma en ese panel)
            const delDock = {conexion: "net", notificaciones: "notif", bateria: "bat", lanzador: "apps", fondos: "walls"};
            const pagDock = {wifi: "net", bluetooth: "net", audio: "audio", micro: "audio", control: "dash", sistema: "dash", "": "dash"};
            const modo = nombre === "pildora" ? pagDock[seccion] : nombre === "conexion" && ["audio", "micro"].includes(seccion) ? "audio" : delDock[nombre];
            if (Ajustes.estiloDock && modo) {
                Quickshell.execDetached(["qs", "-c", "yoru-dock", "ipc", "call", "dock", modo]);
                return;
            }
            if (nombre === "pildora")
                Paneles.abrirPagina(pantalla, seccion,
                    ["control", "wifi", "bluetooth", "audio", "micro", ""].includes(seccion) ? "derecha" : "centro");
            else
                Paneles.alternar(nombre, pantalla, seccion);
        }
        function cerrar(): void {
            Paneles.cerrar();
        }
    }

    // Contador de fotogramas (paneles/Fotogramas.qml), para ver si algo va a
    // tirones:  qs -c yoru ipc call fotogramas alternar   (Mod+Alt+F)
    property bool fotogramas: false
    Variants {
        model: Quickshell.screens
        Fotogramas { activo: raiz.fotogramas }
    }
    IpcHandler {
        target: "fotogramas"

        function alternar(): void {
            raiz.fotogramas = !raiz.fotogramas;
        }
    }

    // «No suspender»:  qs -c yoru ipc call despierto alternar
    IpcHandler {
        target: "despierto"

        function alternar(): void {
            Despierto.activo = !Despierto.activo;
        }
    }

    // Pantalla de bloqueo (en vez de swaylock): bloqueo/Bloqueo.qml
    Bloqueo {}

    // Avisos de batería baja (20, 10 y 5 %)
    AvisoBateria {}

    // Teclas de brillo (binds.kdl):  qs -c yoru ipc call brillo subir   (o bajar)
    IpcHandler {
        target: "brillo"

        function subir(): void {
            Brillo.cambiar(0.1);
        }
        function bajar(): void {
            Brillo.cambiar(-0.1);
        }
    }
}
