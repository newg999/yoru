// ============================================================================
//  Páginas «red», «bt» y «sonido»: solo lo de la ficha que se pulsó en las
//  islas en píldoras (barra/BarraIslas.qml), como en el dock
//
//    red      [󰖩 Wi-Fi  ●]  y debajo las VPN y las redes (SeccionWifi)
//    bt       [󰂯 Bluetooth ●]  y los dispositivos (SeccionBluetooth)
//    sonido   salidas y micrófonos, con su volumen (SeccionAudio)
//
//  El centro de control entero sigue en la página «control» (ver Paginas.qml)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

Column {
    id: pagina

    property string cual: "red"
    property bool activa: false
    spacing: 10

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var btConectados: Bluetooth.devices.values.filter(d => d.connected)

    // ------------------------------------------------------------- Red
    Baldosa {
        visible: pagina.cual === "red"
        width: parent.width
        conFlecha: false
        icono: Networking.wifiEnabled ? "󰖩" : "󰖪"
        titulo: "Wi-Fi"
        detalle: pagina.redWifi ? pagina.redWifi.name : Networking.wifiEnabled ? "Sin conectar" : "Apagado"
        encendida: Networking.wifiEnabled
        onAlternar: Networking.wifiEnabled = !Networking.wifiEnabled
        onElegir: alternar()
    }
    SeccionWifi {
        visible: pagina.cual === "red"
        width: parent.width
        activa: pagina.activa && pagina.cual === "red"
    }

    // ------------------------------------------------------- Bluetooth
    Baldosa {
        visible: pagina.cual === "bt"
        width: parent.width
        conFlecha: false
        icono: pagina.adaptador?.enabled ? "󰂯" : "󰂲"
        titulo: "Bluetooth"
        detalle: !pagina.adaptador ? "No disponible"
            : !pagina.adaptador.enabled ? "Apagado"
            : pagina.btConectados.length === 1 ? pagina.btConectados[0].name
            : pagina.btConectados.length > 1 ? pagina.btConectados.length + " conectados"
            : "Encendido"
        encendida: pagina.adaptador?.enabled ?? false
        onAlternar: Radios.alternarBluetooth()
        onElegir: alternar()
    }
    SeccionBluetooth {
        visible: pagina.cual === "bt"
        width: parent.width
        activa: pagina.activa && pagina.cual === "bt"
    }

    // ---------------------------------------------------------- Sonido
    SeccionAudio {
        visible: pagina.cual === "sonido"
        width: parent.width
        volumen: true
    }
    SeccionAudio {
        visible: pagina.cual === "sonido"
        width: parent.width
        entrada: true
        volumen: true
    }
}
