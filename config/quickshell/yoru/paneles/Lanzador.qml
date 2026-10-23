// ============================================================================
//  Lanzador de apps — sale por la izquierda, bajo el botón 󰀻 de la barra.
//  Con Mod+Space (sección "medio") sale en mitad de la pantalla, más ancho
//  y con las apps en dos columnas.
//
//    Escribe para buscar (nombre, descripción o palabras clave)
//    ↑ ↓ ← → para moverte · Enter para abrir · Esc para cerrar
//
//  Las apps que más abres salen primero (se cuentan en usos.json, en
//  ~/.local/state/quickshell/.../).
//
//  Al buscar salen también los ajustes de Yoru («ajustes», «settings»,
//  «wifi», «pantallas», «letra»...): abren su panel o su pestaña.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.comun

Panel {
    id: panel
    nombre: "lanzador"
    lado: Paneles.seccion === "medio" ? "medio" : "izquierda"
    ancho: medio ? 820 : 480

    readonly property bool medio: Paneles.seccion === "medio"
    readonly property int columnas: medio ? 2 : 1

    property var usos: ({})      // id de la app → veces abierta

    onAbiertoChanged: {
        if (abierto) {
            busqueda.text = "";
            lista.forceLayout();
            lista.currentIndex = 0;
            busqueda.forceActiveFocus();
        }
    }

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

    readonly property var resultados: {
        const q = busqueda.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
            .concat(q === "" ? [] : panel.ajustes);
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
        return apps
            .map(a => ({app: a, puntos: puntuar(a), usos: panel.usos[a.id] ?? 0}))
            .filter(r => r.puntos > 0)
            .sort((x, y) => (y.puntos - x.puntos) || ((y.app.ajuste ?? false) - (x.app.ajuste ?? false))
                || (y.usos - x.usos) || x.app.name.localeCompare(y.app.name))
            .map(r => r.app);
    }

    function abrir(app) {
        if (!app)
            return;
        // Un ajuste de Yoru: se abre su panel (en vez del lanzador), o se
        // empieza a grabar
        if (app.ajuste && app.panel === "grabar") {
            Grabacion.alternar();
            return;
        }
        if (app.ajuste) {
            Paneles.alternar(app.panel, panel.modelData, app.seccion);
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
                panel.usos = JSON.parse(text());
            } catch (e) {}
        }
    }

    Column {
        width: parent.width
        spacing: 12

        // ----------------------------------------------------- Búsqueda
        Rectangle {
            width: parent.width
            height: 46
            radius: 12
            color: Tema.caja
            border.width: 1
            border.color: busqueda.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

            Texto {
                id: lupa
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: "󰍉"
                font.pixelSize: 18
                color: Tema.gris
            }
            TextInput {
                id: busqueda
                anchors { left: lupa.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                color: Tema.texto
                selectionColor: Tema.claro(0.3)
                font.family: Tema.fuente
                font.pixelSize: 14
                focus: true
                clip: true
                onTextChanged: lista.currentIndex = 0

                Keys.onDownPressed: lista.moveCurrentIndexDown()
                Keys.onUpPressed: lista.moveCurrentIndexUp()
                // Con dos columnas, ← → cambian de columna; con una, mueven el cursor del texto
                Keys.onLeftPressed: event => {
                    if (panel.columnas > 1) lista.moveCurrentIndexLeft();
                    else event.accepted = false;
                }
                Keys.onRightPressed: event => {
                    if (panel.columnas > 1) lista.moveCurrentIndexRight();
                    else event.accepted = false;
                }
                Keys.onTabPressed: lista.incrementCurrentIndex()
                Keys.onReturnPressed: panel.abrir(panel.resultados[lista.currentIndex])
                Keys.onEnterPressed: panel.abrir(panel.resultados[lista.currentIndex])
                Keys.onEscapePressed: Paneles.cerrar()

                Texto {
                    visible: busqueda.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Buscar apps y ajustes…"
                    font.bold: false
                    font.pixelSize: 14
                    color: Tema.gris
                }
            }
        }

        Texto {
            leftPadding: 4
            text: "󰀻  " + (busqueda.text.trim() === "" ? "Aplicaciones" : "Apps y ajustes") + "  <font color='" + Tema.gris + "'>" + panel.resultados.length + "</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
            color: Tema.gris
        }

        // --------------------------------------------------------- Lista
        GridView {
            id: lista
            width: parent.width
            // 560, o menos si la pantalla es pequeña (117 = resto del panel)
            height: Math.min(560, panel.altoMax - 117)
            clip: true
            cellWidth: Math.floor(width / panel.columnas)
            cellHeight: 58
            // Al pasar de 1 a 2 columnas (o al revés) GridView no siempre
            // recoloca las filas que ya existían y se quedan unas encima de otras
            onCellWidthChanged: forceLayout()
            model: panel.resultados
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            keyNavigationWraps: true

            Texto {
                visible: panel.resultados.length === 0
                anchors.centerIn: parent
                text: "No hay nada que se llame así"
                font.bold: false
                color: Tema.gris
            }

            delegate: Rectangle {
                id: fila
                required property var modelData
                required property int index
                readonly property bool elegida: GridView.isCurrentItem
                width: lista.cellWidth - (panel.columnas > 1 ? 4 : 0)
                height: 56
                radius: 10
                color: elegida ? Tema.claro(0.90) : "transparent"

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: lista.currentIndex = fila.index
                    onClicked: panel.abrir(fila.modelData)
                }

                IconImage {
                    id: iconoApp
                    visible: !fila.modelData.ajuste
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    implicitSize: 34
                    // Si la app no trae icono (o no existe en el tema), uno genérico
                    source: fila.modelData.ajuste ? "" : Quickshell.iconPath(fila.modelData.icon, true) || Quickshell.iconPath("application-x-executable")
                    asynchronous: true
                }
                // Los ajustes de Yoru llevan su icono de la barra
                Rectangle {
                    visible: fila.modelData.ajuste ?? false
                    anchors.centerIn: iconoApp
                    width: 34; height: 34; radius: 10
                    color: fila.elegida ? Tema.sombra(0.15) : Tema.caja
                    Texto {
                        anchors.centerIn: parent
                        text: fila.modelData.glifo ?? ""
                        font.pixelSize: 18
                        color: fila.elegida ? Tema.oscuro : Tema.texto
                    }
                }
                Column {
                    anchors {
                        left: iconoApp.right; leftMargin: 14
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    Texto {
                        width: parent.width
                        text: fila.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 14
                        color: fila.elegida ? Tema.oscuro : Tema.texto
                    }
                    Texto {
                        width: parent.width
                        visible: text !== ""
                        text: fila.modelData.comment || fila.modelData.genericName || ""
                        elide: Text.ElideRight
                        font.bold: false
                        font.pixelSize: 11
                        color: fila.elegida ? Tema.sombra(0.6) : Tema.gris
                    }
                }
            }
        }
    }
}
