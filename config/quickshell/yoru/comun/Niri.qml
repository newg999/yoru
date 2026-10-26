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
    signal captura(string ruta)        // una captura de pantalla (Imprimir), ya guardada

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

    // focus-monitor lleva el ratón al centro de esa pantalla: solo se usa si
    // el escritorio está en otra (si no, cada clic movería el ratón)
    function irA(escritorio) {
        const actual = escritorios.find(e => e.is_focused)?.output;
        if (escritorio.output === actual)
            accion("focus-workspace", String(escritorio.idx));
        else
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
    // Siempre se asigna un objeto NUEVO a «ventanas»: si se modifica el mismo
    // y se vuelve a asignar, QML no avisa del cambio (y el dock, por ejemplo,
    // no veía las ventanas nuevas ni las cerradas)
    function _enfocar(id) {
        const vs = {};
        for (const k in ventanas)
            vs[k] = Object.assign({}, ventanas[k], {is_focused: ventanas[k].id === id});
        ventanas = vs;
        enfocada = id !== null && vs[id] ? vs[id] : null;
    }

    // ------------------------------------------------- Ventanas a pares
    // Como en Windows: con dos columnas que llenan la pantalla, al cambiar el
    // ancho de una (Mod+R, Mod+- / Mod+=, o arrastrando su borde), la otra
    // se ajusta para que sigan llenándola. Con más de dos, o si no la
    // llenaban, nada (Ajustes › Aspecto › Ventanas a pares)
    property var _anchoPedido: ({})   // id → ancho que le hemos pedido (su aviso no cuenta)
    function _aPares(cambios) {
        if (!Ajustes.ventanasAPares)
            return;
        const hechas = [];             // una vez por columna (sus ventanas cambian a la vez)
        for (const c of cambios) {
            const v = ventanas[c.id];
            if (!v || v.is_floating || !c.antes?.pos_in_scrolling_layout || !c.ahora?.pos_in_scrolling_layout)
                continue;
            const antes = c.antes.tile_size[0], ahora = c.ahora.tile_size[0];
            if (Math.abs(ahora - antes) < 1)
                continue;
            // El cambio que pedimos nosotros a la otra
            if (c.id in _anchoPedido) {
                const pedido = _anchoPedido[c.id];
                delete _anchoPedido[c.id];
                if (Math.abs(pedido - ahora) <= 2)
                    continue;
            }
            const columna = c.ahora.pos_in_scrolling_layout[0];
            const clave = v.workspace_id + ":" + columna;
            if (hechas.includes(clave))
                continue;
            hechas.push(clave);

            // Las columnas del escritorio: tienen que ser justo dos
            const delEscritorio = Object.values(ventanas).filter(w => w.workspace_id === v.workspace_id
                && !w.is_floating && w.layout?.pos_in_scrolling_layout);
            const columnas = [...new Set(delEscritorio.map(w => w.layout.pos_in_scrolling_layout[0]))];
            if (columnas.length !== 2)
                continue;
            const otra = delEscritorio.find(w => w.layout.pos_in_scrolling_layout[0] !== columna);

            // El ancho útil: la pantalla, menos lo que reserva el dock y los
            // tres huecos (bordes y entre las dos)
            const salida = escritorios.find(e => e.id === v.workspace_id)?.output;
            const pantalla = Quickshell.screens.find(p => p.name === salida);
            if (!pantalla)
                continue;
            const hueco = Ajustes.minimalista ? 0 : Tema.gaps;
            const dock = Ajustes.estiloDock && !Ajustes.dockEsconder && Ajustes.dockLado === "izquierda" ? 56 : 0;
            const util = pantalla.width - dock - 3 * hueco;
            // ¿Llenaban la pantalla antes de este cambio?
            const deLaOtra = otra.layout.tile_size[0];
            if (Math.abs(antes + deLaOtra - util) > 4)
                continue;
            const nuevo = Math.max(240, Math.round(util - ahora));
            if (Math.abs(nuevo - deLaOtra) < 2)
                continue;
            _anchoPedido = Object.assign({}, _anchoPedido, {[otra.id]: nuevo});
            accion("set-window-width", "--id", String(otra.id), String(nuevo));
        }
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
            const nueva = !(v.id in ventanas);
            ventanas = Object.assign({}, ventanas, {[v.id]: v});
            if (v.is_focused)
                _enfocar(v.id);
            if (nueva)
                ventanaNueva(v);
        } else if (ev.WindowClosed) {
            const vs = Object.assign({}, ventanas);
            delete vs[ev.WindowClosed.id];
            ventanas = vs;
            if (enfocada && enfocada.id === ev.WindowClosed.id)
                enfocada = null;
        } else if (ev.WindowLayoutsChanged) {
            // Cambió el tamaño o el sitio de algunas ventanas
            const vs = Object.assign({}, ventanas);
            const cambios = [];
            for (const [id, layout] of ev.WindowLayoutsChanged.changes) {
                if (!vs[id])
                    continue;
                cambios.push({id: id, antes: vs[id].layout, ahora: layout});
                vs[id] = Object.assign({}, vs[id], {layout: layout});
            }
            ventanas = vs;
            _aPares(cambios);
        } else if (ev.ScreenshotCaptured) {
            captura(ev.ScreenshotCaptured.path ?? "");
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
