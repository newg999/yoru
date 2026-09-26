// Reloj y fecha · Clic = panel central (calendario, clima, música...)
import QtQuick
import Quickshell
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 7

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    readonly property var diasSemana: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]

    Modulo {
        texto: Qt.formatDateTime(reloj.date, "HH:mm")
        relleno: 7
        onClic: Paneles.alternar("centro", isla.pantalla, "resumen")
    }
    Texto {
        text: "•"
        color: Tema.tenue
        height: Tema.altoBarra
    }
    Modulo {
        texto: isla.diasSemana[reloj.date.getDay()] + " " + reloj.date.getDate()
        relleno: 7
        onClic: Paneles.alternar("centro", isla.pantalla, "resumen")
    }
}
