// CPU, memoria o temperatura, cada una en su isla (cual: "cpu" | "memoria" |
// "temperatura") · Clic en CPU o memoria = su panel (PanelUso: gráfica y lo
// que más gasta); la temperatura solo se ve (en rojo si pasa de 85°)
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    property string cual: "cpu"
    relleno: 7
    pulsable: cual !== "temperatura"
    oculta: cual === "temperatura" && Sistema.temperatura <= 0
    // Iluminada también con su panel abierto (ver Paneles.esta)
    readonly property bool iluminada: hover || Paneles.esta("uso", pantalla, cual)
    onClic: Paneles.alternar("uso", isla.pantalla, cual)

    function duracion(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
    ayuda: cual === "temperatura" ? `Temperatura de la CPU <b>${Sistema.temperatura}°C</b>`
        : (cual === "cpu"
            ? `CPU <b>${Sistema.cpu}%</b>` + (Sistema.temperatura > 0 ? `  ·  ${Sistema.temperatura}°C` : "")
            : `Memoria <b>${Sistema.memUsada.toFixed(1)}</b> de ${Sistema.memTotal.toFixed(1)} GiB`)
        + `<br>` + Tema.suave(`Encendido hace ${duracion(Sistema.encendido)}  ·  clic: más detalle`)

    Modulo {
        icono: isla.cual === "cpu" ? "󰘚" : isla.cual === "memoria" ? "󰍛" : "󰔏"
        texto: isla.cual === "temperatura" ? Sistema.temperatura + "°"
            : (isla.cual === "cpu" ? Sistema.cpu : Sistema.memoria) + "%"
        colorAviso: isla.cual === "temperatura" && Sistema.temperatura > 85 ? Tema.rojo : "transparent"
        pulsable: false
        resaltado: isla.iluminada
    }
}
