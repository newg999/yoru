// ============================================================================
//  Tema — colores, fuente y medidas de todo el escritorio en Quickshell
//  Son los mismos que tenía waybar/style.css y rofi/tema.rasi: blanco sobre
//  oscuro translúcido, y el color solo para los avisos.
//  Para cambiar la paleta, cambia solo este archivo.
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ------------------------------------------------------------ Colores
    readonly property color blanco: "#ffffff"
    readonly property color texto: "#e5e9f0"
    readonly property color tenue: Qt.rgba(1, 1, 1, 0.35)      // apagado / silenciado
    readonly property color gris: "#8a8f98"                     // textos secundarios
    readonly property color oscuro: "#1a1b1e"
    readonly property color rojo: "#bf616a"
    readonly property color amarillo: "#ebcb8b"

    // Islas de la barra: 1.0 = sólidas, 0.0 = invisibles
    readonly property color isla: Qt.rgba(26 / 255, 27 / 255, 30 / 255, 0.45)
    readonly property color islaBorde: Qt.rgba(1, 1, 1, 0.12)

    // Paneles (como los menús de rofi)
    readonly property color panel: Qt.rgba(26 / 255, 27 / 255, 30 / 255, 0.90)
    readonly property color panelBorde: Qt.rgba(1, 1, 1, 0.80) // = anillo de foco de niri
    readonly property color caja: Qt.rgba(1, 1, 1, 0.06)        // fondos de filas y botones
    readonly property color cajaHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color activo: Qt.rgba(1, 1, 1, 0.12)      // conectado / en uso

    // --------------------------------------------------------------- Fuente
    readonly property string fuente: "JetBrainsMono Nerd Font"
    readonly property int letra: 14        // texto normal de la barra
    readonly property int icono: 18        // iconos solos (wifi, bluetooth...)

    // --------------------------------------------------------------- Medidas
    readonly property int altoBarra: 36
    readonly property int margenBarra: 8     // arriba
    readonly property int margenLados: 12
    readonly property int separacion: 8      // entre islas
    readonly property int radio: 12
    readonly property int radioPanel: 14

    // ----------------------------------------------------------- Animaciones
    readonly property int rapida: 120
    readonly property int normal: 220
}
