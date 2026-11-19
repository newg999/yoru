// ============================================================================
//  Bandeja del sistema: iconos de apps en segundo plano (Discord, Telegram...)
//  Clic = ir a su ventana (a su escritorio) o, si ya está delante,
//  esconderla (o su panel de Yoru, como MEGA) · Clic derecho =
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

    // Clic: te lleva a su ventana, al escritorio donde esté (si estaba
    // escondida, vuelve al suyo). Otro clic, con ella delante, la esconde.
    // Esconder no la cierra (Spotify, al cerrar, se sale del todo): se va al
    // escritorio escondido de las minimizadas (comun/Tareas.qml).
    // Sin ventana (la cerraste con su X y quedó en la bandeja), se abre por
    // su lanzador (Steam y otras con AppIndicator no responden a «activate»:
    // solo enseñan su menú); si no hay lanzador, «activate».
    // Las apps con un panel propio de Yoru: su icono abre (y cierra) ese
    // panel, colgando de la isla como los demás, en vez de su ventana
    readonly property var paneles: ({MEGAsync: "mega"})

    function idsDe(item) {
        const entrada = DesktopEntries.heuristicLookup(item.id);
        return [item.id, entrada?.id ?? "", entrada?.startupClass ?? ""]
            .map(x => x.toLowerCase().replace(/\.desktop$/, "")).filter(x => x !== "");
    }

    // ¿Está delante? La última ventana que usaste es suya y está en el
    // escritorio que se ve. (No vale mirar el foco: con un panel abierto o
    // tras pulsar la barra, niri no deja ninguna ventana con el foco, y el
    // segundo clic no la escondía)
    function delante(suyas) {
        const vistas = Object.values(Niri.ventanas).filter(v => !Tareas.minimizada(v));
        const ultima = vistas.length > 0 ? Tareas.ultimaUsada(vistas) : null;
        if (!ultima || !suyas.some(v => v.id === ultima.id))
            return null;
        const escritorio = Niri.escritorios.find(e => e.id === ultima.workspace_id);
        return escritorio?.is_active ? ultima : null;
    }

    function abrir(item) {
        if (paneles[item.id]) {
            Paneles.alternar(paneles[item.id], isla.ventana.screen);
            return;
        }
        // Ir a una app cierra el panel que hubiera (el de MEGA seguía abierto
        // encima: los clics en la barra le llegan aunque haya uno abierto)
        Paneles.cerrar();
        const ids = idsDe(item);
        const suyas = Object.values(Niri.ventanas).filter(v => ids.includes((v.app_id ?? "").toLowerCase()));
        const ya = delante(suyas);
        if (ya)
            Tareas.minimizar(ya);
        else if (suyas.length > 0)
            Tareas.irA(Tareas.ultimaUsada(suyas));
        else if (DesktopEntries.heuristicLookup(item.id))
            Niri.lanzar(DesktopEntries.heuristicLookup(item.id).command);
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
                // Dibujado al tamaño grande y encogido en reposo (estirar el
                // pequeño al pasar el ratón lo pixelaba)
                implicitSize: 24
                source: elemento.modelData.icon
                mipmap: true
                scale: (raton.containsMouse ? 1.18 : 1) * 20 / 24
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
