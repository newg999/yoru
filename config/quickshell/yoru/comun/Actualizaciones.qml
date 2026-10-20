pragma Singleton

// ============================================================================
//  Actualizaciones — cuántas hay de Fedora (dnf) y de Flatpak
//
//  Se mira un par de minutos después de entrar y luego cada 6 horas
//  (scripts/actualizaciones.py; solo mira, no instala). Tras «Actualizar»,
//  se vuelve a mirar cada pocos minutos hasta que baje la cuenta.
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: act

    property int sistema: 0
    property int seguridad: 0
    property int apps: 0
    property var nombres: []
    readonly property int cuantas: sistema + apps
    property bool mirando: false
    property date ultima: new Date(0)     // cuándo se miró por última vez

    function comprobar() {
        if (!lector.running)
            lector.running = true;
    }

    // Abre la terminal de actualizar (la de la Tienda)
    function actualizar() {
        Niri.lanzar(["python3", Quickshell.shellPath("scripts/tienda.py"), "actualizar"]);
        trasActualizar.vueltas = 0;
        trasActualizar.restart();
    }

    Process {
        id: lector
        command: [Quickshell.shellPath("scripts/actualizaciones.py")]
        onRunningChanged: act.mirando = running
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    act.sistema = d.sistema;
                    act.seguridad = d.seguridad;
                    act.apps = d.apps;
                    act.nombres = d.nombres;
                    act.ultima = new Date();
                } catch (e) {}
            }
        }
    }

    // Al entrar, con calma (que la red y el resto arranquen antes)
    Timer {
        running: true
        interval: 2 * 60 * 1000
        onTriggered: act.comprobar()
    }
    Timer {
        running: true
        repeat: true
        interval: 6 * 60 * 60 * 1000
        onTriggered: act.comprobar()
    }
    // Mientras dura la actualización en la terminal: cada 3 min, hasta 1 h
    Timer {
        id: trasActualizar
        property int vueltas: 0
        interval: 3 * 60 * 1000
        repeat: true
        onTriggered: {
            act.comprobar();
            if (++vueltas >= 20)
                stop();
        }
    }
}
