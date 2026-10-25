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
    property string modo: "blanco"      // tema elegido con «yoru tema» (ver Ajustes)

    // El acento o el fondo con transparencia (0 = invisible, 1 = sólido).
    // Úsalos en vez de Qt.rgba(1, 1, 1, x): así siguen al tema.
    function claro(opacidad) { return Qt.rgba(blanco.r, blanco.g, blanco.b, opacidad); }
    function sombra(opacidad) { return Qt.rgba(oscuro.r, oscuro.g, oscuro.b, opacidad); }
    function conAlfa(c, opacidad) { return Qt.rgba(c.r, c.g, c.b, opacidad); }

    readonly property color tenue: claro(0.35)         // apagado / silenciado

    // Para textos con formato (las ayudas de la barra): texto en gris, y
    // texto ajeno (nombres de redes, canciones...) sin que < y & rompan nada
    function suave(t) { return "<font color='" + gris + "'>" + t + "</font>"; }
    function html(t) { return String(t ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    // Islas de la barra: 1.0 = sólidas, 0.0 = invisibles (panel de Ajustes)
    readonly property color isla: sombra(Ajustes.opacidadIslas)
    readonly property color islaBorde: claro(0.12)

    // Paneles
    readonly property color panel: sombra(Ajustes.opacidadPaneles)
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
                tema.modo = c.modo ?? "blanco";
                console.info("Tema:", c.modo, "· acento", c.acento);
            } catch (e) {
                console.warn("colores.json no es válido:", e);
            }
        }
    }

    // --------------------------------------------------------------- Fuente
    // La elegida en Ajustes › Aspecto. Los iconos salen siempre de la Nerd
    // Font: si la letra no los tiene, Qt los busca en ella.
    readonly property string fuente: Ajustes.fuente
    readonly property int letra: Ajustes.letra   // texto normal de la barra
    readonly property int icono: 16        // iconos solos (wifi, bluetooth...)

    // --------------------------------------------------------------- Medidas
    // La barra va arriba o a la izquierda (Ajustes.barra). «grosor» es lo
    // que ocupa desde su borde: el alto de las islas arriba, su ancho a la
    // izquierda. «hueco» es donde empiezan los paneles y avisos, al lado.
    readonly property int altoBarra: 30      // islas de la barra de arriba
    readonly property int anchoBarra: 40     // islas de la barra de la izquierda
    readonly property int grosor: Ajustes.vertical ? anchoBarra : altoBarra
    // A los lados, la barra deja los «gaps» de niri (layout en config.kdl):
    // así empieza y acaba donde las ventanas (si cambias uno, cambia el otro).
    // En alto va más apretada: poco margen al borde y a las ventanas.
    readonly property int gaps: 12
    readonly property int margenLados: gaps
    readonly property int margenBarra: 6     // de la barra a su borde
    readonly property int aVentanas: 6       // de la barra a las ventanas
    // niri ya pone «gaps» tras la zona reservada: se reserva eso de menos
    readonly property int zonaBarra: margenBarra + grosor + aVentanas - gaps
    readonly property int hueco: margenBarra + grosor + aVentanas
    readonly property int separacion: 6      // entre islas
    // Con la minimalista (o la píldora recta), todo recto (Ajustes › Aspecto
    // no lo cambia)
    readonly property int radio: Ajustes.recto ? 0 : Ajustes.radio
    // Grosor del borde de islas, paneles y ayudas: 0 si se quitan en Ajustes.
    // (Los bordes de dentro, que marcan lo elegido, no dependen de esto)
    function borde(ancho) { return Ajustes.bordes ? ancho : 0; }
    readonly property int radioPanel: Ajustes.recto ? 0 : Ajustes.radio + 4
    // Esquinas de tarjetas, botones y cajas de los paneles: con la barra
    // minimalista (o la píldora recta), rectas, como ella (los círculos no:
    // no son esquinas). Uso:  radius: Tema.esquina(12)
    function esquina(n) { return Ajustes.recto ? 0 : n; }

    // ----------------------------------------------------------- Animaciones
    readonly property int rapida: Ajustes.animaciones ? 120 : 0
    readonly property int normal: Ajustes.animaciones ? 220 : 0
}
