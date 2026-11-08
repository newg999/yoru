// ============================================================================
//  Bandeja del sistema: iconos de apps en segundo plano (Discord, Telegram...)
//  Clic = abrir su ventana (o su panel de Yoru, como MEGA) · Clic derecho =
//  su menú (con el aspecto de Yoru: paneles/PanelBandeja.qml) · Clic
//  central = acción 2
//  Al pasar el ratón crecen un poco y se iluminan.
//  Los que están en reposo (Passive, p. ej. mate-polkit) no se muestran.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.comun

Isla {
    id: isla
    required property var ventana     // la barra (su pantalla, para abrir los paneles)
    relleno: 5

    // Clic: su ventana al frente si ya la tiene (y si ya estaba delante, se
    // cierra: vuelve a la bandeja, como el panel de MEGA); si no, se abre la
    // app por su lanzador (Steam y otras con AppIndicator no responden a
    // «activate»: solo enseñan su menú); si no hay lanzador, «activate»
    // Las apps con un panel propio de Yoru: su icono abre (y cierra) ese
    // panel, colgando de la isla como los demás, en vez de su ventana
    readonly property var paneles: ({MEGAsync: "mega"})

    function abrir(item) {
        if (paneles[item.id]) {
            Paneles.alternar(paneles[item.id], isla.ventana.screen);
            return;
        }
        const entrada = DesktopEntries.heuristicLookup(item.id);
        const ids = [item.id, entrada?.id ?? ""].map(x => x.toLowerCase()).filter(x => x !== "");
        const ventana = Object.values(Niri.ventanas).find(v => ids.includes((v.app_id ?? "").toLowerCase()));
        if (ventana && Niri.enfocada?.id === ventana.id)
            Niri.accion("close-window", "--id", String(ventana.id));
        else if (ventana)
            Niri.accion("focus-window", "--id", String(ventana.id));
        else if (entrada)
            Niri.lanzar(entrada.command);
        else
            item.activate();
    }

    Repeater {
        model: SystemTray.items

        Item {
            id: elemento
            required property SystemTrayItem modelData
            visible: modelData.status !== Status.Passive
            implicitWidth: 30
            implicitHeight: Tema.altoBarra

            IconImage {
                anchors.centerIn: parent
                implicitSize: 20
                source: elemento.modelData.icon
                scale: raton.containsMouse ? 1.18 : 1
                Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
            }

            // Brillo al pasar el ratón
            Rectangle {
                anchors.centerIn: parent
                width: 26; height: 26; radius: Tema.esquina(8)
                color: Tema.blanco
                opacity: raton.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
            }

            // Aviso (needs attention): puntito rojo
            Rectangle {
                visible: elemento.modelData.status === Status.NeedsAttention
                width: 6; height: 6; radius: 3
                color: Tema.rojo
                anchors { right: parent.right; top: parent.top; margins: 6 }
            }

            MouseArea {
                id: raton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    const item = elemento.modelData;
                    if (e.button === Qt.RightButton || (e.button === Qt.LeftButton && item.onlyMenu)) {
                        if (item.hasMenu)
                            Paneles.alternar("bandeja", isla.ventana.screen, item.id);
                    } else if (e.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else {
                        isla.abrir(item);
                    }
                }
                onWheel: e => elemento.modelData.scroll(e.angleDelta.y / 120, false)
            }
        }
    }
}
