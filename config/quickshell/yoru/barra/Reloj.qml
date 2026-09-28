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
    readonly property var diasLargos: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    // Semana del año (ISO: empieza en lunes; la 1 es la del primer jueves)
    function semana(f) {
        const d = new Date(Date.UTC(f.getFullYear(), f.getMonth(), f.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        return Math.ceil(((d - Date.UTC(d.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    ayuda: {
        const f = reloj.date;
        return `<b>${diasLargos[f.getDay()]}, ${f.getDate()} de ${meses[f.getMonth()]} de ${f.getFullYear()}</b><br>`
            + Tema.suave(`Semana ${semana(f)}  ·  clic: calendario`);
    }

    Modulo {
        texto: Qt.formatDateTime(reloj.date, "HH:mm")
        relleno: 7
        resaltado: Paneles.esta("centro", isla.pantalla, "resumen")
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
        resaltado: Paneles.esta("centro", isla.pantalla, "resumen")
        onClic: Paneles.alternar("centro", isla.pantalla, "resumen")
    }
}
