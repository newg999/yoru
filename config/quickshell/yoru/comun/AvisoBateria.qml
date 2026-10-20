// ============================================================================
//  AvisoBateria — avisa cuando la batería se está acabando
//
//    20 %  «Batería baja»            aviso normal
//    10 %  «Batería muy baja»        urgente: se queda hasta que lo quites
//     5 %  «Batería casi agotada»    urgente: al 2 % UPower apaga el equipo
//
//  Cada aviso sale una sola vez por descarga, y sustituye al anterior (no
//  se amontonan). Al enchufar el cargador se quita y se vuelve a empezar.
//  Los manda notify-send, así que salen como cualquier otra notificación
//  (y las urgentes, también con «no molestar»).
//
//  Probar sin desenchufar:  qs -c yoru ipc call bateria probar 10
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
    id: aviso

    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria?.isLaptopBattery ?? false
    readonly property bool descargando: hayBateria && UPower.onBattery
    readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 100

    readonly property var niveles: [20, 10, 5]
    property int avisado: 101         // el último nivel avisado en esta descarga
    property string ultimo: ""        // id de la notificación, para sustituirla

    onCargaChanged: revisar()
    onDescargandoChanged: revisar()
    Component.onCompleted: revisar()

    function revisar() {
        if (!descargando) {
            avisado = 101;
            quitar();
            return;
        }
        // El nivel más bajo ya alcanzado (al arrancar con poca batería se
        // avisa solo del de ahora, no de todos los anteriores)
        const nivel = niveles.filter(n => carga <= n).pop();
        if (nivel !== undefined && nivel < avisado) {
            avisado = nivel;
            avisar(nivel, carga, bateria.timeToEmpty);
        }
    }

    function avisar(nivel, porcentaje, segundos) {
        const min = Math.round(segundos / 60);
        const queda = min > 0 ? (min >= 60 ? `Quedan unas ${Math.floor(min / 60)} h ${min % 60} min. ` : `Quedan unos ${min} min. `) : "";
        const [titulo, texto, icono] = nivel <= 5
            ? ["Batería casi agotada", queda + "Al 2 % el equipo se apagará solo: guarda lo que tengas abierto y enchúfalo ya.", "battery-empty"]
            : nivel <= 10
            ? ["Batería muy baja", queda + "Enchufa el portátil pronto.", "battery-caution"]
            : ["Batería baja", queda + "Enchufa el portátil cuando puedas.", "battery-low"];
        const orden = ["notify-send", "-p", "-a", "Batería", "-i", icono,
                       "-u", nivel <= 10 ? "critical" : "normal"];
        if (ultimo !== "")
            orden.push("-r", ultimo);
        envio.command = orden.concat([`${titulo} · ${porcentaje}%`, texto]);
        envio.running = true;
    }

    // Al enchufar, el aviso ya no hace falta
    function quitar() {
        if (ultimo === "")
            return;
        const e = Notificaciones.lista.find(x => String(x.n.id) === ultimo);
        if (e)
            Notificaciones.descartar(e);
        ultimo = "";
    }

    Process {
        id: envio
        stdout: StdioCollector {
            onStreamFinished: aviso.ultimo = text.trim()
        }
    }

    IpcHandler {
        target: "bateria"

        // Enseña el aviso de ese nivel (20, 10 o 5) aunque esté enchufado
        function probar(nivel: int): void {
            aviso.avisar(nivel, nivel, 25 * 60);
        }
    }
}
