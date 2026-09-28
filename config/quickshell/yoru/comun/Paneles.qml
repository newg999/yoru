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

    // ¿Está abierto este panel en esta pantalla? (y en esta sección, si se da)
    // Lo usa la barra para dejar iluminado el botón que lo abrió: al abrirse,
    // el panel tapa la barra y el ratón deja de estar «encima» del botón.
    function esta(nombre, enPantalla, enSeccion) {
        return abierto === nombre && pantalla === enPantalla
            && (enSeccion === undefined || seccion === enSeccion);
    }

    // Abre el panel (o lo cierra si ya estaba abierto en esa misma sección)
    function alternar(nombre, enPantalla, enSeccion) {
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
    }
}
