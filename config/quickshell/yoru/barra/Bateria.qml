// Batería (solo en equipos que la tienen). Clic = panel de batería
import QtQuick
import Quickshell.Services.UPower
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 7
    pulsable: true
    oculta: !hayBateria
    readonly property bool iluminada: hover || Paneles.esta("bateria", pantalla)
    onClic: Paneles.alternar("bateria", isla.pantalla, "")

    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria && bateria.isLaptopBattery
    // UPower da la carga de 0 a 1
    readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
    readonly property bool cargando: hayBateria
        && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)

    ayuda: `Batería <b>${carga}%</b>` + (cargando ? " · cargando" : "") + "<br>" + Tema.suave("Clic: salud, consumo y perfil de energía")

    Modulo {
        readonly property var iconos: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        icono: isla.cargando ? "󰂄" : iconos[Math.min(9, Math.floor(isla.carga / 10))]
        texto: isla.carga + "%"
        pulsable: false
        resaltado: isla.iluminada
        colorAviso: isla.cargando ? "transparent"
            : isla.carga <= 10 ? Tema.rojo
            : isla.carga <= 25 ? Tema.amarillo : "transparent"
    }
}
