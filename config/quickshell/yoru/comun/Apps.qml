pragma Singleton

// ============================================================================
//  Apps — lo que busca el lanzador: las apps instaladas y, al escribir algo,
//  los ajustes de Yoru («ajustes», «wifi», «pantallas», «letra»...)
//
//  Lo usan el panel del lanzador (paneles/Lanzador.qml) y la página
//  «lanzador» de la píldora (paneles/PaginaLanzador.qml):
//      Apps.buscar("fire")       → [apps y ajustes, los mejores primero]
//      Apps.abrir(app, pantalla) → la abre (o abre el panel del ajuste)
//
//  Las apps que más abres salen primero (se cuentan en usos.json, en
//  ~/.local/state/quickshell/.../).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: apps

    property var usos: ({})      // id de la app → veces abierta

    // Ajustes de Yoru que se pueden buscar: [glifo, nombre, descripción,
    // palabras clave, panel, sección]. Solo salen al escribir algo.
    readonly property var ajustes: [
        ["󰒓", "Ajustes de Yoru", "Tema, fondo, barra, pantallas, energía, fecha y hora...", "ajustes settings configuración configuracion preferencias opciones", "ajustes", ""],
        ["󰏘", "Tema y colores", "Ajustes › Tema", "tema theme colores colors paleta oscuro claro dark light", "ajustes", "tema"],
        ["󰸉", "Fondo de pantalla", "Ajustes › Fondo", "fondo wallpaper background imagen", "ajustes", "fondo"],
        ["󰕮", "Barra y dock", "Ajustes › Barra y dock", "barra bar dock panel islas", "ajustes", "barra"],
        ["󰙵", "Aspecto", "Ajustes › Aspecto: esquinas, transparencias, letra, animaciones", "aspecto appearance letra fuente font tipografía tipografia esquinas transparencia opacidad desenfoque blur bordes animaciones", "ajustes", "aspecto"],
        ["󰍹", "Pantallas", "Ajustes › Pantallas: colocarlas, resolución y escala", "pantallas pantalla monitores monitor displays display resolución resolucion escala hz frecuencia", "ajustes", "pantallas"],
        ["󰖔", "Luz nocturna", "Ajustes › Aspecto: pantalla más cálida por la noche", "luz nocturna night light filtro azul blue cálida calida noche", "ajustes", "aspecto"],
        ["󰍽", "Ratón y touchpad", "Ajustes › Ratón: velocidad, rueda y cursor", "ratón raton mouse touchpad cursor puntero trackpad", "ajustes", "raton"],
        ["󰕾", "Ajustes de sonido", "Ajustes › Sonido: salida, micrófono y volumen de cada app", "sonido audio volumen altavoces auriculares micrófono microfono mic salida entrada apps", "ajustes", "sonido"],
        ["󰌌", "Teclado", "Ajustes › Teclado: distribución, repetición y Bloq Mayús", "teclado keyboard distribución distribucion idioma layout inglés ingles repetición repeticion mayúsculas mayusculas bloq num", "ajustes", "teclado"],
        ["󰘳", "Atajos de teclado", "Ajustes › Atajos: todos, con buscador", "atajos shortcuts teclas combinaciones keybinds binds chuleta", "ajustes", "atajos"],
        ["󰂚", "Ajustes de notificaciones", "Ajustes › Notificaciones: no molestar, avisos y apps", "notificaciones notifications avisos no molestar silenciar sonido dnd", "ajustes", "notificaciones"],
        ["󰂄", "Energía y bloqueo", "Ajustes › Energía: bloquear, apagar la pantalla y suspender", "energía energia bloqueo bloquear suspender suspensión suspension apagar pantalla inactividad power perfil ahorro rendimiento", "ajustes", "energia"],
        ["󰥔", "Fecha y hora", "Ajustes › Fecha y hora: zona horaria y reloj", "fecha hora zona horaria timezone reloj clock 24 12 segundos ntp", "ajustes", "fecha"],
        ["󰋼", "Acerca de", "Ajustes › Acerca de: tu equipo y la versión de Yoru", "acerca about sistema versión version equipo hardware actualizar update yoru", "ajustes", "acerca"],
        ["󰖩", "Wi-Fi y red", "Redes, VPN y cable", "wifi wi-fi red network internet ethernet cable vpn wireguard", "pildora", "wifi"],
        ["󰂯", "Bluetooth", "Conectar auriculares, ratones...", "bluetooth auriculares cascos", "pildora", "bluetooth"],
        ["󰕾", "Sonido", "Salida de audio y volumen", "sonido audio volumen sound altavoces salida", "pildora", "audio"],
        ["󰍬", "Micrófono", "Entrada de audio", "micrófono microfono micro mic entrada", "pildora", "micro"],
        ["󰁹", "Batería y energía", "Salud, consumo y perfil de energía", "batería bateria battery energía energia power perfil ahorro rendimiento", "bateria", ""],
        ["󰚰", "Actualizaciones", "Actualizar Fedora y las apps", "actualizar actualizaciones updates update upgrade dnf flatpak", "actualizaciones", ""],
        ["󰕓", "Memorias USB y discos", "Abrir o expulsar los conectados", "usb pendrive memoria disco externo expulsar tarjeta sd", "discos", ""],
        ["󰨇", "Monitor del sistema", "Procesos, CPU, memoria, red y disco", "monitor procesos tareas task manager administrador cpu memoria ram rendimiento", "monitor", "procesos"],
        ["󰅶", "No suspender", "Centro de control: que no se bloquee ni se apague la pantalla", "no suspender cafeína cafeina caffeine despierto inhibir pantalla encendida presentación", "pildora", "control"],
        ["󰂚", "Notificaciones", "Historial y no molestar", "notificaciones notifications no molestar", "notificaciones", ""],
        ["󰅌", "Portapapeles", "Historial de lo copiado", "portapapeles clipboard copiado pegar", "portapapeles", ""],
        ["󰑋", "Grabar la pantalla", "Clic = pantalla entera, arrastrar = una zona · Mod+Alt+R", "grabar grabación grabacion vídeo video record recorder pantalla screencast", "grabar", ""],
        ["󰐥", "Apagar o reiniciar", "Bloquear, suspender, cerrar sesión...", "apagar reiniciar suspender bloquear cerrar sesión sesion power shutdown reboot logout", "apagado", ""]
    ].filter(a => a[4] !== "bateria" || (UPower.displayDevice?.isLaptopBattery ?? false))
     .map(a => ({ajuste: true, glifo: a[0], name: a[1], comment: a[2], keywords: a[3].split(" "), panel: a[4], seccion: a[5], id: "yoru:" + a[1]}))

    function buscar(texto) {
        const q = (texto ?? "").trim().toLowerCase();
        const todas = DesktopEntries.applications.values.filter(a => !a.noDisplay)
            .concat(q === "" ? [] : ajustes);
        const puntuar = a => {
            if (q === "")
                return 1;
            const nombre = (a.name ?? "").toLowerCase();
            if (nombre.startsWith(q)) return 4;
            if (nombre.split(/\s+/).some(p => p.startsWith(q))) return 3;
            if (nombre.includes(q)) return 2;
            const resto = [a.genericName, a.comment, ...(a.keywords ?? [])].join(" ").toLowerCase();
            return resto.includes(q) ? 1 : 0;
        };
        return todas
            .map(a => ({app: a, puntos: puntuar(a), usos: usos[a.id] ?? 0}))
            .filter(r => r.puntos > 0)
            .sort((x, y) => (y.puntos - x.puntos) || ((y.app.ajuste ?? false) - (x.app.ajuste ?? false))
                || (y.usos - x.usos) || x.app.name.localeCompare(y.app.name))
            .map(r => r.app);
    }

    function abrir(app, pantalla) {
        if (!app)
            return;
        // Un ajuste de Yoru: se abre su panel (en vez del lanzador), o se
        // empieza a grabar
        if (app.ajuste && app.panel === "grabar") {
            Paneles.cerrar();
            Grabacion.alternar();
            return;
        }
        if (app.ajuste) {
            Paneles.alternar(app.panel, pantalla, app.seccion);
            return;
        }
        const u = Object.assign({}, usos);
        u[app.id] = (u[app.id] ?? 0) + 1;
        usos = u;
        archivoUsos.setText(JSON.stringify(u));
        // Como app.execute(), pero lanzada por niri (ver Niri.lanzar)
        const orden = app.runInTerminal ? ["kitty", "--", ...app.command] : app.command;
        Niri.lanzar(app.workingDirectory
            ? ["sh", "-c", 'cd "$1" && shift && exec "$@"', "_", app.workingDirectory, ...orden]
            : orden);
        Paneles.cerrar();
    }

    FileView {
        id: archivoUsos
        path: Quickshell.stateDir + "/usos.json"
        onLoaded: {
            try {
                apps.usos = JSON.parse(text());
            } catch (e) {}
        }
    }
}
