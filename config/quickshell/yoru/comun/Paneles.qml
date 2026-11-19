// ============================================================================
//  Paneles — qué panel está abierto y en qué pantalla
//  Solo puede haber uno abierto a la vez: abrir otro cierra el anterior.
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: paneles

    property string abierto: ""      // "" = ninguno · "conexion"
    property var pantalla: null      // ShellScreen donde se abrió
    property string seccion: ""      // dentro del panel: "wifi", "bluetooth", "audio"...
    // Islas y minimalista: de qué lado sale el panel de páginas (el del
    // botón que se pulsó: «derecha» el centro de control, «centro» la hora,
    // la canción o el tiempo)
    property string origen: "centro"
    // Islas en píldoras: el panel justo debajo de la isla pulsada y de su
    // mismo ancho ({x, ancho} en la pantalla; null = según «origen»)
    property var ancla: null

    // Islas en píldoras: el panel sale de la isla que lo abre, fundido con
    // ella (Panel.qml). BarraIslas apunta aquí sus islas, por pantalla
    property var islas: ({})
    // La isla que se convierte en panel ensancha su fondo de x0 a x1 (en su
    // ventana): las demás islas que caen debajo se desvanecen al ritmo f
    // (Isla.tapada). Lo lleva Panel.qml, por panel: clave → {isla, ventana, x0, x1, f}
    property var tapas: ({})
    function tapar(clave, isla, x0, x1, f) {
        const t = Object.assign({}, tapas);
        if (isla && f > 0)
            t[clave] = {isla: isla, ventana: isla.ventana, x0: x0, x1: x1, f: f};
        else if (t[clave])
            delete t[clave];
        else
            return;
        tapas = t;
    }
    // Con la isla (barra/BarraIsla.qml), todo cuelga de ella: pantalla → isla
    property var islaUnica: ({})
    function islaDe(enPantalla, nombre, enSeccion) {
        if (Ajustes.isla) {
            const u = islaUnica[enPantalla?.name] ?? null;
            return u && u.visible ? u : null;
        }
        if (!Ajustes.pildoras)
            return null;
        const i = islas[enPantalla?.name];
        if (!i)
            return null;
        const it = nombre === "pildora"
            ? (enSeccion === "musica" ? i.musica
                // el tiempo, de su isla (a la izquierda); si no se ve, del centro
                : enSeccion === "clima" ? (i.clima?.visible && i.clima.width > 0 ? i.clima : i.centro)
                // las actualizaciones, de la suya (si no se ve, del estado)
                : enSeccion === "actualizaciones" ? (i.novedades?.visible && i.novedades.width > 0 ? i.novedades : i.estado)
                : enSeccion === "calendario" || origen !== "derecha" ? i.centro
                // las de la derecha, cada una de su isla (si no se ve, la del
                // centro de control)
                : ({red: i.red, bt: i.bt, sonido: i.sonido}[enSeccion]?.visible ? {red: i.red, bt: i.bt, sonido: i.sonido}[enSeccion] : null)
                    ?? i.control ?? i.estado)
            : {lanzador: i.botones, bateria: i.bateria ?? i.estado, discos: i.discos,
               notificaciones: i.notificaciones, portapapeles: i.notificaciones, apagado: i.notificaciones,
               // (la bandeja va en su propia isla, a la izquierda)
               mega: i.bandeja ?? i.estado, bandeja: i.bandeja ?? i.estado}[nombre];
        // (una isla que acaba de aparecer para él, como la campana sin avisos,
        // aún no se ve ni tiene ancho: vale si ya no está vacía)
        return it && ((it.visible && it.width > 0) || it.vacia === false) ? it : null;
    }

    // Abre una página del panel «pildora» (paneles/Paginas.qml: control,
    // calendario, multimedia, clima...) bajo el botón pulsado, aunque ya
    // estuviera abierto con otra (se mueve). Si ya está en esa página, se cierra
    // desdeDentro: la abre el propio panel (del centro de control al wifi,
    // de Sistema a las actualizaciones); solo entonces «atrás» (Esc, ‹)
    // vuelve a la de antes
    function abrirPagina(enPantalla, pagina, lado, bajoIsla, desdeDentro) {
        // (la isla de la que cuelga ahora, antes de cambiar «origen»)
        const antes = abierto !== "" ? islaDe(pantalla, abierto, seccion) : null;
        if (cambio.running) {
            // Ya se está cambiando: vale la última pulsada
            cambio.pendiente = [enPantalla, pagina, lado, bajoIsla];
            return;
        }
        const ya = abierto === "pildora" && pantalla === enPantalla && seccion === pagina;
        // De una página a otra desde dentro del panel (del centro de control
        // al wifi): se recuerda de dónde se vino, para «atrás». Desde la
        // barra (del wifi a la isla de actualizaciones), no: Esc cierra
        // (antes volvía a la página de la otra isla)
        anterior = desdeDentro && abierto === "pildora" && pantalla === enPantalla && !ya
            ? {pagina: seccion, lado: origen, ancla: ancla} : null;
        // Barra minimalista: si la nueva página va en otro sitio (de la hora,
        // en el centro, al wifi, a la derecha), el panel se recoge y baja en
        // el suyo. Antes se deslizaba hasta allí con la página de antes
        // dentro y se veía un momento el calendario donde iba el wifi
        // (la que se cierra se queda en su sitio: «origen» cambia al abrir)
        if (Ajustes.minimalista && abierto === "pildora" && pantalla === enPantalla && !ya
                && origen !== (lado ?? "centro") && Tema.normal > 0) {
            cambio.pendiente = [enPantalla, pagina, lado, bajoIsla];
            const volver = anterior;
            deprisa();
            cerrar();
            anterior = volver;
            cambio.restart();
            return;
        }
        origen = lado ?? "centro";
        ancla = bajoIsla ?? null;
        // Si la página nueva cuelga de otra isla, el panel se desliza hasta
        // ella sin cerrarse (Panel.qml: islaX y anchoSuave). Con «Paneles que
        // salen de su isla», no: se cierra deprisa (vuelve a su isla) y se
        // abre desde la nueva, también deprisa (rapido)
        const cerrarYAbrir = Ajustes.panelesDesdeIsla && Ajustes.pildoras;
        const despues = islaDe(enPantalla, "pildora", pagina);
        if (cerrarYAbrir && !ya && antes && despues && antes !== despues && Tema.normal > 0) {
            cambio.pendiente = [enPantalla, pagina, lado, bajoIsla];
            deprisa();
            cerrar();
            cambio.restart();
            return;
        }
        alternar("pildora", enPantalla, pagina);
    }
    // Al pasar de un panel a otro: se cierra y se abre deprisa (Panel.qml
    // mira «rapido» para la duración). Vuelve a lo normal cuando ya ha
    // terminado de abrirse el nuevo
    property bool rapido: false
    function deprisa() {
        rapido = true;
        normalidad.restart();
    }
    Timer { id: normalidad; interval: 550; onTriggered: paneles.rapido = false }

    // Lo que tarda en cerrarse (Panel.qml, deprisa) antes de abrirse en la otra isla
    Timer {
        id: cambio
        property var pendiente: null
        // (la persiana de la minimalista tarda 170 ms en subir)
        interval: Ajustes.minimalista ? 190 : 160
        onTriggered: {
            const p = pendiente;
            pendiente = null;
            paneles.origen = p[2] ?? "centro";
            paneles.ancla = p[3] ?? null;
            paneles.alternar("pildora", p[0], p[1]);
        }
    }

    // (lo mismo, de un panel a otro en la minimalista)
    Timer {
        id: cambioPanel
        property var pendiente: null
        interval: 190
        onTriggered: {
            const p = pendiente;
            pendiente = null;
            if (p && paneles.abierto === "")
                paneles.alternar(p[0], p[1], p[2]);
        }
    }

    // Ajustes es una ventana aparte (paneles/VentanaAjustes.qml), con una
    // sección elegida en su barra lateral. «ajustes» la abre en una de estas
    // secciones (la última que se vio, si no se dice cuál)
    readonly property var seccionesAjustes: ["tema", "fondo", "aspecto", "barra", "escritorio", "pantallas", "sonido", "raton", "teclado", "atajos",
        "notificaciones", "energia", "fecha", "apps", "acerca"]
    property bool ajustesAbiertos: false
    property string seccionAjustes: "tema"

    // ¿Está abierto este panel en esta pantalla? (y en esta sección, si se da)
    // Lo usa la barra para dejar iluminado el botón que lo abrió: al abrirse,
    // el panel tapa la barra y el ratón deja de estar «encima» del botón.
    function esta(nombre, enPantalla, enSeccion) {
        if (nombre === "ajustes")
            return ajustesAbiertos && (!enSeccion || seccionAjustes === enSeccion);
        return abierto === nombre && pantalla === enPantalla
            && (enSeccion === undefined || seccion === enSeccion);
    }

    // Abre el panel (o lo cierra si ya estaba abierto en esa misma sección)
    function alternar(nombre, enPantalla, enSeccion) {
        if (nombre === "ajustes") {
            alternarAjustes(enSeccion);
            return;
        }
        if (abierto === nombre && pantalla === enPantalla && seccion === (enSeccion ?? "")) {
            cerrar();
            return;
        }
        // Minimalista: de un panel abierto a otro (el calendario → las
        // notificaciones, los dos en el centro), primero se recoge uno y
        // luego baja el otro; a la vez se cruzaban en el mismo hueco
        if (Ajustes.minimalista && abierto !== "" && abierto !== nombre && Tema.normal > 0) {
            cambioPanel.pendiente = [nombre, enPantalla, enSeccion];
            cerrar();
            cambioPanel.restart();
            return;
        }
        // De un panel abierto a otro (el reloj → las notificaciones): uno se
        // cierra y el otro se abre a la vez, los dos deprisa
        if (abierto !== "" && abierto !== nombre && Ajustes.panelesDesdeIsla)
            deprisa();
        pantalla = enPantalla;
        seccion = enSeccion ?? "";
        abierto = nombre;
    }

    function cerrar() {
        abierto = "";
        anterior = null;
    }

    // «‹» y Esc: a la página de la que se vino (el wifi → el centro de
    // control) o, si no se vino de ninguna, cerrar
    property var anterior: null

    // Desde el menú de la isla (barra/BarraIsla.qml): lo ya escrito en su
    // buscador pasa al lanzador, y cerrar sesión, reiniciar o apagar abren
    // el menú de apagado con esa opción ya en marcha (su cuenta atrás de 3 s)
    property string textoLanzador: ""
    // Abrir o cerrar la isla en una pantalla, en una página (0 Sistema,
    // 1 Menú, 2 Segundo plano): qs -c yoru ipc call isla menu (Mod+X)
    signal menuIsla(string pantalla, int pagina)
    property string sesionElegida: ""
    function atras() {
        const a = anterior;
        if (!a || abierto !== "pildora") {
            cerrar();
            return;
        }
        abrirPagina(pantalla, a.pagina, a.lado, a.ancla);
        anterior = null;
    }

    // La ventana de Ajustes. Si ya la tienes delante (con el foco) en esa
    // sección, o sin decir sección como con Mod+Alt+T, se cierra; si no, se
    // abre en esa sección o, si estaba detrás de otras ventanas, se trae
    readonly property string tituloAjustes: "Ajustes de Yoru"
    function alternarAjustes(enSeccion) {
        const ventana = Object.values(Niri.ventanas).find(v => v.title === tituloAjustes);
        const delante = ajustesAbiertos && Niri.enfocada?.title === tituloAjustes;
        if (delante && (!enSeccion || enSeccion === seccionAjustes)) {
            ajustesAbiertos = false;
            return;
        }
        if (enSeccion && seccionesAjustes.includes(enSeccion))
            seccionAjustes = enSeccion;
        cerrar();
        if (ajustesAbiertos && ventana)
            Niri.accion("focus-window", "--id", String(ventana.id));
        ajustesAbiertos = true;
    }

    // Meteosat (paneles/Meteosat.qml): una ventana aparte, como Ajustes. Si ya
    // la tienes delante, se cierra; si está detrás de otras, se trae
    property bool meteosatAbierto: false
    readonly property string tituloMeteosat: "Meteosat"
    function alternarMeteosat() {
        const ventana = Object.values(Niri.ventanas).find(v => v.title === tituloMeteosat && v.app_id !== "kitty");
        if (meteosatAbierto && Niri.enfocada?.title === tituloMeteosat) {
            meteosatAbierto = false;
            return;
        }
        cerrar();
        if (meteosatAbierto && ventana)
            Niri.accion("focus-window", "--id", String(ventana.id));
        meteosatAbierto = true;
    }

    // Al abrir el overview (Mod+Tab) se cierra cualquier panel
    Connections {
        target: Niri
        function onOverviewChanged() {
            if (Niri.overview)
                paneles.cerrar();
        }

        // Al abrirse una ventana se cierra el panel: si no, la tapa y se queda
        // con el teclado (p. ej. la contraseña de administrador al instalar
        // desde la Tienda salía debajo y no se podía escribir)
        function onVentanaNueva() {
            paneles.cerrar();
        }
    }
}
