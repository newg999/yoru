// ============================================================================
//  Notificaciones — Quickshell hace de servidor de notificaciones (en lugar
//  de mako): las guarda, decide cuáles salen como aviso y lleva el «no
//  molestar».
//
//    lista        todas las que siguen abiertas, la más nueva primero
//    sinLeer      las que han llegado desde la última vez que se vieron (panel
//                 de notificaciones o centro de control): la campana de la
//                 barra y su punto rojo solo salen si hay alguna
//    emergentes   las que se ven ahora arriba a la derecha (Avisos.qml)
//    noMolestar   sin avisos emergentes (salvo las urgentes); se guardan igual
//
//  De Ajustes › Notificaciones: las apps silenciadas no salen como aviso ni
//  suenan (sí quedan en el panel), y el sonido al llegar.
//
//  Cada entrada lleva la notificación (n) y la hora a la que llegó (hora).
//  Probar:  notify-send "Hola" "Funciona"
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: raiz

    property var lista: []
    property var emergentes: []
    property bool noMolestar: false
    readonly property int cuantas: lista.length
    property int sinLeer: 0
    readonly property bool hayNuevas: sinLeer > 0 && cuantas > 0

    // Abrir el panel de notificaciones o el centro de control (que también
    // las enseña) = verlas todas
    function vistas() {
        if (Paneles.abierto === "notificaciones"
            || (Paneles.abierto === "pildora" && ["control", "", "wifi", "bluetooth", "audio", "micro"].includes(Paneles.seccion)))
            sinLeer = 0;
    }
    Connections {
        target: Paneles
        function onAbiertoChanged() { raiz.vistas(); }
        function onSeccionChanged() { raiz.vistas(); }
    }
    onCuantasChanged: if (cuantas === 0) sinLeer = 0

    // Para las horas relativas («hace 5 min»): se actualiza cada 30 s
    property date ahora: new Date()
    Timer {
        interval: 30000
        running: raiz.lista.length > 0
        repeat: true
        onTriggered: raiz.ahora = new Date()
    }

    NotificationServer {
        id: servidor
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            raiz.ahora = new Date();
            // Una que sustituye a otra (misma id): sube arriba del todo
            const e = raiz.lista.find(x => x.n === n) ?? {n: n, hora: raiz.ahora};
            e.hora = raiz.ahora;
            raiz.lista = [e].concat(raiz.lista.filter(x => x !== e));
            n.closed.connect(() => raiz.quitar(n));

            const app = raiz.app(n);
            if (app !== "" && !Ajustes.appsAvisos.includes(app))
                Ajustes.appsAvisos = Ajustes.appsAvisos.concat([app]).sort((a, b) => a.localeCompare(b));
            if (Ajustes.silenciadas.includes(app))
                return;
            // Una nueva cuenta como sin leer, salvo si ya se están viendo
            // (las de apps silenciadas no llegan aquí: no cuentan)
            raiz.sinLeer++;
            raiz.vistas();

            const urgente = n.urgency === NotificationUrgency.Critical;
            if (!raiz.noMolestar || urgente)
                raiz.emergentes = [e].concat(raiz.emergentes.filter(x => x !== e));
            if (Ajustes.avisosSonido && (!raiz.noMolestar || urgente))
                raiz.sonar();
        }
    }

    // Al recargar la barra (guardar un .qml) el servidor conserva las
    // notificaciones, pero la lista empieza vacía: se rehace
    Component.onCompleted: {
        // Para el estilo Dock (ver exportar)
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"]);
        lista = servidor.trackedNotifications.values.slice().reverse().map(n => {
            n.closed.connect(() => raiz.quitar(n));
            return {n: n, hora: new Date()};
        });
    }

    // El nombre de la app que la manda (para silenciarla)
    function app(n) {
        return (n.appName || n.desktopEntry || "").trim();
    }

    function sonar() {
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/message.oga"]);
    }

    // La app la cerró, o la cerramos nosotros
    function quitar(n) {
        lista = lista.filter(e => e.n !== n);
        emergentes = emergentes.filter(e => e.n !== n);
    }

    // Deja de verse como aviso, pero sigue en el panel (salvo las
    // «transitorias», que no se guardan)
    function ocultar(e) {
        emergentes = emergentes.filter(x => x !== e);
        if (e.n.transient)
            e.n.expire();
    }

    function descartar(e) {
        e.n.dismiss();
    }

    function borrarTodas() {
        for (const e of lista.slice())
            e.n.dismiss();
    }

    // Clic en la notificación: su acción por defecto, si tiene
    function abrir(e) {
        const a = e.n.actions.find(x => x.identifier === "default");
        if (a) {
            a.invoke();
            Paneles.cerrar();
        } else
            ocultar(e);
    }

    // Botones de acción (sin la de por defecto, que es el clic)
    function acciones(n) {
        if (!n)
            return [];
        return n.actions.filter(a => a.identifier !== "default" && a.text !== "");
    }

    // Imagen de la notificación (avatar, portada...), o si no, el icono de la app
    function imagen(n) {
        if (!n)
            return "";
        const ruta = s => s.startsWith("/") ? "file://" + s : s;
        if (n.image)
            return ruta(n.image);
        if (n.appIcon)
            return n.appIcon.includes("/") ? ruta(n.appIcon) : Quickshell.iconPath(n.appIcon, true);
        const app = n.desktopEntry ? DesktopEntries.heuristicLookup(n.desktopEntry) : null;
        return app ? Quickshell.iconPath(app.icon, true) : "";
    }

    function hace(hora) {
        const s = Math.max(0, (ahora - hora) / 1000);
        if (s < 60)
            return "ahora";
        if (s < 3600)
            return `hace ${Math.floor(s / 60)} min`;
        if (hora.toDateString() === ahora.toDateString())
            return Qt.formatTime(hora, "HH:mm");
        return Qt.formatDateTime(hora, "d MMM · HH:mm");
    }

    // «No molestar» se recuerda entre sesiones
    FileView {
        id: estado
        path: Quickshell.env("HOME") + "/.local/state/yoru/no-molestar"
        printErrors: false
        onLoaded: raiz.noMolestar = text().trim() === "1"
    }
    onNoMolestarChanged: {
        Qt.callLater(exportar);
        if (noMolestar)
            emergentes = emergentes.filter(e => e.n.urgency === NotificationUrgency.Critical);
        estado.setText(noMolestar ? "1\n" : "0\n");
    }

    // ------------------------------------------- Para el estilo Dock
    // El dock (config/quickshell/yoru-dock, un port de LeyzS QsDock) no es
    // servidor de notificaciones: lee esta lista y manda sus órdenes por
    // «notifcenter». Mismo formato que su servidor original
    readonly property string rutaLista: Quickshell.env("HOME") + "/.cache/quickshell/notif-list.json"
    function exportar() {
        if (!Ajustes.estiloDock)
            return;
        const items = lista.map(e => {
            const n = e.n;
            const img = imagen(n);
            return {
                id: n.id,
                app: app(n) || "Notificación",
                summary: n.summary || "",
                body: n.body || "",
                // Solo archivos: los iconos (image://icon/...) van en «icon»
                image: n.image ? img : "",
                icon: n.image ? "" : img,
                time: e.hora.getTime(),
                action: n.actions.some(a => a.identifier === "default")
            };
        });
        archivoLista.setText(JSON.stringify({dnd: noMolestar, items: items}));
    }
    onListaChanged: Qt.callLater(exportar)
    Connections {
        target: Ajustes
        function onEstiloDockChanged() {
            Qt.callLater(raiz.exportar);
        }
    }
    FileView {
        id: archivoLista
        path: raiz.rutaLista
        atomicWrites: true
        printErrors: false
    }
    function porId(id) {
        return lista.find(e => String(e.n.id) === String(id)) ?? null;
    }
    IpcHandler {
        target: "notifcenter"
        function dismiss(id: string): void {
            const e = raiz.porId(id);
            if (e)
                raiz.descartar(e);
        }
        function dismissApp(nombre: string): void {
            for (const e of raiz.lista.slice())
                if ((raiz.app(e.n) || "Notificación") === nombre)
                    raiz.descartar(e);
        }
        function clearAll(): void {
            raiz.borrarTodas();
        }
        function invoke(id: string): void {
            const e = raiz.porId(id);
            if (e)
                raiz.abrir(e);
        }
        function setDnd(valor: string): void {
            raiz.noMolestar = valor === "true";
        }
        function toggleDnd(): void {
            raiz.noMolestar = !raiz.noMolestar;
        }
    }

    // Desde fuera:  qs -c yoru ipc call notificaciones noMolestar
    IpcHandler {
        target: "notificaciones"
        function noMolestar(): void {
            raiz.noMolestar = !raiz.noMolestar;
        }
        function borrar(): void {
            raiz.borrarTodas();
        }
    }
}
