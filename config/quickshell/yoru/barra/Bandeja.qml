// ============================================================================
//  Bandeja del sistema: iconos de apps en segundo plano (Discord, Telegram...)
//  Clic = abrir su ventana · Clic derecho = su menú · Clic central = acción 2
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
    required property var ventana     // la barra, para colocar los menús
    relleno: 5

    // Clic: su ventana al frente si ya la tiene; si no, se abre la app por
    // su lanzador (Steam y otras con AppIndicator no responden a
    // «activate»: solo enseñan su menú); si no hay lanzador, «activate»
    function abrir(item) {
        const entrada = DesktopEntries.heuristicLookup(item.id);
        const ids = [item.id, entrada?.id ?? ""].map(x => x.toLowerCase()).filter(x => x !== "");
        const ventana = Object.values(Niri.ventanas).find(v => ids.includes((v.app_id ?? "").toLowerCase()));
        if (ventana)
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
                width: 26; height: 26; radius: 8
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

            QsMenuAnchor {
                id: menu
                menu: elemento.modelData.menu
                anchor.window: isla.ventana
                anchor.item: elemento
                // Debajo del icono (o a su derecha, con la barra a la izquierda)
                anchor.edges: isla.vertical ? Edges.Right : Edges.Bottom
                anchor.gravity: isla.vertical ? Edges.Right : Edges.Bottom
                anchor.margins.top: isla.vertical ? 0 : 6
                anchor.margins.left: isla.vertical ? 6 : 0
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
                            menu.open();
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
