// ============================================================================
//  Sistema — uso de CPU y memoria, temperatura de la CPU y tiempo encendido
//  (lee /proc y /sys cada pocos segundos)
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sistema

    property int cpu: 0          // %
    property int memoria: 0      // %
    property real memUsada: 0    // GiB
    property real memTotal: 0    // GiB
    property int temperatura: 0  // °C de la CPU (0 = no se sabe)
    property int encendido: 0    // segundos desde que arrancó el equipo

    property var _anterior: null // último "cpu ..." de /proc/stat

    function _leer(texto) {
        const lineas = texto.split("\n");

        // CPU: se compara con la lectura anterior (tiempo ocupado / total)
        const n = lineas[0].trim().split(/\s+/).slice(1).map(Number);
        const inactivo = n[3] + n[4];
        const total = n.reduce((a, b) => a + b, 0);
        if (_anterior) {
            const dt = total - _anterior.total;
            if (dt > 0)
                cpu = Math.round(100 * (1 - (inactivo - _anterior.inactivo) / dt));
        }
        _anterior = {total, inactivo};

        // Tiempo encendido y temperatura (líneas "uptime ..." y "temp ...")
        encendido = Math.floor(parseFloat(lineas.find(l => l.startsWith("uptime ")).slice(7)));
        const t = lineas.find(l => l.startsWith("temp "));
        if (t)
            temperatura = Math.round(parseInt(t.slice(5)) / 1000);

        // Memoria: total - disponible
        let totalKb = 0, libreKb = 0;
        for (const l of lineas) {
            if (l.startsWith("MemTotal:"))
                totalKb = parseInt(l.split(/\s+/)[1]);
            else if (l.startsWith("MemAvailable:"))
                libreKb = parseInt(l.split(/\s+/)[1]);
        }
        if (totalKb > 0) {
            memTotal = totalKb / 1048576;
            memUsada = (totalKb - libreKb) / 1048576;
            memoria = Math.round(100 * (totalKb - libreKb) / totalKb);
        }
    }

    Process {
        id: lector
        // La temperatura sale del sensor de la CPU (AMD: k10temp, Intel: coretemp)
        command: ["sh", "-c", `head -1 /proc/stat
            grep -E '^Mem(Total|Available):' /proc/meminfo
            echo "uptime $(cut -d' ' -f1 /proc/uptime)"
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat $h/name)" in k10temp|coretemp|zenpower|cpu_thermal)
                    echo "temp $(cat $h/temp1_input)"; break ;;
                esac
            done`]
        stdout: StdioCollector {
            onStreamFinished: sistema._leer(text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: lector.running = true
    }
}
