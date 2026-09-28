// ============================================================================
//  Tema — colores, fuente y medidas de todo el escritorio en Quickshell
//  Blanco sobre oscuro translúcido, y el color solo para los avisos.
//
//  Los colores base salen de «yoru tema» (tema/blanco.json, o sacados del
//  fondo de pantalla): se leen de ~/.local/state/yoru/tema/colores.json y
//  cambian en vivo. Si ese archivo no existe, se quedan los de aquí abajo.
//  Para cambiar la paleta, cambia tema/blanco.json, no este archivo.
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: tema

    // ------------------------------------------------------------ Colores
    property color blanco: "#ffffff"    // el acento: blanco en el tema blanco
    property color texto: "#e5e9f0"
    property color gris: "#8a8f98"      // textos secundarios
    property color oscuro: "#1a1b1e"
    property color rojo: "#bf616a"
    property color amarillo: "#ebcb8b"

    // El acento o el fondo con transparencia (0 = invisible, 1 = sólido).
    // Úsalos en vez de Qt.rgba(1, 1, 1, x): así siguen al tema.
    function claro(opacidad) { return Qt.rgba(blanco.r, blanco.g, blanco.b, opacidad); }
    function sombra(opacidad) { return Qt.rgba(oscuro.r, oscuro.g, oscuro.b, opacidad); }
    function conAlfa(c, opacidad) { return Qt.rgba(c.r, c.g, c.b, opacidad); }

    readonly property color tenue: claro(0.35)         // apagado / silenciado

    // Islas de la barra: 1.0 = sólidas, 0.0 = invisibles
    readonly property color isla: sombra(0.45)
    readonly property color islaBorde: claro(0.12)

    // Paneles (como los menús de rofi)
    readonly property color panel: sombra(0.90)
    readonly property color panelBorde: claro(0.80)    // = anillo de foco de niri
    readonly property color caja: claro(0.06)          // fondos de filas y botones
    readonly property color cajaHover: claro(0.12)
    readonly property color activo: claro(0.12)        // conectado / en uso

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/yoru/tema/colores.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text());
                tema.blanco = c.acento;
                tema.texto = c.texto;
                tema.gris = c.gris;
                tema.oscuro = c.fondo;
                tema.rojo = c.rojo;
                tema.amarillo = c.amarillo;
                console.info("Tema:", c.modo, "· acento", c.acento);
            } catch (e) {
                console.warn("colores.json no es válido:", e);
            }
        }
    }

    // --------------------------------------------------------------- Fuente
    readonly property string fuente: "JetBrainsMono Nerd Font"
    readonly property int letra: 13        // texto normal de la barra
    readonly property int icono: 16        // iconos solos (wifi, bluetooth...)

    // --------------------------------------------------------------- Medidas
    readonly property int altoBarra: 30
    readonly property int margenBarra: 2     // arriba
    readonly property int margenLados: 2
    readonly property int separacion: 6      // entre islas
    readonly property int radio: 10
    readonly property int radioPanel: 14

    // ----------------------------------------------------------- Animaciones
    readonly property int rapida: 120
    readonly property int normal: 220
}
