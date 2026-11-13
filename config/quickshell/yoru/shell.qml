//@ pragma UseQApplication
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
    // (cada estilo de barra, y el dock, solo existe si está elegido: crearlos
    // todos, aunque no se vieran, retrasaba la barra al entrar)
    LazyLoader {
        active: Ajustes.vertical
        Variants {
            model: Quickshell.screens
            Barra {}
        }
    }
    Component.onCompleted: {
        // El estilo Dock (yoru-dock) ya no existe: si quedó uno abierto de
        // antes, se cierra, y fuera el espacio que reservaba en niri
        Quickshell.execDetached(["sh", "-c",
            'qs kill -c yoru-dock >/dev/null 2>&1; rm -f "$HOME/.local/state/yoru/niri-dock.kdl"; true']);
        // Bluetooth: como lo dejaste la última vez (comun/Radios.qml)
        Radios.recuerdo;
    }
    // Los paneles (páginas, Ajustes, lanzador, monitor, tienda...) se crean
    // en segundo plano (LazyLoader con «loading»), después de la barra y el
    // fondo: creándolos todos antes, la barra tardaba un par de segundos en
    // salir al entrar en la sesión
    // Las páginas (control, calendario, multimedia, clima...) bajo las
    // islas o la minimalista
    LazyLoader {
        loading: true
        Variants {
            model: Quickshell.screens
            PanelPaginas {}
        }
    }
    // O la barra de píldoras: las islas arriba, o la minimalista (la misma
    // en una franja entera) (barra/BarraIslas.qml). Y los widgets sobre el
    // fondo, con cualquier estilo (barra/Escritorio.qml)
    Variants {
        model: Quickshell.screens
        BarraIslas {}
    }
    // O una sola isla viva arriba, con la lunita (barra/BarraIsla.qml)
    LazyLoader {
        active: Ajustes.isla
        Variants {
            model: Quickshell.screens
            BarraIsla {}
        }
    }
    // O la barra de tareas abajo, como la de Windows 11
    LazyLoader {
        active: Ajustes.windows
        Variants {
            model: Quickshell.screens
            BarraWindows {}
        }
    }
    Variants {
        model: Quickshell.screens
        Escritorio {}
    }
    // Archivos y accesos directos de ~/Escritorio sobre el fondo, como en
    // Windows (barra/IconosEscritorio.qml), en la primera pantalla
    LazyLoader {
        active: Widgets.iconos
        Variants {
            model: Quickshell.screens.slice(0, 1)
            IconosEscritorio {}
        }
    }
    // Notas adhesivas en el escritorio (barra/NotasEscritorio.qml), con
    // cualquier estilo de barra
    Variants {
        model: Quickshell.screens
        NotasEscritorio {}
    }
    // Dock de apps abajo (barra/Dock.qml)
    LazyLoader {
        active: Ajustes.dock !== "nunca" && !Ajustes.windows
        Variants {
            model: Quickshell.screens
            Dock {}
        }
    }
    // Ajustes: una ventana aparte, una sola (no una por pantalla)
    LazyLoader {
        loading: true
        Scope {
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
                PanelMega {}
            }
            Variants {
                model: Quickshell.screens
                PanelBandeja {}
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
        }
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
    LazyLoader {
        loading: true
        Variants {
            model: Quickshell.screens
            PanelNotificaciones {}
        }
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
    // El menú de la isla (estilo Isla), en la pantalla con el foco:
    //   qs -c yoru ipc call isla menu          (Mod+X)     o sistema, bandeja
    IpcHandler {
        target: "isla"
        function abrirEn(pagina: int): void {
            const salida = Niri.escritorios.find(e => e.is_focused)?.output ?? Quickshell.screens[0]?.name;
            Paneles.menuIsla(salida, pagina);
        }
        function menu(): void { abrirEn(1); }
        function sistema(): void { abrirEn(0); }
        function bandeja(): void { abrirEn(2); }
    }
    IpcHandler {
        target: "panel"

        function alternar(nombre: string, seccion: string): void {
            // Se abre en la pantalla que tiene el foco
            const salida = Niri.escritorios.find(e => e.is_focused)?.output;
            const pantalla = Quickshell.screens.find(s => s.name === salida) ?? Quickshell.screens[0];
            // Las páginas: el control y sus listas a la derecha (bajo la
            // conexión), el resto en el centro
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
    LazyLoader {
        loading: true
        Variants {
            model: Quickshell.screens
            Fotogramas { activo: raiz.fotogramas }
        }
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
