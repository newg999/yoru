// ============================================================================
//  Panel — recuadro que se despliega bajo la barra (como los de DMS)
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
    default property alias contenido: interior.data

    readonly property bool abierto: Paneles.abierto === nombre && Paneles.pantalla === modelData

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

    // Desenfoque detrás del recuadro (si el compositor lo permite).
    // Solo con el panel ya abierto del todo: el desenfoque no se puede
    // desvanecer, y si se deja durante la animación queda un rectángulo
    // borroso que no encaja con el recuadro y desaparece de golpe al final.
    BackgroundEffect.blurRegion: Region {
        item: ventana.abierto && ventana.progreso > 0.97 ? caja : null
        radius: Tema.radioPanel
    }

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

        x: ventana.lado === "izquierda" ? Tema.margenLados
            : ventana.lado === "centro" || enMedio ? (parent.width - width) / 2
            : parent.width - width - Tema.margenLados
        y: enMedio ? Math.round((parent.height - height) / 2)
            : Tema.margenBarra + Tema.altoBarra + 8 - (1 - ventana.progreso) * 14

        opacity: ventana.progreso
        scale: (enMedio ? 0.94 : 0.96) + (enMedio ? 0.06 : 0.04) * ventana.progreso
        transformOrigin: enMedio ? Item.Center : Item.Top

        radius: Tema.radioPanel
        color: Tema.panel
        border.width: 2
        border.color: Tema.panelBorde
        clip: true

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
