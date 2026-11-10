pragma Singleton

// ============================================================================
//  Tareas — las apps del dock (barra/Dock.qml) y de la barra de tareas
//  (barra/BarraWindows.qml): las fijadas primero (comun/Favoritos.qml, en su
//  orden) y luego las abiertas que no lo son, cada una con sus ventanas.
//
//    Tareas.apps          [{clave, entrada, appId, fija, ventanas: [...]}]
//    Tareas.lanzar(app)   abre otra ventana · Tareas.irA(ventana)
//    Tareas.alternar(app) el clic de la barra de Windows: abrir, ir a ella o,
//                         si ya tiene el foco, minimizarla (como en Windows)
//    Tareas.minimizar(v) · Tareas.minimizada(v) · Tareas.cerrar(v)
//    Tareas.cerrarTodas(app)
//  Niri no sabe minimizar: las minimizadas se van a un escritorio escondido
//  («minimizadas», al final, que no sale en la barra) y al volver regresan
//  al escritorio en el que estaban.
//  El menú de clic derecho de las dos: barra/MenuApp.qml
// ============================================================================
import QtQuick
import Quickshell

Singleton {
    id: tareas

    // Una entrada por app: las favoritas primero (en su orden) y luego las
    // abiertas que no lo son, en el orden en que se abrieron
    readonly property var apps: {
        DesktopEntries.applications.values;   // recalcular cuando carguen las apps
        const grupos = new Map();
        for (const id of Favoritos.ids) {
            const entrada = DesktopEntries.byId(id);
            if (entrada)
                grupos.set(id, {clave: id, entrada, appId: id, fija: true, ventanas: []});
        }
        const ventanas = Object.values(Niri.ventanas).sort((a, b) => a.id - b.id);
        for (const v of ventanas) {
            const entrada = DesktopEntries.heuristicLookup(v.app_id);
            const clave = entrada?.id ?? v.app_id;
            if (!grupos.has(clave))
                grupos.set(clave, {clave, entrada, appId: v.app_id, fija: false, ventanas: []});
            grupos.get(clave).ventanas.push(v);
        }
        return [...grupos.values()];
    }
    readonly property int fijas: apps.filter(a => a.fija).length

    function nombre(app) {
        return app.entrada?.name ?? app.appId;
    }

    function icono(app) {
        return Quickshell.iconPath(app.entrada?.icon ?? app.appId, true)
            || Quickshell.iconPath("application-x-executable");
    }

    function enfocada(app) {
        return app.ventanas.some(v => v.id === Niri.enfocada?.id);
    }

    // Dónde está una ventana: «Escritorio 2» (y la pantalla, si hay varias)
    function lugar(v) {
        const e = Niri.escritorios.find(e => e.id === v.workspace_id);
        if (!e)
            return "";
        return "Escritorio " + e.idx + (Quickshell.screens.length > 1 ? " · " + e.output : "");
    }

    function lanzar(app) {
        const e = app.entrada;
        if (!e)
            return;
        // Como el lanzador: lo abre niri (sobrevive a reiniciar la barra)
        const orden = e.runInTerminal ? ["kitty", "--", ...e.command] : e.command;
        Niri.lanzar(e.workingDirectory
            ? ["sh", "-c", 'cd "$1" && shift && exec "$@"', "_", e.workingDirectory, ...orden]
            : orden);
        Niri.accion("close-overview");
    }

    // ------------------------------------------------------ Minimizar
    readonly property string escondido: "minimizadas"
    property var origen: ({})     // id de la ventana → escritorio del que vino

    function minimizada(v) {
        return Niri.escritorios.find(e => e.id === v.workspace_id)?.name === escondido;
    }

    function minimizar(v) {
        const desde = Niri.escritorios.find(e => e.id === v.workspace_id);
        if (!desde || desde.name === escondido)
            return;
        origen = Object.assign({}, origen, {[v.id]: desde.id});
        // El escritorio escondido, o si no lo hay, el vacío del final de su
        // pantalla con ese nombre (así queda detrás de los de verdad)
        const hay = Niri.escritorios.some(e => e.name === escondido);
        const ultimo = Math.max(...Niri.escritoriosDe(desde.output).map(e => e.idx), 0) + 1;
        Quickshell.execDetached(["sh", "-c",
            (hay ? "" : `niri msg action set-workspace-name --workspace ${ultimo} ${escondido} && `)
            + `niri msg action move-window-to-workspace --window-id ${v.id} --focus false ${escondido}`]);
    }

    // Vuelve a su escritorio (o al de ahora, si ya no existe) con el foco.
    // Si era la última, el escondido pierde el nombre y niri lo quita
    function restaurar(v) {
        const vuelta = Niri.escritorios.find(e => e.id === origen[v.id] && e.name !== escondido)
            ?? Niri.escritorios.find(e => e.is_focused && e.name !== escondido);
        const o = Object.assign({}, origen);
        delete o[v.id];
        origen = o;
        const quedan = Object.values(Niri.ventanas).some(w => w.id !== v.id && minimizada(w));
        Quickshell.execDetached(["sh", "-c",
            (vuelta ? `niri msg action move-window-to-workspace --window-id ${v.id} --focus false ${vuelta.idx} && ` : "")
            + `niri msg action focus-window --id ${v.id} && niri msg action close-overview`
            + (quedan ? "" : ` && niri msg action unset-workspace-name ${escondido}`)]);
    }

    // Ir a una ventana (si está minimizada, la trae). Primero el foco y
    // luego cerrar el overview: así se acerca a esa ventana
    function irA(v) {
        if (minimizada(v))
            return restaurar(v);
        Quickshell.execDetached(["sh", "-c",
            `niri msg action focus-window --id ${v.id} && niri msg action close-overview`]);
    }

    // La que usaste por última vez (mejor una que no esté minimizada)
    function ultimaUsada(vs) {
        const visibles = vs.filter(v => !minimizada(v));
        return (visibles.length > 0 ? visibles : vs).slice().sort((a, b) =>
            (b.focus_timestamp?.secs ?? 0) - (a.focus_timestamp?.secs ?? 0)
            || (b.focus_timestamp?.nanos ?? 0) - (a.focus_timestamp?.nanos ?? 0))[0];
    }

    // Como en Windows 11 con una app de varias ventanas (kitty): si ninguna
    // suya tiene el foco, va a la última que usaste; si una lo tiene, cada
    // clic pasa a la siguiente y tras la última vuelve a la primera. El orden
    // es el de apertura (app.ventanas va por id), así que siempre es el mismo
    // y se recorren todas, también las minimizadas (irA las trae).
    function siguiente(app) {
        const vs = app.ventanas;
        const i = vs.findIndex(v => v.id === Niri.enfocada?.id);
        irA(i < 0 ? ultimaUsada(vs) : vs[(i + 1) % vs.length]);
    }

    // Como en Windows: sin ventanas la abre; con varias, va pasando de una a
    // otra (siguiente); con una, si tiene el foco la minimiza y si no va a ella
    function alternar(app) {
        const vs = app.ventanas;
        if (vs.length === 0)
            return lanzar(app);
        if (vs.length > 1)
            return siguiente(app);
        if (vs[0].id === Niri.enfocada?.id)
            return minimizar(vs[0]);
        irA(vs[0]);
    }

    function cerrar(v) {
        Niri.accion("close-window", "--id", String(v.id));
    }

    function cerrarTodas(app) {
        for (const v of app.ventanas)
            Niri.accion("close-window", "--id", String(v.id));
    }
}
