// ============================================================================
//  Avisos — las notificaciones que acaban de llegar, arriba a la derecha,
//  bajo la barra (o en el centro, según Ajustes › Notificaciones). Se van
//  solas a los 5 s (o lo elegido allí; las urgentes se quedan hasta que
//  las cierras); con el ratón encima no se van. Aunque se vayan, siguen en
//  el panel de notificaciones (la campana de la barra).
//
//  Salen en la pantalla que tiene el foco. Con el panel de notificaciones
//  abierto no salen: ya están ahí.
//
//  Con la barra minimalista, dentro de un recuadro pegado a ella (mismo
//  fondo, esquinas rectas, hasta el borde de la pantalla) que baja como una
//  persiana, como sus paneles.
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
    // (con el estilo Dock no: los saca el propio dock, yoru-dock)
    // (con la píldora abierta tampoco: saldrían encima de ella; esperan)
    readonly property bool mostrar: enfocada && !Paneles.esta("notificaciones", modelData)
        && !(Ajustes.pildora && Paneles.esta("pildora", modelData))
        && Notificaciones.emergentes.length > 0 && !Ajustes.estiloDock

    readonly property bool minima: Ajustes.minimalista
    readonly property bool aLaDerecha: Ajustes.avisosLado !== "centro" && !Ajustes.pildora
    readonly property int relleno: minima ? 10 : 0

    // Al aparecer, el recuadro de la minimalista baja desde la barra
    property real aparecer: 0
    onMostrarChanged: {
        if (mostrar) {
            aparecer = 0;
            bajar.restart();
        }
    }
    NumberAnimation {
        id: bajar
        target: ventana
        property: "aparecer"
        to: 1
        duration: Tema.normal
        easing.type: Easing.OutCubic
    }

    visible: mostrar
    // A la derecha o en el centro (Ajustes › Notificaciones); con la barra
    // en píldora, siempre en el centro, bajo ella
    anchors { top: true; right: aLaDerecha }
    // Bajo la barra (pegados a ella con la minimalista); con la barra a la
    // izquierda, arriba del todo
    margins.top: minima ? Tema.altoBarra + 2 : Ajustes.vertical ? Tema.margenLados + 6 : Tema.hueco
    margins.right: minima ? 0 : Tema.margenLados
    implicitWidth: minima ? 400 : 380
    implicitHeight: Math.max(1, minima ? fondo.height : pila.height)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-avisos"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Solo se pueden pulsar las tarjetas (o su recuadro); el resto deja pasar los clics
    mask: Region { item: ventana.minima ? fondo : pila }

    // Minimalista: el recuadro pegado a la barra
    Rectangle {
        id: fondo
        visible: ventana.minima
        // Pegado al borde de la pantalla, su borde de ese lado queda fuera
        width: parent.width + (ventana.aLaDerecha ? border.width : 0)
        height: pila.height + 2 * ventana.relleno
        y: -(1 - ventana.aparecer) * height
        color: Tema.panel
        // Todo recto, como la barra minimalista
        radius: 0
        border.width: Tema.borde(1)
        border.color: Tema.claro(0.08)
        Behavior on height { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

        // Sin borde arriba: se funde con la barra
        Rectangle {
            visible: parent.border.width > 0
            x: parent.border.width
            width: parent.width - 2 * parent.border.width
            height: parent.border.width
            color: parent.color
        }
    }

    ListView {
        id: pila
        x: ventana.relleno
        y: ventana.minima ? fondo.y + ventana.relleno : 0
        width: parent.width - 2 * ventana.relleno
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
            // Sueltas, con el fondo y el borde de un panel; en la minimalista,
            // dentro de su recuadro, como las del centro de control
            color: ventana.minima ? (hover ? Tema.cajaHover : Tema.caja) : hover ? Tema.sombra(0.95) : Tema.panel
            border.color: urgente ? Tema.rojo : ventana.minima ? Tema.claro(0.06) : Tema.panelBorde
            border.width: urgente ? 2 : ventana.minima ? 1 : Tema.borde(2)
            radius: ventana.minima ? 12 : Tema.radioPanel

            // Entra desde la derecha (aquí y no en «add» de la lista: si
            // llegan varias seguidas, esa animación se cortaba a medias)
            transform: Translate { id: desliz; x: 0 }
            ParallelAnimation {
                running: true
                NumberAnimation { target: desliz; property: "x"; from: ventana.minima ? 0 : 60; to: 0; duration: Tema.normal; easing.type: Easing.OutCubic }
                NumberAnimation { target: aviso; property: "opacity"; from: 0; to: 1; duration: Tema.normal }
            }

            // Tiempo: el que pida la app, o el de Ajustes; las urgentes, sin límite
            // (Quickshell da expireTimeout en segundos)
            readonly property int duracion: aviso.n?.expireTimeout > 0 ? aviso.n.expireTimeout * 1000
                : aviso.urgente ? 0 : Ajustes.avisosSegundos * 1000
            Timer {
                interval: aviso.duracion
                running: aviso.duracion > 0 && !aviso.hover && ventana.mostrar
                onTriggered: Notificaciones.ocultar(aviso.modelData)
            }
        }
    }
}
