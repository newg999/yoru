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
//  persiana, como sus paneles. Con la de Windows, igual pero abajo a la
//  derecha, subiendo desde ella.
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
    readonly property bool mostrar: enfocada && !Paneles.esta("notificaciones", modelData)
        && Notificaciones.emergentes.length > 0 && !Ajustes.estiloDock

    readonly property bool pegada: Ajustes.minimalista || abajo
    readonly property bool abajo: Ajustes.abajo
    readonly property bool aLaDerecha: Ajustes.avisosLado !== "centro"
    readonly property int relleno: pegada ? 10 : 0

    // Al aparecer, el recuadro pegado baja desde la barra (o sube, abajo)
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
    // A la derecha o en el centro (Ajustes › Notificaciones)
    anchors { top: !abajo; bottom: abajo; right: aLaDerecha }
    // Bajo la barra (pegados a ella con la minimalista); con la barra a la
    // izquierda, arriba del todo; con la de abajo, encima de ella, tapando
    // su línea de arriba
    margins.top: Ajustes.minimalista ? Tema.altoBarra + 2 : Ajustes.vertical ? Tema.margenLados + 6 : Tema.hueco
    margins.bottom: Tema.altoTareas - 1
    margins.right: pegada ? 0 : Tema.margenLados
    implicitWidth: pegada ? 400 : 380
    implicitHeight: Math.max(1, pegada ? fondo.height : pila.height)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-avisos"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Solo se pueden pulsar las tarjetas (o su recuadro); el resto deja pasar los clics
    mask: Region { item: ventana.pegada ? fondo : pila }

    // Minimalista o Windows: el recuadro pegado a la barra
    Rectangle {
        id: fondo
        visible: ventana.pegada
        // Pegado al borde de la pantalla, su borde de ese lado queda fuera
        width: parent.width + (ventana.aLaDerecha ? border.width : 0)
        height: pila.height + 2 * ventana.relleno
        y: (ventana.abajo ? 1 : -1) * (1 - ventana.aparecer) * height
        color: Tema.panel
        // Todo recto, como la barra minimalista; con la de Windows, como sus
        // paneles: redonda solo la esquina de arriba hacia dentro
        radius: 0
        topLeftRadius: ventana.abajo && ventana.aLaDerecha ? Tema.radioPanel : 0
        border.width: Tema.borde(1)
        border.color: Tema.claro(0.08)
        Behavior on height { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

        // Sin borde del lado de la barra: se funde con ella
        Rectangle {
            visible: parent.border.width > 0
            x: parent.border.width
            y: ventana.abajo ? parent.height - height : 0
            width: parent.width - 2 * parent.border.width
            height: parent.border.width
            color: parent.color
        }
    }

    ListView {
        id: pila
        x: ventana.relleno
        y: ventana.pegada ? fondo.y + ventana.relleno : 0
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
            color: ventana.pegada ? (hover ? Tema.cajaHover : Tema.caja) : hover ? Tema.sombra(0.95) : Tema.panel
            border.color: urgente ? Tema.rojo : ventana.pegada ? Tema.claro(0.06) : Tema.panelBorde
            border.width: urgente ? 2 : ventana.pegada ? 1 : Tema.borde(2)
            radius: ventana.pegada ? 12 : Tema.radioPanel

            // Entra desde la derecha (aquí y no en «add» de la lista: si
            // llegan varias seguidas, esa animación se cortaba a medias)
            transform: Translate { id: desliz; x: 0 }
            ParallelAnimation {
                running: true
                NumberAnimation { target: desliz; property: "x"; from: ventana.pegada ? 0 : 60; to: 0; duration: Tema.normal; easing.type: Easing.OutCubic }
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
