// Botón de las apps (a la izquierda del todo) · Clic = lanzador
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 3

    Modulo {
        icono: "󰀻"
        relleno: 8
        onClic: Paneles.alternar("lanzador", isla.pantalla, "")
    }
}
