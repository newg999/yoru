// ============================================================================
//  Panel — recuadro que se despliega bajo la barra (como los de DMS)
//  Con la barra a la izquierda, sale a su derecha: «izquierda» arriba,
//  «centro» en medio y «derecha» abajo (donde quedan sus botones).
//
//  La ventana ocupa la pantalla entera pero es invisible: así un clic fuera
//  del recuadro lo cierra.
//  Esc también lo cierra.
//
//    Panel {
//        nombre: "conexion"     // el que abre Paneles.alternar("conexion", ...)
//        lado: "derecha"        // "izquierda", "centro", "derecha"
//                               // o "medio" (en mitad de la pantalla)
//        MiContenido {}
//    }
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    property string nombre: ""
    property string lado: "derecha"
    property int ancho: 420
    // {x, ancho}: justo debajo de una isla y de su ancho (Paneles.ancla)
    property var ancla: null
    default property alias contenido: interior.data

    readonly property bool abierto: Paneles.abierto === nombre && Paneles.pantalla === modelData
    readonly property bool vertical: Ajustes.vertical

    // Alto máximo del recuadro en ESTA pantalla (bajo la barra, con margen).
    // Los paneles con listas largas las acortan con esto para caber también
    // en monitores pequeños (1080p, portátiles de 768...)
    readonly property int altoMax: modelData.height - (vertical ? 2 * Tema.margenLados + 12 : Tema.hueco) - 12

    // 0 = cerrado · 1 = abierto. La ventana sigue visible hasta que termina
    // la animación de cierre.
    property real progreso: abierto ? 1 : 0
    Behavior on progreso {
        NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
    }

    screen: modelData
    visible: abierto || progreso > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-panel"
    WlrLayershell.layer: WlrLayer.Top
    // Teclado para Esc y para escribir contraseñas
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Sin desenfoque detrás del recuadro (las islas de la barra sí lo
    // tienen): el de niri no se puede desvanecer, y al ponerse al final de
    // la animación el panel cambiaba de golpe de tono (parecía un parpadeo).

    // Clic fuera = cerrar. Menos en la franja de la barra: ahí los clics
    // pasan a la barra, así que pulsar otro botón con un panel abierto lo
    // abre a la primera (antes el primer clic solo cerraba este)
    mask: Region {
        item: entera
        Region { item: franjaBarra; intersection: Intersection.Subtract }
    }
    Item { id: entera; anchors.fill: parent }
    Item {
        id: franjaBarra
        width: ventana.vertical ? Tema.margenBarra + Tema.anchoBarra : parent.width
        height: ventana.vertical ? parent.height
            : Ajustes.minimalista ? Tema.altoBarra + 2 : Tema.margenBarra + Tema.altoBarra
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Paneles.cerrar()
    }

    // Con la minimalista, el panel baja desde la barra como una persiana: se
    // recorta justo por debajo de ella para no pintarse encima mientras baja
    Item {
        id: recorte
        anchors.fill: parent
        anchors.topMargin: Ajustes.minimalista ? Tema.altoBarra + 2 : 0
        clip: Ajustes.minimalista

        Rectangle {
            id: caja

            readonly property bool anclado: ventana.ancla !== null && !ventana.vertical
            width: anclado ? ventana.ancla.ancho : ventana.ancho
            height: interior.implicitHeight + 32
            readonly property bool enMedio: ventana.lado === "medio"
            // Con la barra minimalista, pegado a ella: sin hueco, esquinas
            // rectas, su mismo fondo y un borde fino
            readonly property bool pegado: Ajustes.minimalista && !enMedio
            readonly property string sitio: ventana.lado

            // Al abrirse se desliza un poco desde la barra
            readonly property real deslizar: (1 - ventana.progreso) * 14

            x: enMedio ? Math.round((parent.width - width) / 2)
                : anclado ? ventana.ancla.x
                : ventana.vertical ? Tema.hueco - deslizar
                // Pegado al borde de la pantalla, su borde de ese lado queda
                // fuera (si no, se veía una línea fina contra el borde)
                : sitio === "izquierda" ? (pegado ? -border.width : Tema.margenLados)
                : sitio === "centro" ? (parent.width - width) / 2
                : parent.width - width - (pegado ? -border.width : Tema.margenLados)
            // (en el recorte, que con la minimalista empieza bajo la barra)
            y: enMedio ? Math.round((ventana.height - height) / 2) - recorte.y
                : pegado ? -(1 - ventana.progreso) * height
                : !ventana.vertical ? Tema.hueco - deslizar
                : sitio === "izquierda" ? Tema.margenLados + 6
                : sitio === "centro" ? Math.round((parent.height - height) / 2)
                : parent.height - height - Tema.margenLados - 6

            // Pegado a la barra baja como una persiana (ver «recorte»), sin
            // fundido ni encoger (se despegaría de ella)
            opacity: pegado ? 1 : ventana.progreso
            scale: pegado ? 1 : (enMedio ? 0.94 : 0.96) + (enMedio ? 0.06 : 0.04) * ventana.progreso
            transformOrigin: enMedio ? Item.Center : ventana.vertical ? Item.Left : Item.Top

            radius: Tema.radioPanel
            // Pegado a la barra minimalista: todo recto, como ella
            topLeftRadius: pegado ? 0 : radius
            topRightRadius: pegado ? 0 : radius
            bottomLeftRadius: pegado ? 0 : radius
            bottomRightRadius: pegado ? 0 : radius
            color: Tema.panel
            border.width: pegado ? Tema.borde(1) : Tema.borde(2)
            border.color: pegado ? Tema.claro(0.08) : Tema.panelBorde
            clip: true

            // Pegado: sin borde arriba (se funde con la barra)
            Rectangle {
                visible: caja.pegado && caja.border.width > 0
                x: caja.border.width
                width: parent.width - 2 * caja.border.width
                height: caja.border.width
                color: caja.color
                z: 1
            }

            // Solo con el panel ya abierto (al cambiar de sección o página): al
            // abrirse toma su tamaño directamente, sin arrastrar el de la última vez
            Behavior on height {
                enabled: ventana.abierto && ventana.progreso === 1
                NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
            }

            // Los clics dentro del recuadro no lo cierran
            MouseArea {
                anchors.fill: parent
            }

            FocusScope {
                id: foco
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Paneles.cerrar()

                Item {
                    id: interior
                    x: 16; y: 16
                    width: parent.width - 32
                    implicitHeight: childrenRect.height
                }
            }
        }
    }
}
