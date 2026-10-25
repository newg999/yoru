// ============================================================================
//  Páginas del panel de la píldora y de la barra minimalista: una a la vista,
//  con fundido al cambiar y el alto ajustándose suave
//
//    control · calendario · multimedia · clima · sistema · temas · fondos
//    y, solo en la píldora, lanzador · portapapeles · apagado (Mod+Espacio,
//    Mod+Alt+V y Mod+Shift+Retroceso: ver Paneles.alternar)
//
//  La página es la sección del panel «pildora» (Paneles.seccion):
//      Paneles.alternar("pildora", pantalla, "clima")
//  Lo usan paneles/Pildora.qml (dentro de la propia píldora) y
//  paneles/PanelPaginas.qml (bajo las islas o la barra minimalista).
// ============================================================================
import QtQuick
import qs.comun

Item {
    id: raiz

    required property var pantalla
    property bool abierta: false

    readonly property var todas: ["control", "calendario", "multimedia", "clima", "sistema", "temas", "fondos",
        "lanzador", "portapapeles", "apagado"]
    // (wifi, bluetooth, audio y micro son el control con esa lista abierta)
    readonly property string pagina: todas.includes(Paneles.seccion) ? Paneles.seccion : "control"
    // Multimedia y Clima son las pestañas del panel central: piden más sitio
    readonly property int anchoPedido: ["multimedia", "clima"].includes(pagina) ? 620
        : pagina === "portapapeles" ? 560 : pagina === "lanzador" ? 520 : 460
    // Ir a una página (la que ya se ve: volver a control)
    function ir(p) {
        Paneles.alternar("pildora", pantalla, abierta && pagina === p ? "control" : p);
    }

    implicitHeight: pagina === "calendario" ? calendario.implicitHeight
        : pagina === "multimedia" ? multimedia.implicitHeight
        : pagina === "clima" ? clima.implicitHeight
        : pagina === "sistema" ? sistema.implicitHeight
        : pagina === "temas" ? temas.implicitHeight
        : pagina === "fondos" ? fondos.implicitHeight
        : pagina === "lanzador" ? lanzador.implicitHeight
        : pagina === "portapapeles" ? portapapeles.implicitHeight
        : pagina === "apagado" ? apagado.implicitHeight
        : control.implicitHeight
    height: implicitHeight
    Behavior on height {
        enabled: raiz.abierta
        NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
    }

    PaginaControl {
        id: control
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.pagina === "control"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "control"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaCalendario {
        id: calendario
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "calendario"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "calendario"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    // Las mismas pestañas del panel central
    PestanaMultimedia {
        id: multimedia
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "multimedia"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "multimedia"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PestanaClima {
        id: clima
        width: parent.width
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "clima"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaSistema {
        id: sistema
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.pagina === "sistema"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "sistema"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaTemas {
        id: temas
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "temas"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "temas"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaFondos {
        id: fondos
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "fondos"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "fondos"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaLanzador {
        id: lanzador
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.pagina === "lanzador"
        visible: raiz.pagina === "lanzador"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaPortapapeles {
        id: portapapeles
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "portapapeles"
        visible: raiz.pagina === "portapapeles"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
    PaginaApagado {
        id: apagado
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "apagado"
        visible: raiz.pagina === "apagado"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    }
}
