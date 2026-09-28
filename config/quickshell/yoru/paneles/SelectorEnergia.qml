// ============================================================================
//  Perfil de energía: [󰌪 Ahorro] [󰾅 Equilibrado] [󱐋 Rendimiento]
//  Usa el servicio estándar de perfiles (power-profiles-daemon, o tuned-ppd
//  en Fedora). Sin él, no se muestra.
// ============================================================================
import QtQuick
import Quickshell.Services.UPower
import qs.comun

Row {
    id: selector

    readonly property var perfiles: [
        {perfil: PowerProfile.PowerSaver, icono: "󰌪", texto: "Ahorro"},
        {perfil: PowerProfile.Balanced, icono: "󰾅", texto: "Equilibrado"},
        {perfil: PowerProfile.Performance, icono: "󱐋", texto: "Rendimiento"}
    ].filter(p => p.perfil !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

    spacing: 6

    Repeater {
        model: selector.perfiles

        Rectangle {
            id: boton
            required property var modelData
            readonly property bool elegido: PowerProfiles.profile === modelData.perfil
            width: (selector.width - selector.spacing * (selector.perfiles.length - 1)) / selector.perfiles.length
            height: 36
            radius: 10
            color: elegido ? Tema.claro(0.90) : raton.containsMouse ? Tema.cajaHover : Tema.caja
            Behavior on color { ColorAnimation { duration: Tema.rapida } }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Texto {
                    text: boton.modelData.icono
                    font.pixelSize: 15
                    color: boton.elegido ? Tema.oscuro : Tema.texto
                }
                Texto {
                    text: boton.modelData.texto
                    font.pixelSize: 12
                    color: boton.elegido ? Tema.oscuro : Tema.texto
                }
            }

            MouseArea {
                id: raton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: PowerProfiles.profile = boton.modelData.perfil
            }
        }
    }
}
