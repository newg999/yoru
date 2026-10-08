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

ShellRoot {
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
    //   qs -c yoru ipc call panel alternar apagado ""         (o portapapeles, notificaciones, fondos, tienda, velocidad)
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
