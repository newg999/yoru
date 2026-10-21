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

    // Ajustes es una ventana aparte (paneles/VentanaAjustes.qml), con una
    // sección elegida en su barra lateral. «ajustes» la abre en una de estas
    // secciones (la última que se vio, si no se dice cuál)
    readonly property var seccionesAjustes: ["tema", "fondo", "aspecto", "barra", "pantallas", "raton",
        "energia", "fecha", "apps", "acerca"]
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
