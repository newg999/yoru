// ============================================================================
//  Barra — una por pantalla. La barra en sí es invisible: solo se ven las islas.
//
//    [escritorios] [título]      [reloj] [música]      [recursos] [conexión] [bandeja]
//
//  El reloj va siempre en el centro exacto y la música se coloca a su derecha.
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

    Item {
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

            Escritorios { salida: barra.modelData.name }
            Titulo {
                salida: barra.modelData.name
                maximo: barra.pequena ? 300 : 420
            }
        }

        // ------------------------------------------------------------- Centro
        Reloj {
            id: reloj
            anchors.centerIn: parent
        }
        Musica {
            anchors { left: reloj.right; leftMargin: Tema.separacion; verticalCenter: parent.verticalCenter }
            maximo: barra.pequena ? 240 : 480
        }

        // ------------------------------------------------------------ Derecha
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tema.separacion
            layoutDirection: Qt.LeftToRight

            Recursos {}
            Conexion { pantalla: barra.modelData }
            Bandeja { ventana: barra }
        }
    }
}
