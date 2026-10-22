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
import qs.comun
import qs.barra
import qs.paneles
import qs.bloqueo

ShellRoot {
    id: raiz

    // Una barra y un juego de paneles por pantalla
    Variants {
        model: Quickshell.screens
        Barra {}
    }
    // Dock de apps abajo (barra/Dock.qml)
    Variants {
        model: Quickshell.screens
        Dock {}
    }
    Variants {
        model: Quickshell.screens
        CentroControl {}
    }
    Variants {
        model: Quickshell.screens
        PanelCentral {}
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
    //   qs -c yoru ipc call panel alternar conexion wifi     (o bluetooth, audio, micro)
    //   qs -c yoru ipc call panel alternar centro resumen     (o clima)
    //   qs -c yoru ipc call panel alternar lanzador ""        (o medio: en mitad de la pantalla)
    //   qs -c yoru ipc call panel alternar monitor procesos   (o rendimiento)
    //   qs -c yoru ipc call panel alternar uso cpu            (o memoria)
    //   qs -c yoru ipc call panel alternar apagado ""         (o portapapeles, notificaciones, bateria, fondos, tienda, velocidad)
    //   qs -c yoru ipc call panel alternar ajustes tema       (o fondo, barra, aspecto, pantallas, sonido, raton, teclado, notificaciones, apps;
    //                                                          abre la ventana de Ajustes en esa sección)
    //   qs -c yoru ipc call panel cerrar
    IpcHandler {
        target: "panel"

        function alternar(nombre: string, seccion: string): void {
            // Se abre en la pantalla que tiene el foco
            const salida = Niri.escritorios.find(e => e.is_focused)?.output;
            const pantalla = Quickshell.screens.find(s => s.name === salida) ?? Quickshell.screens[0];
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
