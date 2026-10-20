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

    // Ajustes es una pestaña del panel central: «ajustes» abre «centro» en
    // una de estas secciones (la última que se vio, si no se dice cuál)
    readonly property var seccionesAjustes: ["tema", "fondo", "barra", "aspecto", "pantallas", "raton", "apps"]
    property string ultimoAjuste: "tema"
    onSeccionChanged: if (seccionesAjustes.includes(seccion)) ultimoAjuste = seccion
    function enAjustes() {
        return abierto === "centro" && seccionesAjustes.includes(seccion);
    }

    // ¿Está abierto este panel en esta pantalla? (y en esta sección, si se da)
    // Lo usa la barra para dejar iluminado el botón que lo abrió: al abrirse,
    // el panel tapa la barra y el ratón deja de estar «encima» del botón.
    function esta(nombre, enPantalla, enSeccion) {
        if (nombre === "ajustes")
            return enAjustes() && pantalla === enPantalla && (!enSeccion || seccion === enSeccion);
        return abierto === nombre && pantalla === enPantalla
            && (enSeccion === undefined || seccion === enSeccion);
    }

    // Abre el panel (o lo cierra si ya estaba abierto en esa misma sección)
    function alternar(nombre, enPantalla, enSeccion) {
        if (nombre === "ajustes") {
            if (!enSeccion && enAjustes() && pantalla === enPantalla) {
                cerrar();
                return;
            }
            nombre = "centro";
            enSeccion = enSeccion || ultimoAjuste;
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
