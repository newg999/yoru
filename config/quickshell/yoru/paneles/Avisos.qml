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
//  Con la barra de islas, cuelgan de la campana fundidas con ella, como sus
//  paneles: un recuadro bajo la isla (que pierde sus esquinas de abajo y
//  toma su color), con las curvas que los unen, que baja desde ella y
//  vuelve a subir a ella al irse la última.
//
//  Con la barra minimalista, dentro de un recuadro pegado a ella (mismo
//  fondo, esquinas rectas, hasta el borde de la pantalla) que baja como una
//  persiana, como sus paneles. Con la de Windows, igual pero abajo a la
//  derecha, subiendo desde ella.
// ============================================================================
import QtQuick
import QtQuick.Shapes
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

    readonly property bool pegada: Ajustes.minimalista || abajo
    readonly property bool abajo: Ajustes.abajo
    readonly property bool aLaDerecha: Ajustes.avisosLado !== "centro"
    readonly property int relleno: pegada || colgada ? 10 : 0

    // ----------------------------------------------- Colgando de la campana
    readonly property Item campana: Ajustes.pildoras && aLaDerecha && !pegada && !Ajustes.vertical
        ? (Paneles.islas[modelData.name]?.notificaciones ?? null) : null
    // Su sitio en la pantalla (sumando los x de sus padres: así se entera si
    // se mueve, y no cuenta la escala de cuando se pulsa)
    readonly property real campanaX: {
        const it = campana;
        if (!it)
            return 0;
        let x = 0;
        for (let p = it; p; p = p.parent)
            x += p.x;
        return x;
    }
    readonly property real campanaAncho: campana?.width ?? 0
    readonly property bool colgada: campana !== null && campana.visible && campanaAncho > 0
    // Lo que sube la ventana por encima del recuadro: ahí van las curvas
    // (ya no hay curvas: es el hueco entre la campana y el recuadro)
    readonly property int curvas: colgada ? 6 : 0
    // Dónde queda la campana dentro de la ventana
    readonly property real campanaDentro: campanaX - (modelData.width - margins.right - implicitWidth)

    // La campana se funde con el recuadro mientras está
    readonly property string clave: "avisos@" + modelData.name
    // (ya no: van sueltos bajo ella, con su hueco y sus esquinas)
    onAparecerChanged: campana?.aportar(clave, 0)
    onColgadaChanged: if (!colgada && campana) campana.aportar(clave, 0)
    Component.onDestruction: campana?.aportar(clave, 0)

    // Al aparecer, el recuadro baja desde la barra (o sube, abajo); colgando
    // de la campana, también vuelve a subir a ella al irse la última
    property real aparecer: 0
    onMostrarChanged: {
        if (mostrar) {
            if (!colgada || aparecer === 0)
                aparecer = 0;
            irse.stop();
            bajar.restart();
        } else if (colgada) {
            bajar.stop();
            irse.restart();
        } else
            aparecer = 0;
    }
    NumberAnimation {
        id: bajar
        target: ventana
        property: "aparecer"
        to: 1
        duration: ventana.colgada ? Tema.normal * 1.6 : Tema.normal
        easing.type: ventana.colgada ? Easing.OutQuint : Easing.OutCubic
    }
    NumberAnimation {
        id: irse
        target: ventana
        property: "aparecer"
        to: 0
        duration: Tema.normal * 1.2
        easing.type: Easing.InOutCubic
    }
    // El alto del recuadro: el de las tarjetas (al irse la última se queda
    // con el que tenía, para encogerse desde ahí)
    property real alto: 0
    readonly property real altoPila: pila.height + 2 * relleno
    onAltoPilaChanged: if (pila.height > 0) alto = altoPila

    visible: mostrar || (colgada && aparecer > 0)
    // A la derecha o en el centro (Ajustes › Notificaciones)
    anchors { top: !abajo; bottom: abajo; right: aLaDerecha }
    // Bajo la barra (pegados a ella con la minimalista o a la campana); con
    // la barra a la izquierda, arriba del todo; con la de abajo, encima de
    // ella, tapando su línea de arriba
    margins.top: colgada ? Tema.margenBarra + Tema.altoBarra - curvas
        : Ajustes.minimalista ? Tema.altoBarra + 2 : Ajustes.vertical ? Tema.margenLados + 6 : Tema.hueco
    margins.bottom: Tema.altoTareas - 1
    // Colgando: centrado bajo la campana, sin salirse de la pantalla
    margins.right: pegada ? 0
        : colgada ? Math.round(Math.max(Tema.margenLados, modelData.width - (campanaX + campanaAncho / 2) - implicitWidth / 2))
        : Tema.margenLados
    implicitWidth: pegada ? 400 : 380
    implicitHeight: Math.max(1, colgada ? curvas + alto : pegada ? fondo.height : pila.height)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-avisos"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Solo se pueden pulsar las tarjetas (o su recuadro); el resto deja pasar los clics
    mask: Region { item: ventana.pegada || ventana.colgada ? fondo : pila }

    // El recuadro: pegado a la barra (minimalista o Windows) o colgando de
    // la campana. Sueltas (otras barras), sin recuadro
    Rectangle {
        id: fondo
        readonly property bool hay: ventana.pegada || ventana.colgada
        // Pegado al borde de la pantalla, su borde de ese lado queda fuera
        width: parent.width + (ventana.pegada && ventana.aLaDerecha ? border.width : 0)
        height: ventana.colgada ? ventana.alto * ventana.aparecer : hay ? pila.height + 2 * ventana.relleno : pila.height
        y: ventana.colgada ? ventana.curvas : hay ? (ventana.abajo ? 1 : -1) * (1 - ventana.aparecer) * height : 0
        color: hay ? Tema.panel : "transparent"
        clip: ventana.colgada
        // Pegado: todo recto, como la barra minimalista; con la de Windows,
        // como sus paneles: redonda solo la esquina de arriba hacia dentro.
        // Colgando: redondo (la campana es estrecha: sus esquinas de arriba
        // quedan lejos de ella), menos si la campana llega a una esquina
        radius: ventana.colgada ? Tema.radioPanel : 0
        topLeftRadius: ventana.colgada ? Tema.radioPanel
            : ventana.abajo && ventana.aLaDerecha ? Tema.radioPanel : 0
        topRightRadius: ventana.colgada ? Tema.radioPanel : 0
        border.width: ventana.pegada ? Tema.borde(1) : ventana.colgada ? Tema.borde(2) : 0
        border.color: ventana.colgada ? Tema.panelBorde : Tema.claro(0.08)
        Behavior on height {
            enabled: !ventana.colgada
            NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
        }

        // Sin borde del lado de la barra: se funde con ella
        Rectangle {
            visible: ventana.pegada && parent.border.width > 0
            x: parent.border.width
            y: ventana.abajo ? parent.height - height : 0
            width: parent.width - 2 * parent.border.width
            height: parent.border.width
            color: parent.color
        }

        ListView {
            id: pila
            x: ventana.relleno
            y: fondo.hay ? ventana.relleno : 0
            width: ventana.width - 2 * ventana.relleno
            height: Math.min(contentHeight, ventana.modelData.height * 0.7)
            spacing: 8
            interactive: false
            clip: true
            // Colgando: lo de dentro asoma cuando el recuadro ya ha bajado
            opacity: ventana.colgada ? Math.max(0, Math.min(1, (ventana.aparecer - 0.35) / 0.5)) : 1

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
                // Sueltas, con el fondo y el borde de un panel; dentro de un
                // recuadro, como las del centro de control
                color: fondo.hay ? (hover ? Tema.cajaHover : Tema.caja) : hover ? Tema.sombra(0.95) : Tema.panel
                border.color: urgente ? Tema.rojo : fondo.hay ? Tema.claro(0.06) : Tema.panelBorde
                border.width: urgente ? 2 : fondo.hay ? 1 : Tema.borde(2)
                radius: fondo.hay ? 12 : Tema.radioPanel

                // Entra desde la derecha; en un recuadro, se funde y baja un
                // poco (aquí y no en «add» de la lista: si llegan varias
                // seguidas, esa animación se cortaba a medias)
                // (de dónde sale se fija al nacer: si cambiaba a medias, la
                // animación se quedaba corrida para siempre)
                transform: Translate { id: desliz }
                Component.onCompleted: {
                    desliz.x = fondo.hay ? 0 : 60;
                    desliz.y = ventana.colgada ? -10 : 0;
                    llega.start();
                }
                ParallelAnimation {
                    id: llega
                    NumberAnimation { target: desliz; properties: "x,y"; to: 0; duration: Tema.normal; easing.type: Easing.OutCubic }
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

    // Las curvas que unen la campana con el recuadro, a cada lado de ella
    // (crecen con él al bajar)
    component Curva: Shape {
        property bool derecha: false
        property real r: 0
        visible: false      // (ya no se funden con la campana)
        y: ventana.curvas - r
        width: r
        height: r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: fondo.color
            strokeWidth: -1
            startX: derecha ? 0 : r; startY: 0
            PathLine { x: derecha ? 0 : r; y: r }
            PathLine { x: derecha ? r : 0; y: r }
            PathArc {
                x: derecha ? 0 : r; y: 0
                radiusX: r; radiusY: r
                direction: derecha ? PathArc.Clockwise : PathArc.Counterclockwise
            }
        }
    }
    readonly property real crece: Math.max(0, Math.min(1, aparecer * 2.5))
    Curva {
        r: Math.min(12, Math.max(0, ventana.campanaDentro / 2)) * ventana.crece
        x: ventana.campanaDentro - r
    }
    Curva {
        derecha: true
        r: Math.min(12, Math.max(0, (ventana.implicitWidth - ventana.campanaDentro - ventana.campanaAncho) / 2)) * ventana.crece
        x: ventana.campanaDentro + ventana.campanaAncho
    }
}
