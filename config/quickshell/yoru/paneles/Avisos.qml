// ============================================================================
//  Avisos — las notificaciones que acaban de llegar, arriba a la derecha,
//  bajo la barra. Se van solas a los 5 s (las urgentes se quedan hasta que
//  las cierras); con el ratón encima no se van. Aunque se vayan, siguen en
//  el panel de notificaciones (la campana de la barra).
//
//  Salen en la pantalla que tiene el foco. Con el panel de notificaciones
//  abierto no salen: ya están ahí.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.comun

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    screen: modelData

    readonly property bool enfocada: (Niri.escritorios.find(e => e.is_focused)?.output ?? modelData.name) === modelData.name
    readonly property bool mostrar: enfocada && !Paneles.esta("notificaciones", modelData)
        && Notificaciones.emergentes.length > 0

    visible: mostrar
    anchors { top: true; right: true }
    margins.top: Tema.margenBarra + Tema.altoBarra + 8
    margins.right: Tema.margenLados
    implicitWidth: 380
    implicitHeight: Math.max(1, pila.height)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-avisos"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Solo se pueden pulsar las tarjetas; el resto deja pasar los clics
    mask: Region { item: pila }

    ListView {
        id: pila
        width: parent.width
        height: Math.min(contentHeight, ventana.modelData.height * 0.7)
        spacing: 8
        interactive: false
        clip: true

        model: ScriptModel { values: Notificaciones.emergentes.slice(0, 5) }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: Tema.normal; easing.type: Easing.OutCubic }
        }

        delegate: TarjetaAviso {
            id: aviso
            required property var modelData
            entrada: modelData
            width: pila.width
            lineas: 3
            color: hover ? Tema.sombra(0.95) : Tema.panel
            border.color: urgente ? Tema.rojo : Tema.panelBorde
            border.width: 2
            radius: Tema.radioPanel

            // Entra desde la derecha (aquí y no en «add» de la lista: si
            // llegan varias seguidas, esa animación se cortaba a medias)
            transform: Translate { id: desliz; x: 0 }
            ParallelAnimation {
                running: true
                NumberAnimation { target: desliz; property: "x"; from: 60; to: 0; duration: Tema.normal; easing.type: Easing.OutCubic }
                NumberAnimation { target: aviso; property: "opacity"; from: 0; to: 1; duration: Tema.normal }
            }

            // Tiempo: el que pida la app, o 5 s; las urgentes, sin límite
            // (Quickshell da expireTimeout en segundos)
            readonly property int duracion: aviso.n?.expireTimeout > 0 ? aviso.n.expireTimeout * 1000
                : aviso.urgente ? 0 : 5000
            Timer {
                interval: aviso.duracion
                running: aviso.duracion > 0 && !aviso.hover && ventana.mostrar
                onTriggered: Notificaciones.ocultar(aviso.modelData)
            }
        }
    }
}
