// ============================================================================
//  Yoru 夜 · escritorio en Quickshell
//
//  Probar sin instalar:     qs -p ~/dotfiles/config/quickshell/yoru
//  Instalado (enlazado):    qs -c yoru
//  Recargar: se recarga solo al guardar cualquier archivo .qml
//
//    comun/    tema, piezas reutilizables y servicios (niri, cpu...)
//    barra/    la barra y sus islas
//    paneles/  lo que se despliega al pulsar la barra
// ============================================================================
//@ pragma UseQApplication
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
    Variants {
        model: Quickshell.screens
        CentroControl {}
    }

    // Abrir paneles desde fuera (atajos de niri, scripts...):
    //   qs -c yoru ipc call panel alternar conexion wifi
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
}
