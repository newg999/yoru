// ============================================================================
//  Salida y entrada de audio: altavoces, auriculares, HDMI, bluetooth...
//  Clic = usar ese dispositivo. La que está en uso va en blanco.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.comun

Column {
    id: seccion
    spacing: 4

    readonly property var nodos: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var salidas: nodos.filter(n => n.isSink)
    readonly property var entradas: nodos.filter(n => !n.isSink && !n.name.endsWith(".monitor"))

    function nombre(n) {
        return n.description || n.nickname || n.name;
    }
    function icono(n) {
        const t = (n.name + " " + nombre(n)).toLowerCase();
        if (t.includes("headset")) return "󰋎";
        if (t.includes("headphone") || t.includes("auricular") || t.includes("bluez")) return "󰋋";
        // La salida de la gráfica (HDMI/DisplayPort) = el altavoz del monitor
        if (t.includes("hdmi") || t.includes("displayport") || t.includes("high definition audio controller")) return "󰍹";
        if (t.includes("s/pdif") || t.includes("spdif") || t.includes("iec958")) return "󰓃";
        return n.isSink ? "󰓃" : "󰍬";
    }

    Titular {
        width: parent.width
        texto: "Salida"

        BotonIcono {
            icono: "󰒓"
            onClic: {
                Paneles.cerrar();
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }

    Repeater {
        model: seccion.salidas
        Fila {
            required property var modelData
            width: seccion.width
            icono: seccion.icono(modelData)
            titulo: seccion.nombre(modelData)
            seleccionada: Pipewire.defaultAudioSink === modelData
            onClic: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Item { width: 1; height: 4 }

    Titular {
        width: parent.width
        texto: "Micrófono"
    }

    Repeater {
        model: seccion.entradas
        Fila {
            required property var modelData
            width: seccion.width
            icono: seccion.icono(modelData)
            titulo: seccion.nombre(modelData)
            seleccionada: Pipewire.defaultAudioSource === modelData
            onClic: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
}
