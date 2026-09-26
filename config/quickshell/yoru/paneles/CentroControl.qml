// ============================================================================
//  Centro de control — se abre al pulsar el audio, el wifi o el bluetooth
//
//    ┌──────────────────────────────────┐
//    │ [󰖩 Wi-Fi     󰅀] [󰂯 Bluetooth 󰅀]│  icono = on/off · resto = su lista
//    │ 󰕾 ━━━━━━━━━○──────── 45%  󰅀     │  volumen (󰅀 = elegir salida)
//    │ 󰍬 ━━━━━○──────────── 60%  󰅀     │  micrófono
//    │ ─────────────────────────────── │
//    │  lista de la sección elegida    │  redes, dispositivos o salidas
//    └──────────────────────────────────┘
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
                elegida: panel.seccion === "audio"
                onElegir: panel.elegir("audio")
            }
        }

        // ------------------------------------------------ Lista elegida
        Rectangle {
            visible: panel.seccion !== ""
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Item {
            id: listas
            width: parent.width
            visible: panel.seccion !== ""
            implicitHeight: panel.seccion === "wifi" ? secWifi.implicitHeight
                : panel.seccion === "bluetooth" ? secBt.implicitHeight
                : panel.seccion === "audio" ? secAudio.implicitHeight : 0
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
        }
    }
}
