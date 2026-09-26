// ============================================================================
//  Salidas de audio (altavoces, auriculares, HDMI, bluetooth...) o, con
//  entrada: true, micrófonos.
//  Clic = usar ese dispositivo. El que está en uso va en blanco.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.comun

Column {
    id: seccion
    spacing: 4

    property bool entrada: false     // false = salidas · true = micrófonos

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
        texto: seccion.entrada ? "Micrófono" : "Salida"

        BotonIcono {
            icono: "󰒓"
            onClic: {
                Paneles.cerrar();
                // Abre pavucontrol en su pestaña (3 = salida, 4 = entrada)
                Quickshell.execDetached(["pavucontrol", "-t", seccion.entrada ? "4" : "3"]);
            }
        }
    }

    Repeater {
        model: seccion.entrada ? seccion.entradas : seccion.salidas
        Fila {
            required property var modelData
            width: seccion.width
            icono: seccion.icono(modelData)
            titulo: seccion.nombre(modelData)
            seleccionada: (seccion.entrada ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink) === modelData
            onClic: {
                if (seccion.entrada)
                    Pipewire.preferredDefaultAudioSource = modelData;
                else
                    Pipewire.preferredDefaultAudioSink = modelData;
            }
        }
    }
}
