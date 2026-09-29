// ============================================================================
//  Centro de control — se abre al pulsar el audio, el wifi o el bluetooth
//
//    ┌──────────────────────────────────┐
//    │ [󰖩 Wi-Fi     󰅀] [󰂯 Bluetooth 󰅀]│  icono = on/off · resto = su lista
//    │ 󰕾 ━━━━━━━━━○──────── 45%  󰅀     │  volumen (󰅀 = elegir salida)
//    │ 󰍬 ━━━━━○──────────── 60%  󰅀     │  micrófono (󰅀 = elegir micrófono)
//    │ 󰃠 ━━━━━━━━━━━━○───── 80%        │  brillo (portátil o monitor por DDC)
//    │ [Ahorro] [Equilibrado] [Rendim.]│  perfil de energía
//    │ ─────────────────────────────── │
//    │  lista de la sección elegida    │  redes, dispositivos, salidas o micros
//    │ ─────────────────────────────── │
//    │ Sesión de don    󰌾 󰤄 󰍃 󰜉 󰐥    │  bloquear, suspender, salir, reiniciar,
//    └──────────────────────────────────┘  apagar (los 3 últimos: dos clics)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.comun

Panel {
    id: panel
    nombre: "conexion"
    lado: "derecha"
    ancho: 420

    readonly property string seccion: abierto ? Paneles.seccion : ""
    function elegir(s) {
        Paneles.seccion = Paneles.seccion === s ? "" : s;
    }

    // Datos para las baldosas
    readonly property var dispositivos: Networking.devices.values
    readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var btConectados: Bluetooth.devices.values.filter(d => d.connected)

    // El brillo puede haber cambiado desde fuera (botones del monitor);
    // Brillo.leer() solo relee si hace más de 10 min
    onAbiertoChanged: {
        if (abierto)
            Brillo.leer();
        else
            confirmar = "";
    }

    // ------------------------------------------------------------ Sesión
    // Cerrar sesión, reiniciar y apagar piden un segundo clic (el botón se
    // pone rojo 3 s): un clic sin querer no te cierra todo
    readonly property var sesion: [
        {icono: "󰌾", titulo: "Bloquear", orden: ["sh", "-c", "~/.config/niri/scripts/bloquear.sh"]},
        {icono: "󰤄", titulo: "Suspender", orden: ["sh", "-c", "~/.config/niri/scripts/bloquear.sh && systemctl suspend"]},
        {icono: "󰍃", titulo: "Cerrar sesión", seguro: true, orden: ["niri", "msg", "action", "quit", "--skip-confirmation"]},
        {icono: "󰜉", titulo: "Reiniciar", seguro: true, orden: ["systemctl", "reboot"]},
        {icono: "󰐥", titulo: "Apagar", seguro: true, orden: ["systemctl", "poweroff"]},
    ]
    property string confirmar: ""      // título de la opción esperando el 2.º clic

    function sesionElegir(o) {
        if (o.seguro && confirmar !== o.titulo) {
            confirmar = o.titulo;
            espera.restart();
            return;
        }
        confirmar = "";
        Paneles.cerrar();
        Quickshell.execDetached(o.orden);
    }
    Timer {
        id: espera
        interval: 3000
        onTriggered: panel.confirmar = ""
    }

    Column {
        width: parent.width
        spacing: 10

        // ------------------------------------------------------- Baldosas
        Row {
            width: parent.width
            spacing: 10

            Baldosa {
                width: (parent.width - 10) / 2
                icono: Networking.wifiEnabled ? "󰖩" : "󰖪"
                titulo: "Wi-Fi"
                detalle: panel.redWifi ? panel.redWifi.name
                    : panel.cable ? "Por cable"
                    : Networking.wifiEnabled ? "Sin conectar" : "Apagado"
                encendida: Networking.wifiEnabled
                elegida: panel.seccion === "wifi"
                onAlternar: Networking.wifiEnabled = !Networking.wifiEnabled
                onElegir: panel.elegir("wifi")
            }
            Baldosa {
                width: (parent.width - 10) / 2
                icono: panel.adaptador?.enabled ? "󰂯" : "󰂲"
                titulo: "Bluetooth"
                detalle: !panel.adaptador ? "No disponible"
                    : !panel.adaptador.enabled ? "Apagado"
                    : panel.btConectados.length === 1 ? panel.btConectados[0].name
                    : panel.btConectados.length > 1 ? panel.btConectados.length + " conectados"
                    : "Encendido"
                encendida: panel.adaptador?.enabled ?? false
                elegida: panel.seccion === "bluetooth"
                onAlternar: if (panel.adaptador) panel.adaptador.enabled = !panel.adaptador.enabled
                onElegir: panel.elegir("bluetooth")
            }
        }

        // -------------------------------------------------------- Volumen
        Column {
            width: parent.width
            spacing: 0

            FilaVolumen {
                width: parent.width
                nodo: Pipewire.defaultAudioSink
                elegida: panel.seccion === "audio"
                onElegir: panel.elegir("audio")
            }
            FilaVolumen {
                width: parent.width
                nodo: Pipewire.defaultAudioSource
                iconoOn: "󰍬"
                iconoOff: "󰍭"
                elegida: panel.seccion === "micro"
                onElegir: panel.elegir("micro")
            }

            // Brillo (solo si hay alguna pantalla que lo permita)
            Repeater {
                model: Brillo.pantallas
                FilaBrillo {
                    required property var modelData
                    width: parent.width
                    pantalla: modelData
                    conNombre: Brillo.pantallas.length > 1
                }
            }
        }

        // ------------------------------------------- Perfil de energía
        SelectorEnergia {
            width: parent.width
        }

        // ------------------------------------------------ Lista elegida
        Rectangle {
            visible: panel.seccion !== ""
            width: parent.width
            height: 1
            color: Tema.claro(0.08)
        }

        Item {
            id: listas
            width: parent.width
            visible: panel.seccion !== ""
            implicitHeight: panel.seccion === "wifi" ? secWifi.implicitHeight
                : panel.seccion === "bluetooth" ? secBt.implicitHeight
                : panel.seccion === "audio" ? secAudio.implicitHeight
                : panel.seccion === "micro" ? secMicro.implicitHeight : 0
            height: implicitHeight

            SeccionWifi {
                id: secWifi
                width: parent.width
                activa: panel.seccion === "wifi"
                visible: opacity > 0
                opacity: activa ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            }
            SeccionBluetooth {
                id: secBt
                width: parent.width
                activa: panel.seccion === "bluetooth"
                visible: opacity > 0
                opacity: activa ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            }
            SeccionAudio {
                id: secAudio
                width: parent.width
                visible: opacity > 0
                opacity: panel.seccion === "audio" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            }
            SeccionAudio {
                id: secMicro
                width: parent.width
                entrada: true
                visible: opacity > 0
                opacity: panel.seccion === "micro" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            }
        }

        // ------------------------------------------------------- Sesión
        Rectangle {
            width: parent.width
            height: 1
            color: Tema.claro(0.08)
        }

        Titular {
            width: parent.width
            texto: panel.confirmar !== "" ? panel.confirmar + ": pulsa otra vez"
                : "Sesión de " + Quickshell.env("USER")

            Repeater {
                model: panel.sesion
                BotonIcono {
                    required property var modelData
                    icono: modelData.icono
                    alerta: panel.confirmar === modelData.titulo
                    onClic: panel.sesionElegir(modelData)
                }
            }
        }
    }
}
