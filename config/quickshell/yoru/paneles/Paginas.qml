// ============================================================================
//  Páginas del panel de la píldora y de la barra minimalista: una a la vista,
//  con fundido al cambiar y el alto ajustándose suave
//
//    control · calendario · multimedia · clima · sistema · temas · fondos
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

    readonly property var todas: ["control", "calendario", "multimedia", "clima", "sistema", "temas", "fondos"]
    // (wifi, bluetooth, audio y micro son el control con esa lista abierta)
    readonly property string pagina: todas.includes(Paneles.seccion) ? Paneles.seccion : "control"
    // Multimedia y Clima son las pestañas del panel central: piden más sitio
    readonly property int anchoPedido: ["multimedia", "clima"].includes(pagina) ? 620 : 460
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
        visible: opacity > 0
        opacity: raiz.pagina === "control" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "control"; NumberAnimation { duration: Tema.normal } }
    }
    PaginaCalendario {
        id: calendario
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "calendario"
        visible: opacity > 0
        opacity: raiz.pagina === "calendario" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "calendario"; NumberAnimation { duration: Tema.normal } }
    }
    // Las mismas pestañas del panel central
    PestanaMultimedia {
        id: multimedia
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "multimedia"
        visible: opacity > 0
        opacity: raiz.pagina === "multimedia" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "multimedia"; NumberAnimation { duration: Tema.normal } }
    }
    PestanaClima {
        id: clima
        width: parent.width
        visible: opacity > 0
        opacity: raiz.pagina === "clima" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "clima"; NumberAnimation { duration: Tema.normal } }
    }
    PaginaSistema {
        id: sistema
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.pagina === "sistema"
        visible: opacity > 0
        opacity: raiz.pagina === "sistema" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "sistema"; NumberAnimation { duration: Tema.normal } }
    }
    PaginaTemas {
        id: temas
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "temas"
        visible: opacity > 0
        opacity: raiz.pagina === "temas" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "temas"; NumberAnimation { duration: Tema.normal } }
    }
    PaginaFondos {
        id: fondos
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "fondos"
        visible: opacity > 0
        opacity: raiz.pagina === "fondos" ? 1 : 0
        // Entra con fundido; al irse, desaparece al momento (si no, se veían
        // las dos páginas a la vez un instante)
        Behavior on opacity { enabled: raiz.pagina === "fondos"; NumberAnimation { duration: Tema.normal } }
    }
}
