// Reloj y fecha · Clic = el calendario, debajo
// Hora y día son un solo botón: la isla entera se ilumina y se pulsa
// Con la barra a la izquierda, las horas sobre los minutos y el día debajo
import QtQuick
import Quickshell
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 7
    pulsable: true
    onClic: Paneles.abrirPagina(isla.pantalla, "calendario", "centro")
    readonly property bool iluminada: isla.hover || Paneles.esta("pildora", isla.pantalla, "calendario")

    SystemClock {
        id: reloj
        precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes
    }

    // Ajustes › Fecha y hora: 24 o 12 horas y con o sin segundos (en
    // vertical, sin segundos: no caben)
    readonly property string formato: isla.vertical ? (Ajustes.reloj24 ? "HH\nmm" : "h\nmm")
        : (Ajustes.reloj24 ? "HH:mm" : "h:mm") + (Ajustes.relojSegundos ? ":ss" : "") + (Ajustes.reloj24 ? "" : " AP")

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
        texto: Qt.formatDateTime(reloj.date, isla.formato)
        relleno: 7
        pulsable: false
        resaltado: isla.iluminada
    }
    Texto {
        text: isla.vertical ? "··" : "•"
        color: isla.iluminada ? Tema.gris : Tema.tenue
        Behavior on color { ColorAnimation { duration: Tema.rapida } }
        height: isla.vertical ? 10 : Tema.altoBarra
    }
    Modulo {
        texto: isla.diasSemana[reloj.date.getDay()] + (isla.vertical ? "\n" : " ") + reloj.date.getDate()
        relleno: 7
        pulsable: false
        resaltado: isla.iluminada
    }
}
