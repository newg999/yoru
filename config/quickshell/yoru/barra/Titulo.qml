// ============================================================================
//  Ventana activa de esta pantalla: icono de la app (en blanco, a juego con
//  la barra) y título. Sin ventanas, la isla desaparece.
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.comun

Isla {
    id: isla
    required property string salida
    property int maximo: 420       // píxeles; lo que no quepa se corta con "…"

    readonly property var ventana: Niri.ventanaEn(salida)
    // El icono sale del .desktop de la app (por su app-id)
    readonly property string icono: {
        if (!ventana)
            return "";
        const app = DesktopEntries.heuristicLookup(ventana.app_id);
        return Quickshell.iconPath(app?.icon ?? ventana.app_id, true);
    }

    relleno: 12
    espacio: 8

    Item {
        visible: isla.ventana !== null && isla.icono !== ""
        implicitWidth: 16
        implicitHeight: Tema.altoBarra

        IconImage {
            id: iconoApp
            anchors.centerIn: parent
            implicitSize: 16
            source: isla.icono
            visible: false
        }
        // Silueta en blanco del icono
        MultiEffect {
            anchors.fill: iconoApp
            source: iconoApp
            colorization: 1
            colorizationColor: Tema.blanco
            brightness: 1
        }
    }

    Texto {
        text: isla.ventana?.title ?? ""
        visible: text !== ""
        font.bold: false
        elide: Text.ElideRight
        width: Math.min(implicitWidth, isla.maximo)
        height: Tema.altoBarra
    }
}
