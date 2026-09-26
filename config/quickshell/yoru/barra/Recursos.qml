// CPU, memoria y batería (la batería se oculta en equipos sin ella)
// Un solo botón: clic = monitor del sistema (procesos y rendimiento)
import QtQuick
import Quickshell.Services.UPower
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 7
    pulsable: true
    onClic: Paneles.alternar("monitor", isla.pantalla, "procesos")

    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria && bateria.isLaptopBattery
    // UPower da la carga de 0 a 1
    readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
    readonly property bool cargando: hayBateria
        && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)

    Modulo {
        icono: "󰘚"
        texto: Sistema.cpu + "%"
        pulsable: false
        resaltado: isla.hover
    }
    Modulo {
        icono: "󰍛"
        texto: Sistema.memoria + "%"
        pulsable: false
        resaltado: isla.hover
    }
    Modulo {
        visible: isla.hayBateria
        readonly property var iconos: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        readonly property int carga: isla.carga
        icono: isla.cargando ? "󰂄" : iconos[Math.min(9, Math.floor(carga / 10))]
        texto: carga + "%"
        pulsable: false
        resaltado: isla.hover
        colorAviso: isla.cargando ? "transparent"
            : carga <= 10 ? Tema.rojo
            : carga <= 25 ? Tema.amarillo : "transparent"
    }
}
