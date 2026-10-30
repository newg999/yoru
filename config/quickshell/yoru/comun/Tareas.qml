pragma Singleton

// ============================================================================
//  Tareas — las apps del dock (barra/Dock.qml) y de la barra de tareas
//  (barra/BarraWindows.qml): las fijadas primero (comun/Favoritos.qml, en su
//  orden) y luego las abiertas que no lo son, cada una con sus ventanas.
//
//    Tareas.apps          [{clave, entrada, appId, fija, ventanas: [...]}]
//    Tareas.lanzar(app)   abre otra ventana · Tareas.irA(ventana)
//    Tareas.cerrarTodas(app)
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

    // Ir a una ventana. Primero el foco y luego cerrar el overview: así se
    // acerca a esa ventana
    function irA(v) {
        Quickshell.execDetached(["sh", "-c",
            `niri msg action focus-window --id ${v.id} && niri msg action close-overview`]);
    }

    function cerrarTodas(app) {
        for (const v of app.ventanas)
            Niri.accion("close-window", "--id", String(v.id));
    }
}
