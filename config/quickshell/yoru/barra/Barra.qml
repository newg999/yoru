// ============================================================================
//  Barra — una por pantalla. La barra en sí es invisible: solo se ven las islas.
//
//    [apps] [escritorios] [título]    [música] [reloj] [clima]    [bandeja] [recursos] [conexión]
//
//  El reloj va siempre en el centro exacto; la música y el clima, a sus lados.
//  Con el overview abierto (Mod+Tab) la barra sube y desaparece, como en DMS.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: barra
    required property ShellScreen modelData
    screen: modelData

    // Monitor pequeño (portátil) → títulos más cortos
    readonly property bool pequena: modelData.width < 1800

    anchors { top: true; left: true; right: true }
    implicitHeight: Tema.margenBarra + Tema.altoBarra
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    // Escondida: sin zona de clic, para que los clics lleguen al overview
    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    Item {
        id: contenido
        opacity: Niri.overview ? 0 : 1
        transform: Translate {
            y: Niri.overview ? -(Tema.altoBarra + Tema.margenBarra) : 0
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }

        anchors {
            fill: parent
            topMargin: Tema.margenBarra
            leftMargin: Tema.margenLados
            rightMargin: Tema.margenLados
        }

        // ---------------------------------------------------------- Izquierda
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: Tema.separacion

            BotonApps { pantalla: barra.modelData }
            Escritorios { salida: barra.modelData.name }
            Titulo {
                salida: barra.modelData.name
                maximo: barra.pequena ? 300 : 420
            }
        }

        // ------------------------------------------------------------- Centro
        Musica {
            anchors { right: reloj.left; rightMargin: Tema.separacion; verticalCenter: parent.verticalCenter }
            pantalla: barra.modelData
            maximo: barra.pequena ? 140 : 200
        }
        Reloj {
            id: reloj
            anchors.centerIn: parent
            pantalla: barra.modelData
        }
        Clima {
            anchors { left: reloj.right; leftMargin: Tema.separacion; verticalCenter: parent.verticalCenter }
            pantalla: barra.modelData
        }

        // ------------------------------------------------------------ Derecha
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tema.separacion
            layoutDirection: Qt.LeftToRight

            Bandeja { ventana: barra }
            Recursos { pantalla: barra.modelData }
            Conexion { pantalla: barra.modelData }
        }
    }
}
