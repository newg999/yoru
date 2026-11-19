// ============================================================================
//  Páginas del panel de las islas y de la barra minimalista: una a la vista,
//  con fundido al cambiar y el alto ajustándose suave
//  (al abrirse el panel, sin fundido propio: entra con el panel, como el
//  Inicio, y no cada página a su manera)
//
//    control · calendario · multimedia · clima · sistema · temas · fondos
//    red · bt · sonido · musica   (solo eso: las islas en píldoras, PaginaSola.qml)
//    actualizaciones              (PaginaActualizaciones.qml, con su isla)
//    bateria                      (PaginaBateria.qml, con las islas)
//
//  Al pasar de una a otra de la misma isla, la nueva entra deslizándose
//  desde el lado de su icono: del wifi al volumen o a la batería, desde la
//  derecha; de vuelta, desde la izquierda (y del tiempo a la hora, igual)
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

    readonly property var todas: ["control", "calendario", "multimedia", "clima", "sistema", "temas", "fondos", "red", "bt", "sonido", "musica", "actualizaciones", "bateria"]
    readonly property bool sola: ["red", "bt", "sonido", "musica"].includes(mostrada)
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

    // El orden de los iconos en sus islas, de izquierda a derecha: el tiempo
    // y la hora; wifi, Bluetooth, volumen, batería y el centro de control
    readonly property var orden: ["clima", "calendario", "red", "bt", "sonido", "bateria", "control"]
    // La que se ve: sigue a «pagina», pero entre dos de la misma isla espera
    // a que la de antes haya salido por su lado (un carrusel)
    property string mostrada: pagina
    property real desliz: 0
    property real fundido: 1
    property real lado: 1
    onPaginaChanged: {
        const a = orden.indexOf(mostrada), b = orden.indexOf(pagina);
        cambio.stop();
        if (!abierta || a < 0 || b < 0 || a === b || Tema.normal === 0) {
            mostrada = pagina;
            desliz = 0;
            fundido = 1;
            return;
        }
        lado = b > a ? 1 : -1;
        cambio.start();
    }
    // Sale la de antes hacia el lado contrario y entra la nueva desde el suyo
    SequentialAnimation {
        id: cambio
        ParallelAnimation {
            NumberAnimation { target: raiz; property: "desliz"; to: -raiz.lado * 70; duration: Tema.ms(150); easing.type: Easing.InCubic }
            NumberAnimation { target: raiz; property: "fundido"; to: 0; duration: Tema.ms(150); easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                raiz.mostrada = raiz.pagina;
                raiz.desliz = raiz.lado * 70;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: raiz; property: "desliz"; to: 0; duration: Tema.ms(300); easing.type: Easing.OutCubic }
            NumberAnimation { target: raiz; property: "fundido"; to: 1; duration: Tema.ms(240); easing.type: Easing.OutCubic }
        }
    }
    opacity: fundido
    transform: Translate { x: raiz.desliz }
    Connections {
        target: Paneles
        function onSeccionChanged() { raiz.elegir(); }
        function onAbiertoChanged() { raiz.elegir(); }
    }
    // Multimedia es la pestaña del panel central: pide más sitio. Las que
    // copian los paneles del dock, algo menos
    // (la de red, con el aspecto del panel del dock: algo más estrecha)
    readonly property int anchoPedido: pagina === "multimedia" ? 620 : ["red", "bt", "sonido", "calendario", "clima", "actualizaciones", "bateria"].includes(pagina) || (pagina === "control" && Ajustes.conPildoras) ? 400 : 460
    // Ir a una página (la que ya se ve: volver a control)
    function ir(p) {
        Paneles.alternar("pildora", pantalla, abierta && pagina === p ? "control" : p);
    }

    implicitHeight: mostrada === "calendario" ? calendario.implicitHeight
        : mostrada === "multimedia" ? multimedia.implicitHeight
        : mostrada === "clima" ? clima.implicitHeight
        : mostrada === "sistema" ? sistema.implicitHeight
        : mostrada === "temas" ? temas.implicitHeight
        : mostrada === "fondos" ? fondos.implicitHeight
        : mostrada === "actualizaciones" ? actualizaciones.implicitHeight
        : mostrada === "bateria" ? bateria.implicitHeight
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
        activa: raiz.abierta && raiz.mostrada === "actualizaciones"
        visible: raiz.mostrada === "actualizaciones"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }

    // Con las islas y la minimalista, el centro de control con el aspecto del dock
    PaginaControlDock {
        id: controlDock
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.mostrada === "control" && Ajustes.conPildoras
        visible: raiz.mostrada === "control" && Ajustes.conPildoras
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaControl {
        id: control
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.mostrada === "control" && !Ajustes.conPildoras
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "control" && !Ajustes.conPildoras
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaCalendario {
        id: calendario
        width: parent.width
        activa: raiz.abierta && raiz.mostrada === "calendario"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "calendario"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    // Las mismas pestañas del panel central
    PestanaMultimedia {
        id: multimedia
        width: parent.width
        activa: raiz.abierta && raiz.mostrada === "multimedia"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "multimedia"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaClima {
        id: clima
        width: parent.width
        altoMax: raiz.altoMax
        activa: raiz.abierta && raiz.mostrada === "clima"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "clima"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaSistema {
        id: sistema
        width: parent.width
        pantalla: raiz.pantalla
        activa: raiz.abierta && raiz.mostrada === "sistema"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "sistema"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaTemas {
        id: temas
        width: parent.width
        activa: raiz.abierta && raiz.mostrada === "temas"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "temas"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaSola {
        id: solo
        width: parent.width
        cual: raiz.sola ? raiz.mostrada : "red"
        pantalla: raiz.pantalla
        altoMax: raiz.altoMax
        activa: raiz.abierta && raiz.sola
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.sola
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaBateria {
        id: bateria
        width: parent.width
        abierto: raiz.abierta && raiz.mostrada === "bateria"
        visible: raiz.mostrada === "bateria"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
    PaginaFondos {
        id: fondos
        width: parent.width
        activa: raiz.abierta && raiz.mostrada === "fondos"
        // Solo la elegida: la que se va se oculta al momento (con un fundido
        // se veía un instante encima de la nueva); la que llega, con fundido
        visible: raiz.mostrada === "fondos"
        opacity: visible ? 1 : 0
        Behavior on opacity { enabled: raiz.abierta; NumberAnimation { duration: Tema.normal } }
    }
}
