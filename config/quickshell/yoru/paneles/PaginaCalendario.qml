// ============================================================================
//  Página «calendario» de la píldora (Pildora.qml): el mes, como en el panel
//  central (Calendario.qml). Se abre al pulsar la hora con la píldora abierta.
//    󰅁 󰅂, rueda o ← → = cambiar de mes · clic en el título o Inicio = hoy
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Column {
    id: pagina

    property bool activa: false
    spacing: 6

    readonly property var dias: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    onActivaChanged: {
        if (activa) {
            calendario.volverAHoy();
            calendario.forceActiveFocus();
        }
    }

    // Hoy, en grande
    Item {
        width: parent.width
        height: 52
        Column {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            Texto {
                text: pagina.dias[reloj.date.getDay()]
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
            Texto {
                text: reloj.date.getDate() + " de " + pagina.meses[reloj.date.getMonth()]
                font.pixelSize: 20
                color: Tema.blanco
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 290
        radius: Tema.esquina(12)
        color: Tema.caja

        Calendario {
            id: calendario
            anchors { fill: parent; margins: 10 }
            conApp: false
        }
    }
}
