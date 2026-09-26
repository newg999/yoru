// ============================================================================
//  Audio, wifi y bluetooth: un solo botón (como en DMS)
//    Clic = centro de control · Rueda = volumen
//    Clic central = silenciar · Clic derecho = mezclador (pavucontrol)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 5
    pulsable: true

    onClic: boton => {
        if (boton === Qt.MiddleButton)
            salida.audio.muted = !mudo;
        else if (boton === Qt.RightButton)
            Quickshell.execDetached(["pavucontrol"]);
        else
            Paneles.alternar("conexion", isla.pantalla, "");
    }
    onRueda: pasos => cambiarVolumen(pasos)

    // ---------------------------------------------------------------- Audio
    readonly property var salida: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [isla.salida] }

    readonly property real volumen: salida?.audio?.volume ?? 0
    readonly property bool mudo: salida?.audio?.muted ?? true

    function iconoAudio() {
        if (mudo || !salida)
            return "󰖁";
        const nombre = (salida.name + " " + (salida.description ?? "")).toLowerCase();
        if (nombre.includes("headset"))
            return "󰋎";
        if (nombre.includes("headphone") || nombre.includes("auricular") || nombre.includes("bluez"))
            return "󰋋";
        if (nombre.includes("hdmi") || nombre.includes("displayport"))
            return "󰍹";
        return volumen < 0.34 ? "󰕿" : volumen < 0.67 ? "󰖀" : "󰕾";
    }

    function cambiarVolumen(pasos) {
        if (!salida?.audio)
            return;
        salida.audio.muted = false;
        salida.audio.volume = Math.max(0, Math.min(1, Math.round(volumen * 20 + pasos) / 20));
    }

    Modulo {
        icono: isla.iconoAudio()
        relleno: 4
        apagado: isla.mudo
        pulsable: false
        resaltado: isla.hover
    }

    // ----------------------------------------------------------------- Red
    readonly property var dispositivos: Networking.devices.values
    readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null

    Modulo {
        readonly property var senales: ["󰤟", "󰤢", "󰤥", "󰤨"]
        icono: isla.cable ? "󰈀"
            : isla.redWifi ? senales[Math.min(3, Math.floor(isla.redWifi.signalStrength * 4))]
            : !Networking.wifiEnabled ? "󰤭" : "󰤮"
        colorAviso: !isla.cable && !isla.redWifi && Networking.wifiEnabled ? Tema.rojo : "transparent"
        apagado: !isla.cable && !Networking.wifiEnabled
        pulsable: false
        resaltado: isla.hover
    }

    // ----------------------------------------------------------- Bluetooth
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property int conectados: Bluetooth.devices.values.filter(d => d.connected).length

    Modulo {
        visible: isla.adaptador !== null
        icono: !isla.adaptador?.enabled ? "󰂲" : isla.conectados > 0 ? "󰂱" : "󰂯"
        texto: isla.conectados > 0 ? String(isla.conectados) : ""
        tamIcono: Tema.icono
        apagado: !isla.adaptador?.enabled
        pulsable: false
        resaltado: isla.hover
    }
}
