// CPU o memoria, cada una en su isla (cual: "cpu" | "memoria")
// Clic = su panel (PanelUso: gráfica y lo que más gasta)
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    property string cual: "cpu"
    relleno: 7
    pulsable: true
    // Iluminada también con su panel abierto (ver Paneles.esta)
    readonly property bool iluminada: hover || Paneles.esta("uso", pantalla, cual)
    onClic: Paneles.alternar("uso", isla.pantalla, cual)

    function duracion(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
    ayuda: (cual === "cpu"
            ? `CPU <b>${Sistema.cpu}%</b>` + (Sistema.temperatura > 0 ? `  ·  ${Sistema.temperatura}°C` : "")
            : `Memoria <b>${Sistema.memUsada.toFixed(1)}</b> de ${Sistema.memTotal.toFixed(1)} GiB`)
        + `<br>` + Tema.suave(`Encendido hace ${duracion(Sistema.encendido)}  ·  clic: más detalle`)

    Modulo {
        icono: isla.cual === "cpu" ? "󰘚" : "󰍛"
        texto: (isla.cual === "cpu" ? Sistema.cpu : Sistema.memoria) + "%"
        pulsable: false
        resaltado: isla.iluminada
    }
}
