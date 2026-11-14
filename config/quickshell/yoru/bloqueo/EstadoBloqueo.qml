// ============================================================================
//  EstadoBloqueo — arriba a la derecha de la pantalla de bloqueo
//
//    󰤨 󰂯 󰕾  │  󰁹 80%
//
//  La red, el bluetooth, el volumen y la batería (si la hay). Lo que no
//  hay, no sale.
// ============================================================================
import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun
import qs.barra

Row {
    id: estado
    spacing: 14
    height: 28

    component Etiqueta: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: Tema.texto
        font.family: Tema.fuente
        font.pixelSize: 14
    }
    component Separador: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 16
        color: Tema.claro(0.2)
    }
    component Boton: Text {
        id: boton
        signal pulsado()
        anchors.verticalCenter: parent.verticalCenter
        color: zona.containsMouse ? Tema.blanco : Tema.gris
        font.family: Tema.fuente
        font.pixelSize: 15
        MouseArea {
            id: zona
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
    }

    // ------------------------------------------- Red, bluetooth y volumen
    readonly property var dispositivos: Networking.devices.values
    readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var salida: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [estado.salida] }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Etiqueta {
            readonly property var senales: ["󰤟", "󰤢", "󰤥", "󰤨"]
            text: estado.cable ? "󰈀"
                : estado.redWifi ? senales[Math.min(3, Math.floor(estado.redWifi.signalStrength * 4))]
                : !Networking.wifiEnabled ? "󰤭" : "󰤮"
        }
        Etiqueta {
            visible: Vpn.conectadas.length > 0
            text: "󰦝"
        }
        Etiqueta {
            visible: estado.adaptador !== null
            text: !estado.adaptador?.enabled ? "󰂲"
                : Bluetooth.devices.values.some(d => d.connected) ? "󰂱" : "󰂯"
            color: estado.adaptador?.enabled ? Tema.texto : Tema.tenue
        }
        Etiqueta {
            readonly property real volumen: estado.salida?.audio?.volume ?? 0
            readonly property bool mudo: estado.salida?.audio?.muted ?? true
            text: mudo ? "󰖁" : volumen < 0.34 ? "󰕿" : volumen < 0.67 ? "󰖀" : "󰕾"
        }
    }

    // ----------------------------------------------------------- Batería
    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria?.isLaptopBattery ?? false
    readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
    readonly property bool cargando: hayBateria
        && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)

    Separador { visible: estado.hayBateria }
    // Como en la barra: con los iconos del dock, la pila dibujada
    // (IconoBateria: se llena por colores, con rayo al cargar); si no, el
    // icono de la letra. Y el porcentaje al lado, del color del texto
    Row {
        visible: estado.hayBateria
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7
        IconoBateria {
            visible: Ajustes.iconosDock
            anchors.verticalCenter: parent.verticalCenter
            carga: estado.carga / 100
            cargando: estado.cargando
        }
        Etiqueta {
            visible: !Ajustes.iconosDock
            readonly property var iconos: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
            text: estado.cargando ? "󰂄" : iconos[Math.min(9, Math.floor(estado.carga / 10))]
            // Por colores: verde llena o cargando y, según baja, amarillo,
            // naranja y rojo (Tema.bateria)
            color: Tema.bateria(estado.carga / 100, estado.cargando)
        }
        Etiqueta {
            text: estado.carga + "%"
            // Baja, en su color de aviso; si no, como el resto
            color: !estado.cargando && estado.carga <= 15 ? Tema.bateria(estado.carga / 100, false) : Tema.texto
        }
    }
}
