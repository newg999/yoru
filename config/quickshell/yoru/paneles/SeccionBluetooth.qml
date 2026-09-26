// ============================================================================
//  Dispositivos bluetooth: conectados primero, luego emparejados y el resto.
//    Clic = conectar / desconectar (si es nuevo, lo empareja y conecta)
//    󰆴 = olvidar el dispositivo
//  Mientras la lista está a la vista, se buscan dispositivos nuevos.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.comun

Column {
    id: seccion

    property bool activa: false
    spacing: 4

    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property bool encendido: adaptador?.enabled ?? false
    readonly property var dispositivos: {
        if (!adaptador)
            return [];
        // Los que no tienen nombre (solo la dirección) no dicen nada: fuera
        return adaptador.devices.values
            .filter(d => d.paired || (d.name && d.name.replace(/[-:]/g, "") !== d.address.replace(/[-:]/g, "")))
            .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
    }

    Binding {
        when: seccion.adaptador !== null
        target: seccion.adaptador
        property: "discovering"
        value: seccion.activa && seccion.encendido
    }

    function icono(d) {
        const i = d.icon ?? "";
        if (i.includes("headset")) return "󰋎";
        if (i.includes("headphone") || i.includes("audio")) return "󰋋";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("gaming")) return "󰊴";
        if (i.includes("phone")) return "󰏲";
        if (i.includes("computer")) return "󰟀";
        return "󰂯";
    }

    function detalle(d) {
        if (d.pairing) return "Emparejando…";
        if (d.state === BluetoothDeviceState.Connecting) return "Conectando…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Desconectando…";
        if (d.connected)
            return d.batteryAvailable ? `Conectado · ${Math.round(d.battery * 100)}%` : "Conectado";
        return d.paired ? "Emparejado" : "";
    }

    Titular {
        width: parent.width
        texto: "Dispositivos"

        BotonIcono {
            icono: "󰑐"
            visible: seccion.encendido
            girando: seccion.adaptador?.discovering ?? false
        }
        BotonIcono {
            icono: "󰒓"
            onClic: {
                Paneles.cerrar();
                Quickshell.execDetached(["blueman-manager"]);
            }
        }
    }

    Texto {
        visible: !seccion.encendido || seccion.dispositivos.length === 0
        width: parent.width
        height: 44
        horizontalAlignment: Text.AlignHCenter
        font.bold: false
        font.pixelSize: 12
        color: Tema.gris
        text: !seccion.adaptador ? "No hay bluetooth en este equipo"
            : !seccion.encendido ? "El bluetooth está apagado" : "Buscando dispositivos…"
    }

    Lista {
        width: parent.width
        visible: seccion.encendido
        model: seccion.dispositivos

        delegate: Fila {
            id: fila
            required property var modelData
            readonly property var dispositivo: modelData
            property bool conectarTrasEmparejar: false
            width: ListView.view.width

            icono: seccion.icono(dispositivo)
            titulo: dispositivo.name
            detalle: seccion.detalle(dispositivo)
            seleccionada: dispositivo.connected
            ocupada: dispositivo.pairing || dispositivo.state === BluetoothDeviceState.Connecting
                || dispositivo.state === BluetoothDeviceState.Disconnecting

            onClic: {
                const d = dispositivo;
                if (d.connected) {
                    d.disconnect();
                } else if (d.paired) {
                    d.connect();
                } else {
                    d.trusted = true;
                    conectarTrasEmparejar = true;
                    d.pair();
                }
            }

            Connections {
                target: fila.dispositivo
                function onPairedChanged() {
                    if (fila.dispositivo.paired && fila.conectarTrasEmparejar) {
                        fila.conectarTrasEmparejar = false;
                        fila.dispositivo.connect();
                    }
                }
            }

            BotonIcono {
                visible: fila.dispositivo.paired
                icono: "󰆴"
                colorIcono: fila.dispositivo.connected ? Tema.oscuro : Tema.gris
                onClic: fila.dispositivo.forget()
            }
        }
    }
}
