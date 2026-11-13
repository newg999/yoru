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
                : enSeccion === "calendario" || origen !== "derecha" ? i.centro : i.estado)
            : {lanzador: i.botones, bateria: i.estado, actualizaciones: i.novedades, discos: i.discos,
               notificaciones: i.notificaciones, portapapeles: i.notificaciones, apagado: i.notificaciones,
               mega: i.estado, bandeja: i.estado}[nombre];
        // (una isla que acaba de aparecer para él, como la campana sin avisos,
        // aún no se ve ni tiene ancho: vale si ya no está vacía)
        return it && ((it.visible && it.width > 0) || it.vacia === false) ? it : null;
    }

    // Abre una página del panel «pildora» (paneles/Paginas.qml: control,
    // calendario, multimedia, clima...) bajo el botón pulsado, aunque ya
    // estuviera abierto con otra (se mueve). Si ya está en esa página, se cierra
    function abrirPagina(enPantalla, pagina, lado, bajoIsla) {
        // (la isla de la que cuelga ahora, antes de cambiar «origen»)
        const antes = abierto !== "" ? islaDe(pantalla, abierto, seccion) : null;
        if (cambio.running) {
            // Ya se está cambiando: vale la última pulsada
            cambio.pendiente = [enPantalla, pagina, lado, bajoIsla];
            return;
        }
        const ya = abierto === "pildora" && pantalla === enPantalla && seccion === pagina;
        // De una página a otra dentro del mismo panel (del centro de control
        // al wifi): se recuerda de dónde se vino, para «atrás»
        anterior = abierto === "pildora" && pantalla === enPantalla && !ya
            ? {pagina: seccion, lado: origen, ancla: ancla} : null;
        origen = lado ?? "centro";
        ancla = bajoIsla ?? null;
        // Islas con animaciones: si la página nueva cuelga de otra isla, el
        // panel no se desliza de una a otra: se cierra (vuelve a su isla) y
        // se abre desde la nueva
        const despues = islaDe(enPantalla, "pildora", pagina);
        if (!ya && antes && despues && antes !== despues && Tema.normal > 0) {
            cambio.pendiente = [enPantalla, pagina, lado, bajoIsla];
            cerrar();
            cambio.restart();
            return;
        }
        alternar("pildora", enPantalla, pagina);
    }
    // Lo que tarda en cerrarse (Panel.qml) antes de abrirse en la otra isla
    Timer {
        id: cambio
        property var pendiente: null
        interval: 190
        onTriggered: {
            const p = pendiente;
            pendiente = null;
            paneles.origen = p[2] ?? "centro";
            paneles.ancla = p[3] ?? null;
            paneles.alternar("pildora", p[0], p[1]);
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
