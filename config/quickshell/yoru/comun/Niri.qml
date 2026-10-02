// ============================================================================
//  Niri — escritorios y ventanas, escuchando "niri msg --json event-stream"
//  Niri manda primero el estado completo y luego solo los cambios.
//  Referencia de eventos: https://niri-wm.github.io/niri/IPC.html
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: niri

    property var escritorios: []   // [{id, idx, name, output, is_active, is_focused...}]
    property var ventanas: ({})    // id → {id, title, app_id, workspace_id, is_focused...}
    property var enfocada: null    // ventana con el foco (o null)
    property bool overview: false  // overview abierto (Mod+Tab): la barra se esconde

    // Se ha abierto una ventana nueva (no un cambio de título o de foco)
    signal ventanaNueva(var ventana)

    // Escritorios de una pantalla, en orden
    function escritoriosDe(salida) {
        return escritorios.filter(e => e.output === salida).sort((a, b) => a.idx - b.idx);
    }

    // Ventana activa en una pantalla (cada barra muestra la suya), o null
    function ventanaEn(salida) {
        const activo = escritorios.find(e => e.output === salida && e.is_active);
        if (!activo || activo.active_window_id === null)
            return null;
        return ventanas[activo.active_window_id] ?? null;
    }

    function irA(escritorio) {
        Quickshell.execDetached(["sh", "-c",
            `niri msg action focus-monitor '${escritorio.output}' && niri msg action focus-workspace ${escritorio.idx}`]);
    }

    function accion(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    // Abrir apps y programas que deben seguir vivos aunque se reinicie la
    // barra: los lanza niri, cada uno en su propio grupo de systemd. Con
    // execDetached quedarían dentro de yoru-shell.service y se cerrarían al
    // reiniciarlo (systemctl --user restart yoru-shell, yoru reload...).
    function lanzar(orden) {
        Quickshell.execDetached(["niri", "msg", "action", "spawn", "--", ...orden]);
    }

    // ---------------------------------------------------------- Eventos
    function _enfocar(id) {
        const vs = ventanas;
        for (const k in vs)
            vs[k].is_focused = (vs[k].id === id);
        ventanas = vs;
        enfocada = id !== null && vs[id] ? vs[id] : null;
    }

    function _procesar(linea) {
        let ev;
        try {
            ev = JSON.parse(linea);
        } catch (e) {
            return;
        }

        if (ev.WorkspacesChanged) {
            escritorios = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated) {
            const {id, focused} = ev.WorkspaceActivated;
            const salida = escritorios.find(e => e.id === id)?.output;
            escritorios = escritorios.map(e => {
                const c = Object.assign({}, e);
                if (e.output === salida)
                    c.is_active = (e.id === id);
                if (focused)
                    c.is_focused = (e.id === id);
                return c;
            });
        } else if (ev.WorkspaceActiveWindowChanged) {
            const {workspace_id, active_window_id} = ev.WorkspaceActiveWindowChanged;
            escritorios = escritorios.map(e => e.id === workspace_id
                ? Object.assign({}, e, {active_window_id}) : e);
        } else if (ev.WindowsChanged) {
            const vs = {};
            for (const v of ev.WindowsChanged.windows)
                vs[v.id] = v;
            ventanas = vs;
            enfocada = ev.WindowsChanged.windows.find(v => v.is_focused) ?? null;
        } else if (ev.WindowOpenedOrChanged) {
            const v = ev.WindowOpenedOrChanged.window;
            const vs = ventanas;
            const nueva = !(v.id in vs);
            vs[v.id] = v;
            ventanas = vs;
            if (v.is_focused)
                _enfocar(v.id);
            else
                ventanasChanged();
            if (nueva)
                ventanaNueva(v);
        } else if (ev.WindowClosed) {
            const vs = ventanas;
            delete vs[ev.WindowClosed.id];
            ventanas = vs;
            if (enfocada && enfocada.id === ev.WindowClosed.id)
                enfocada = null;
        } else if (ev.OverviewOpenedOrClosed) {
            overview = ev.OverviewOpenedOrClosed.is_open;
        } else if (ev.WindowFocusChanged) {
            _enfocar(ev.WindowFocusChanged.id);
        }
    }

    Process {
        id: flujo
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: linea => niri._procesar(linea)
        }
        // Si niri se reinicia o se corta, se vuelve a conectar
        onExited: reconectar.start()
    }

    Timer {
        id: reconectar
        interval: 1000
        onTriggered: flujo.running = true
    }
}
