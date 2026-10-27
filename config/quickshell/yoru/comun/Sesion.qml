pragma Singleton

// ============================================================================
//  Sesion — bloquear, suspender, cerrar sesión, reiniciar y apagar
//
//  Lo usa el menú de apagado (paneles/Apagado.qml). Para añadir opciones:
//  una línea en «opciones».
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sesion

    readonly property var opciones: [
        {icono: "󰌾", titulo: "Bloquear", tecla: "b", orden: ["sh", "-c", "~/.config/niri/scripts/bloquear.sh"]},
        {icono: "󰤄", titulo: "Suspender", tecla: "s", orden: ["sh", "-c", "~/.config/niri/scripts/bloquear.sh && systemctl suspend"]},
        {icono: "󰍃", titulo: "Cerrar sesión", tecla: "c", peligrosa: true, orden: ["niri", "msg", "action", "quit", "--skip-confirmation"]},
        {icono: "󰜉", titulo: "Reiniciar", tecla: "r", peligrosa: true, orden: ["systemctl", "reboot"]},
        {icono: "󰐥", titulo: "Apagar", tecla: "a", peligrosa: true, orden: ["systemctl", "poweroff"]},
    ]

    property string encendido: ""     // "3 h 20 min", de /proc/uptime
    function leerEncendido() {
        uptime.reload();
    }

    function elegir(opcion) {
        if (!opcion)
            return;
        Paneles.cerrar();
        Quickshell.execDetached(opcion.orden);
    }

    FileView {
        id: uptime
        path: "/proc/uptime"
        onLoaded: {
            const min = Math.floor(parseFloat(text()) / 60);
            const h = Math.floor(min / 60);
            sesion.encendido = (h > 0 ? h + " h " : "") + (min % 60) + " min";
        }
    }
}
