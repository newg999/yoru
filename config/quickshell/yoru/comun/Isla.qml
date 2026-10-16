// ============================================================================
//  Isla — recuadro translúcido de la barra que agrupa uno o varios módulos
//  Los módulos se ponen dentro y se colocan en fila (o en columna, con la
//  barra a la izquierda: Ajustes.vertical).
//  Si no hay nada visible dentro (u oculta: true), la isla se desvanece.
//  Con pulsable: true, la isla entera es un solo botón (avisa con clic(boton)
//  y rueda(pasos)); al pasar el ratón se iluminan sus módulos, como los demás
//  (resaltado: isla.hover), sin cambiar el fondo.
//  Con ayuda: "...", al dejar el ratón encima sale un recuadro con más
//  información (ver Ayuda.qml).
// ============================================================================
import QtQuick
import Quickshell

Rectangle {
    id: isla

    default property alias contenido: fila.data
    property int relleno: 14            // margen a izquierda y derecha (arriba y abajo en vertical)
    property alias espacio: fila.spacing
    property bool oculta: false         // quitada en Ajustes
    readonly property bool vertical: Ajustes.vertical
    // Lo que ocupan los módulos visibles. No vale fila.implicitWidth: Grid
    // cuenta la separación de los ocultos (la batería en un PC, el Repeater...)
    // y dejaba más margen a un lado de la isla que al otro
    // Mientras la isla está oculta sus hijos también lo parecen (visible es
    // heredado) y salía 0: entonces vale la medida aproximada de Grid. (No se
    // mira isla.visible: depende de esto mismo y sería un bucle)
    readonly property real ocupado: {
        let fin = 0;
        for (const hijo of fila.children)
            if (hijo.visible)
                fin = Math.max(fin, vertical ? hijo.y + hijo.height : hijo.x + hijo.width);
        return fin > 0 ? Math.ceil(fin) : (vertical ? fila.implicitHeight : fila.implicitWidth);
    }
    property bool vacia: oculta || ocupado <= 0
    // Lo que ocuparía a lo largo de la barra aunque esté oculta (la barra lo
    // usa para ver si cabe sin chocar con las de al lado)
    readonly property int largoNatural: vertical ? ocupado + 2 * rellenoVertical
                                                 : ocupado + 2 * relleno
    // En vertical sobra tanto margen: los módulos ya llevan el suyo
    readonly property int rellenoVertical: Math.min(relleno, 6)
    property bool pulsable: false
    readonly property alias hover: raton.containsMouse
    property string ayuda: ""
    signal clic(int boton)
    signal rueda(int pasos)

    implicitWidth: vertical ? Tema.anchoBarra : vacia ? 0 : ocupado + 2 * relleno
    implicitHeight: !vertical ? Tema.altoBarra : vacia ? 0 : ocupado + 2 * rellenoVertical
    radius: Tema.radio
    color: Tema.isla
    border.width: Tema.borde(1)
    border.color: Tema.islaBorde
    clip: true

    opacity: vacia ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Tema.normal } }
    Behavior on implicitWidth { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

    MouseArea {
        id: raton
        anchors.fill: parent
        enabled: isla.pulsable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => isla.clic(e.button)
        onWheel: e => {
            if (e.angleDelta.y !== 0)
                isla.rueda(e.angleDelta.y > 0 ? 1 : -1);
        }
    }

    // Ayuda: tras un momento con el ratón encima; se quita al abrir o cerrar
    // un panel (lo normal después de un clic)
    HoverHandler { id: sobre }
    Timer {
        id: retraso
        property bool mostrar: false
        interval: 600
        running: sobre.hovered && !mostrar
        onTriggered: mostrar = true
    }
    Connections {
        target: sobre
        function onHoveredChanged() {
            if (!sobre.hovered)
                retraso.mostrar = false;
        }
    }
    Connections {
        target: Paneles
        function onAbiertoChanged() {
            retraso.mostrar = false;
        }
    }
    Ayuda {
        objetivo: isla
        texto: isla.ayuda
        mostrar: retraso.mostrar && Paneles.abierto === "" && !Niri.overview
    }

    // Una fila (barra arriba) o una columna (barra a la izquierda)
    Grid {
        id: fila
        // Solo cambian las columnas: una (en columna) o de sobra (en fila).
        // Cambiar filas y columnas a la vez pasa un momento por 1×1 y Qt avisa
        columns: isla.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        x: isla.vertical ? Math.round((isla.width - width) / 2) : isla.relleno
        y: isla.vertical ? isla.rellenoVertical : Math.round((isla.height - height) / 2)
        spacing: 0
    }
}
