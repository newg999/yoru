// ============================================================================
//  Raton — por dónde va el cursor, en coordenadas globales (todas las
//  pantallas), para que Hotaru (la luna de la isla) lo mire siempre
//
//  Wayland no le dice a la barra dónde está el cursor si no está encima de
//  ella, así que se juntan dos cosas:
//    · apuntar(): la posición exacta, cuando el ratón pasa por la isla o
//      el escritorio
//    · scripts/cursor.py: cuánto se mueve el ratón (leído de /dev/input,
//      con la aceleración de niri), que se suma a la última posición
//  Sin permiso para leer el ratón (system/udev/70-yoru-raton.rules) solo
//  queda lo primero: la última posición donde se vio.
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: raton

    property var pos: null          // {x, y} o null (aún no se sabe)

    function apuntar(pantalla, x, y) {
        pos = {x: pantalla.x + x, y: pantalla.y + y};
    }

    // Suma el movimiento y lo deja dentro de alguna pantalla, como niri
    function mover(dx, dy) {
        const ps = Quickshell.screens;
        if (ps.length === 0)
            return;
        const ini = pos ?? {x: ps[0].x + ps[0].width / 2, y: ps[0].y + ps[0].height / 2};
        let x = ini.x + dx, y = ini.y + dy;
        let mejor = null, distMejor = Infinity;
        for (const p of ps) {
            const cx = Math.max(p.x, Math.min(p.x + p.width - 1, x));
            const cy = Math.max(p.y, Math.min(p.y + p.height - 1, y));
            const d = (cx - x) ** 2 + (cy - y) ** 2;
            if (d < distMejor) {
                distMejor = d;
                mejor = {x: cx, y: cy};
            }
        }
        pos = mejor;
    }

    Process {
        id: lector
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/cursor.py"]
        stdout: SplitParser {
            onRead: linea => {
                const d = linea.split(" ");
                raton.mover(Number(d[0]) || 0, Number(d[1]) || 0);
            }
        }
        // Si se cae, vuelve a empezar
        onExited: reintentar.start()
    }
    Timer {
        id: reintentar
        interval: 5000
        onTriggered: lector.running = true
    }
}
