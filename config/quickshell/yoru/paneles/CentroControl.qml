// ============================================================================
//  Centro de control — se abre al pulsar el audio, el wifi o el bluetooth
//
//    ┌──────────────────────────────────┐
//    │ [󰖩 Wi-Fi     󰅀] [󰂯 Bluetooth 󰅀]│  icono = on/off · resto = su lista
//    │                                  │  (con cable: 󰈀 Ethernet; el wifi, en su lista)
//    │ [󰖔 Luz noct.  ] [󰂚 No molestar ]│  icono = on/off · resto = sus ajustes
//    │ [󰅶 No suspend.] [󰀝 Modo avión  ]│
//    │ 󰕾 ━━━━━━━━━○──────── 45%  󰅀     │  volumen (󰅀 = elegir salida)
//    │ 󰍬 ━━━━━○──────────── 60%  󰅀     │  micrófono (󰅀 = elegir micrófono)
//    │ 󰃠 ━━━━━━━━━━━━○───── 80%        │  brillo (portátil o monitor por DDC)
//    │ [Ahorro] [Equilibrado] [Rendim.]│  perfil de energía
//    │ ─────────────────────────────── │
//    │  lista de la sección elegida    │  VPN y redes, dispositivos, salidas o micros
//    └──────────────────────────────────┘
//
//  Bloquear, apagar, etc.: botón 󰐥 de la barra (paneles/Apagado.qml)
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

    // (El brillo no se relee al abrir: ddcutil congela el ratón con NVIDIA,
    // ver comun/Brillo.qml)

    Column {
        width: parent.width
        spacing: 10

        // ------------------------------------------------------- Baldosas
        Row {
            width: parent.width
            spacing: 10

            // Con cable es la baldosa del cable (el wifi se enciende y apaga
            // desde su lista); si no, la del wifi
            Baldosa {
                width: (parent.width - 10) / 2
                icono: panel.cable ? "󰈀" : Networking.wifiEnabled ? "󰖩" : "󰖪"
                titulo: panel.cable ? "Ethernet" : "Wi-Fi"
                detalle: panel.cable ? (Vpn.conectadas.length ? "VPN " + Vpn.conectadas[0].nombre : "Conectado")
                    : panel.redWifi ? panel.redWifi.name + (Vpn.conectadas.length ? " · VPN" : "")
                    : Networking.wifiEnabled ? "Sin conectar" : "Apagado"
                encendida: panel.cable !== null || Networking.wifiEnabled
                elegida: panel.seccion === "wifi"
                onAlternar: {
                    if (panel.cable)
                        panel.elegir("wifi");
                    else
                        Networking.wifiEnabled = !Networking.wifiEnabled;
                }
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

        // Luz nocturna y no molestar (clic en el resto: sus ajustes)
        Row {
            width: parent.width
            spacing: 10

            Baldosa {
                width: (parent.width - 10) / 2
                icono: "󰖔"
                titulo: "Luz nocturna"
                detalle: !LuzNocturna.instalada ? "Falta wlsunset"
                    : Ajustes.luzNocturna === "auto" ? "Al anochecer"
                    : Ajustes.luzNocturna === "siempre" ? "Siempre" : "Apagada"
                encendida: LuzNocturna.encendida
                property string ultimo: "auto"     // el modo al que vuelve al encenderla
                onAlternar: {
                    if (LuzNocturna.encendida) {
                        ultimo = Ajustes.luzNocturna;
                        Ajustes.luzNocturna = "apagada";
                    } else {
                        Ajustes.luzNocturna = ultimo;
                    }
                }
                onElegir: Paneles.alternar("ajustes", panel.modelData, "aspecto")
            }
            Baldosa {
                width: (parent.width - 10) / 2
                icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
                titulo: "No molestar"
                detalle: Notificaciones.noMolestar ? "Solo avisos urgentes" : "Apagado"
                encendida: Notificaciones.noMolestar
                onAlternar: Notificaciones.noMolestar = !Notificaciones.noMolestar
                onElegir: Paneles.alternar("notificaciones", panel.modelData, "")
            }
        }

        // No suspender y modo avión
        Row {
            width: parent.width
            spacing: 10

            Baldosa {
                width: (parent.width - 10) / 2
                icono: "󰅶"
                titulo: "No suspender"
                detalle: Despierto.activo ? "Activado" : "Apagado"
                encendida: Despierto.activo
                onAlternar: Despierto.activo = !Despierto.activo
                onElegir: Despierto.activo = !Despierto.activo
            }
            // Wifi y bluetooth apagados a la vez (al quitarlo, se encienden los dos)
            Baldosa {
                readonly property bool avion: !Networking.wifiEnabled && !(panel.adaptador?.enabled ?? false)
                width: (parent.width - 10) / 2
                icono: "󰀝"
                titulo: "Modo avión"
                detalle: avion ? "Sin wifi ni bluetooth" : "Apagado"
                encendida: avion
                onAlternar: {
                    Networking.wifiEnabled = avion;
                    if (panel.adaptador)
                        panel.adaptador.enabled = avion;
                }
                onElegir: alternar()
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
    }
}
