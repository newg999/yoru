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
//                               // (con la barra en píldora, todos menos
//                               // «medio» salen centrados bajo ella)
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

    // Clic fuera = cerrar
    MouseArea {
        anchors.fill: parent
        onClicked: Paneles.cerrar()
    }

    Rectangle {
        id: caja

        width: ventana.ancho
        height: interior.implicitHeight + 32
        readonly property bool enMedio: ventana.lado === "medio"
        // Con la barra minimalista, pegado a ella: sin hueco, esquinas de
        // arriba rectas, su mismo fondo y un borde fino
        readonly property bool pegado: Ajustes.minimalista && !enMedio
        // Con la barra en píldora, todo sale centrado bajo ella (con la
        // minimalista, cada uno bajo su botón, como con las islas)
        readonly property string sitio: Ajustes.pildora && !enMedio ? "centro" : ventana.lado

        // Al abrirse se desliza un poco desde la barra
        readonly property real deslizar: (1 - ventana.progreso) * 14

        x: enMedio ? Math.round((parent.width - width) / 2)
            : ventana.vertical ? Tema.hueco - deslizar
            : sitio === "izquierda" ? Tema.margenLados
            : sitio === "centro" ? (parent.width - width) / 2
            : parent.width - width - Tema.margenLados
        y: enMedio ? Math.round((parent.height - height) / 2)
            : pegado ? Tema.altoBarra + 2
            : !ventana.vertical ? Tema.hueco - deslizar
            : sitio === "izquierda" ? Tema.margenLados + 6
            : sitio === "centro" ? Math.round((parent.height - height) / 2)
            : parent.height - height - Tema.margenLados - 6

        opacity: ventana.progreso
        // Pegado a la barra no encoge (se despegaría de ella): solo aparece
        scale: pegado ? 1 : (enMedio ? 0.94 : 0.96) + (enMedio ? 0.06 : 0.04) * ventana.progreso
        transformOrigin: enMedio ? Item.Center : ventana.vertical ? Item.Left : Item.Top

        radius: Tema.radioPanel
        topLeftRadius: pegado ? 0 : radius
        topRightRadius: pegado ? 0 : radius
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

        Behavior on height { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

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
