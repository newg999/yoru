// ============================================================================
//  Notificaciones — Quickshell hace de servidor de notificaciones (en lugar
//  de mako): las guarda, decide cuáles salen como aviso y lleva el «no
//  molestar».
//
//    lista        todas las que siguen abiertas, la más nueva primero
//    emergentes   las que se ven ahora arriba a la derecha (Avisos.qml)
//    noMolestar   sin avisos emergentes (salvo las urgentes); se guardan igual
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

            if (!raiz.noMolestar || n.urgency === NotificationUrgency.Critical)
                raiz.emergentes = [e].concat(raiz.emergentes.filter(x => x !== e));
        }
    }

    // Al recargar la barra (guardar un .qml) el servidor conserva las
    // notificaciones, pero la lista empieza vacía: se rehace
    Component.onCompleted: {
        lista = servidor.trackedNotifications.values.slice().reverse().map(n => {
            n.closed.connect(() => raiz.quitar(n));
            return {n: n, hora: new Date()};
        });
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
        if (noMolestar)
            emergentes = emergentes.filter(e => e.n.urgency === NotificationUrgency.Critical);
        estado.setText(noMolestar ? "1\n" : "0\n");
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
