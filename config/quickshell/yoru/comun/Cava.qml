// ============================================================================
//  Cava — niveles del audio que suena, para el visualizador de la barra
//  Solo está en marcha mientras algún reproductor suena (si no, no gasta nada).
//  Configuración: cava.conf (junto a shell.qml)
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: cava

    property var niveles: [0, 0, 0, 0, 0, 0]     // de 0 a 1, uno por barra
    readonly property bool sonando: Mpris.players.values.some(p => p.isPlaying)

    Process {
        id: proceso
        running: cava.sonando
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: linea => {
                cava.niveles = linea.split(";").filter(n => n !== "").map(n => parseInt(n) / 100);
            }
        }
        onRunningChanged: if (!running) cava.niveles = cava.niveles.map(() => 0)
        // Si se cierra solo (cambias cava.conf, falla el audio...), se vuelve a abrir
        onExited: if (cava.sonando) reintentar.start()
    }

    Timer {
        id: reintentar
        interval: 3000
        onTriggered: proceso.running = Qt.binding(() => cava.sonando)
    }
}
