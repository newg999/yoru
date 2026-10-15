// ============================================================================
//  Apps abiertas de esta pantalla, como una barra de tareas: un icono por
//  ventana (en blanco, ver comun/Iconos.qml), en el orden de niri (escritorio
//  y columna). La que tiene el foco va sobre una píldora; las de otros
//  escritorios, más apagadas. Es la alternativa a la isla del título
//  (Ajustes → Barra y dock). Sin ventanas, la isla desaparece.
//
//  Clic = ir a esa ventana · Clic central = cerrarla
//  Con el ratón encima, la ayuda dice qué ventana es
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Isla {
    id: isla
    required property string salida

    relleno: 6
    espacio: 4

    // Ventanas de los escritorios de esta pantalla, ordenadas como en niri
    readonly property var lista: {
        const escritorios = Niri.escritoriosDe(salida);
        const orden = {};
        escritorios.forEach((e, i) => orden[e.id] = i);
        const pos = v => v.layout?.pos_in_scrolling_layout ?? [999, 999];
        return Object.values(Niri.ventanas)
            .filter(v => v.workspace_id in orden)
            .sort((a, b) => orden[a.workspace_id] - orden[b.workspace_id]
                || pos(a)[0] - pos(b)[0] || pos(a)[1] - pos(b)[1] || a.id - b.id);
    }
    readonly property int escritorioActivo: Niri.escritoriosDe(salida).find(e => e.is_active)?.id ?? -1

    // La ventana bajo el ratón (para la ayuda)
    property var sobre: null
    ayuda: !sobre ? ""
        : Tema.html(sobre.title || sobre.app_id) + "<br>" + Tema.suave(Tema.html(nombre(sobre.app_id)))

    function nombre(appId) {
        return DesktopEntries.heuristicLookup(appId)?.name ?? appId;
    }

    Repeater {
        model: isla.lista

        Item {
            id: elemento
            required property var modelData
            readonly property bool enfocada: modelData.is_focused
            readonly property bool aqui: modelData.workspace_id === isla.escritorioActivo

            implicitWidth: isla.vertical ? Tema.anchoBarra - 2 * isla.rellenoVertical : 28
            implicitHeight: isla.vertical ? 28 : Tema.altoBarra

            Rectangle {
                anchors.centerIn: parent
                width: 28
                height: 24
                radius: Math.min(Tema.radio, 8)
                color: elemento.enfocada ? Tema.activo : raton.containsMouse ? Tema.cajaHover : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
            }

            Texto {
                anchors.centerIn: parent
                text: Iconos.app(elemento.modelData.app_id)
                font.pixelSize: Tema.icono
                color: elemento.modelData.is_urgent ? Tema.rojo
                    : elemento.enfocada || raton.containsMouse ? Tema.blanco
                    : elemento.aqui ? Tema.claro(0.7)
                    : Tema.tenue
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
            }

            MouseArea {
                id: raton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onContainsMouseChanged: {
                    if (containsMouse)
                        isla.sobre = elemento.modelData;
                    else if (isla.sobre?.id === elemento.modelData.id)
                        isla.sobre = null;
                }
                onClicked: e => {
                    if (e.button === Qt.MiddleButton)
                        Niri.accion("close-window", "--id", String(elemento.modelData.id));
                    else
                        Niri.accion("focus-window", "--id", String(elemento.modelData.id));
                }
            }
        }
    }
}
