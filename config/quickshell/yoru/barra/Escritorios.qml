// Escritorios de esta pantalla: 󰝥 el activo, 󰝦 los demás.
// Clic = ir a ese escritorio · Rueda = anterior / siguiente
import QtQuick
import qs.comun

Isla {
    id: isla
    required property string salida
    relleno: 6

    Repeater {
        model: Niri.escritoriosDe(isla.salida)

        Modulo {
            required property var modelData
            icono: modelData.is_active ? "󰝥" : "󰝦"
            tamIcono: 15
            relleno: 6
            apagado: !modelData.is_active
            colorAviso: modelData.is_urgent ? Tema.rojo : "transparent"
            onClic: Niri.irA(modelData)
            onRueda: pasos => Niri.accion(pasos > 0 ? "focus-workspace-up" : "focus-workspace-down")
        }
    }
}
