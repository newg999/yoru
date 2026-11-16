// ============================================================================
//  Páginas del panel de las islas y de la barra minimalista: una a la vista,
//  con fundido al cambiar y el alto ajustándose suave
//  (al abrirse el panel, sin fundido propio: entra con el panel, como el
//  Inicio, y no cada página a su manera)
//
//    control · calendario · multimedia · clima · sistema · temas · fondos
//    red · bt · sonido · musica   (solo eso: las islas en píldoras, PaginaSola.qml)
//    actualizaciones              (PaginaActualizaciones.qml, con su isla)
//
//  La página es la sección del panel «pildora» (el nombre es de cuando
//  existía la píldora; Paneles.seccion):
//      Paneles.alternar("pildora", pantalla, "clima")
//  Lo usa paneles/PanelPaginas.qml (bajo las islas o la barra minimalista).
// ============================================================================
import QtQuick
import qs.comun

Item {
    id: raiz

    required property var pantalla
    property bool abierta: false
    property int altoMax: 700

    readonly property var todas: ["control", "calendario", "multimedia", "clima", "sistema", "temas", "fondos", "red", "bt", "sonido", "musica", "actualizaciones"]
    readonly property bool sola: ["red", "bt", "sonido", "musica"].includes(pagina)
    // (wifi, bluetooth, audio y micro son el control con esa lista abierta)
    // Si otro panel se abre (el Inicio, los avisos), la sección se queda
    // vacía: mientras este se cierra, sigue con su página. Antes volvía de
    // golpe al centro de control y, del wifi al Inicio, el panel que se iba
    // cambiaba de tamaño y de contenido a medio camino
    property string pagina: "control"
    function elegir() {
        if (todas.includes(Paneles.seccion))
            pagina = Paneles.seccion;
        else if (Paneles.abierto === "pildora")
            pagina = "control";
    }
    Component.onCompleted: elegir()
    Connections {
        target: Paneles
        function onSeccionChanged() { raiz.elegir(); }
        function onAbiertoChanged() { raiz.elegir(); }
    }
    // Multimedia es la pestaña del panel central: pide más sitio. Las que
    // copian los paneles del dock, algo menos
    // (la de red, con el aspecto del panel del dock: algo más estrecha)
    readonly property int anchoPedido: pagina === "multimedia" ? 620 : ["red", "bt", "sonido", "calendario", "clima", "actualizaciones"].includes(pagina) || (pagina === "control" && Ajustes.conPildoras) ? 400 : 460
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
        : pagina === "actualizaciones" ? actualizaciones.implicitHeight
        : sola ? solo.implicitHeight
        : Ajustes.conPildoras ? controlDock.implicitHeight
        : control.implicitHeight
    height: implicitHeight
    Behavior on height {
        enabled: raiz.abierta
        NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
    }

    PaginaActualizaciones {
        id: actualizaciones
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "actualizaciones"
        visible: raiz.pagina === "actualizaciones"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }

    // Con las islas y la minimalista, el centro de control con el aspecto del dock
    PaginaControlDock {
        id: controlDock
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.pagina === "control" && Ajustes.conPildoras
        visible: raiz.pagina === "control" && Ajustes.conPildoras
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaControl {
        id: control
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.pagina === "control" && !Ajustes.conPildoras
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "control" && !Ajustes.conPildoras
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaCalendario {
        id: calendario
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "calendario"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "calendario"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
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
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaClima {
        id: clima
        width: parent.width
        altoMax: raiz.altoMax
        activa: raiz.abierta && raiz.pagina === "clima"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "clima"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
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
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaTemas {
        id: temas
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "temas"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "temas"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaSola {
        id: solo
        width: parent.width
        cual: raiz.sola ? raiz.pagina : "red"
        pantalla: raiz.pantalla
        altoMax: raiz.altoMax
        activa: raiz.abierta && raiz.sola
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.sola
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaFondos {
        id: fondos
        width: parent.width
        activa: raiz.abierta && raiz.pagina === "fondos"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.pagina === "fondos"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
}
