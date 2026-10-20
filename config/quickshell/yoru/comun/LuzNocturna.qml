pragma Singleton

// ============================================================================
//  LuzNocturna — pantalla más cálida (menos luz azul) con wlsunset
//
//    Ajustes.luzNocturna   "apagada" · "auto" (al anochecer) · "siempre"
//    Ajustes.calidez       temperatura de color de noche, en K (6500 = normal)
//
//  «auto» usa la ubicación del clima (Tiempo.qml) para saber cuándo se pone
//  y sale el sol; sin ubicación, de 20:30 a 7:30. «siempre» es el mismo
//  wlsunset con el día igual de cálido que la noche.
//  Quickshell lo arranca y lo para: no hace falta nada en config.kdl.
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: luz

    property bool instalada: false
    readonly property bool encendida: Ajustes.luzNocturna !== "apagada"

    readonly property var orden: {
        const t = String(Ajustes.calidez);
        if (Ajustes.luzNocturna === "siempre")
            return ["wlsunset", "-t", t, "-T", String(Ajustes.calidez + 1)];
        const sitio = isNaN(Tiempo.latitud)
            ? ["-S", "07:30", "-s", "20:30"]
            : ["-l", Tiempo.latitud.toFixed(2), "-L", Tiempo.longitud.toFixed(2)];
        return ["wlsunset", "-t", t, "-T", "6500", ...sitio];
    }

    Process {
        id: proceso
        running: luz.instalada && luz.encendida
        command: luz.orden
    }
    // Un cambio (calidez, modo, ubicación) con wlsunset en marcha: se relanza
    onOrdenChanged: if (proceso.running) {
        proceso.running = false;
        reinicio.restart();
    }
    Timer {
        id: reinicio
        interval: 200
        onTriggered: proceso.running = Qt.binding(() => luz.instalada && luz.encendida)
    }

    // ¿Está wlsunset? Mientras no, se mira cada 10 s: así, al instalarlo,
    // funciona sin reiniciar la barra
    Process {
        id: comprobar
        running: true
        command: ["sh", "-c", "command -v wlsunset"]
        onExited: codigo => luz.instalada = codigo === 0
    }
    Timer {
        running: !luz.instalada
        interval: 10000
        repeat: true
        onTriggered: comprobar.running = true
    }
}
