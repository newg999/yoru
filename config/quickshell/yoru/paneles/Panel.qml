// ============================================================================
//  Panel — recuadro que se despliega bajo la barra (como los de DMS)
//  Con la barra a la izquierda, sale a su derecha: «izquierda» arriba,
//  «centro» en medio y «derecha» abajo (donde quedan sus botones). Con la
//  barra de tareas (abajo), sube encima de ella.
//
//  La ventana ocupa la pantalla entera pero es invisible: así un clic fuera
//  del recuadro lo cierra.
//  Esc también lo cierra.
//
//    Panel {
//        nombre: "conexion"     // el que abre Paneles.alternar("conexion", ...)
//        lado: "derecha"        // "izquierda", "centro", "derecha"
//                               // o "medio" (en mitad de la pantalla)
//        MiContenido {}
//    }
//
//  Con las islas en píldoras, cuelga de la isla que lo abre (Paneles.islaDe):
//  la isla pierde sus esquinas de abajo, unas curvas unen los dos y el panel
//  baja desde ella como una persiana.
//  Con la barra de Windows (fundido), todos se pegan a ella, sin hueco ni
//  borde entre los dos, y suben desde ella como una persiana.
//
//  Con las islas, sale de la isla: nace de su ancho bajo ella y se
//  despliega hacia abajo y hacia los lados, fundido con ella. Si la página
//  nueva cuelga de otra isla, el panel se cierra y se abre desde ella
//  (Paneles.abrirPagina).
// ============================================================================
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    property string nombre: ""
    property string lado: "derecha"
    property int ancho: 420
    // {x, ancho}: justo debajo de una isla y de su ancho (Paneles.ancla)
    property var ancla: null
    property bool fundido: Ajustes.windows
    default property alias contenido: interior.data

    readonly property bool abierto: Paneles.abierto === nombre && Paneles.pantalla === modelData

    // La isla de la que cuelga (islas en píldoras). Se toma al abrirse (o al
    // cambiar de página) y se guarda al cerrarse, para volver a ella
    property Item isla: null
    // La isla se transforma al ritmo del panel (Isla.aportar)
    readonly property string clave: nombre + "@" + modelData.name
    function tomarIsla() {
        if (!abierto)
            return;
        const nueva = vertical || lado === "medio" ? null : Paneles.islaDe(modelData, nombre, Paneles.seccion);
        if (isla && isla !== nueva)
            isla.aportar(clave, 0);
        isla = nueva;
        // La nueva se funde ya (si el panel ya estaba abierto, el progreso
        // no cambia y no se enteraba: se quedaba con sus esquinas y suelta)
        isla?.aportar(clave, fusion());
    }
    onAbiertoChanged: {
        tomarIsla();
        // Y otra vez enseguida: la isla puede estar apareciendo justo ahora
        // (la campana sin avisos nuevos) y aún no contar como visible
        Qt.callLater(tomarIsla);
        if (abierto && Tema.normal > 0)
            animSubida.restart();
    }
    // La isla pierde sus esquinas de abajo enseguida al abrirse y no las
    // recupera hasta que el panel casi se ha ido (al ritmo del panel
    // asomaba el fondo entre los dos en la esquina)
    function fusion() {
        return Math.min(1, progreso * 4) * cerca;
    }
    // Al pasar de una isla a otra, el panel se desliza hasta ella: la isla
    // nueva se funde (y salen las curvas) según llega, no antes (si no,
    // la isla se quedaba sin esquinas y las curvas sueltas a medio camino)
    readonly property real cerca: {
        const lejos = Math.abs(islaX - islaXReal) + Math.abs(islaAncho - islaAnchoReal) / 2;
        return lejos < 1.5 ? 1 : 1 - Math.min(1, lejos / 40);
    }
    onCercaChanged: isla?.aportar(clave, fusion())
    onProgresoChanged: isla?.aportar(clave, fusion())
    Connections {
        target: Paneles
        function onSeccionChanged() {
            if (ventana.abierto)
                ventana.tomarIsla();
        }
    }
    Component.onDestruction: isla?.aportar(clave, 0)
    // Dónde está (en la pantalla) y qué ancho tiene
    readonly property real islaXReal: {
        const it = isla;
        if (!it)
            return 0;
        // Se suma el x de todos sus padres: así se entera aunque se mueva un
        // padre (la isla de la hora va centrada y se corre cuando otra cambia
        // de ancho). Y a mano, no con mapToItem: ese cuenta la escala y, con
        // la isla encogida por el clic, el panel se quedaba un poco corrido
        // y nunca terminaba de fundirse con ella
        let x = 0;
        for (let p = it; p; p = p.parent)
            x += p.x;
        return x;
    }
    readonly property real islaAnchoReal: isla?.width ?? 0
    // Lo mismo, pero si el panel ya abierto pasa a otra isla (de la hora al
    // centro de control, p. ej.) se desliza hasta ella en vez de saltar
    readonly property bool asentado: abierto && progreso >= 1
    property real islaX: islaXReal
    property real islaAncho: islaAnchoReal
    Behavior on islaX {
        enabled: ventana.asentado
        NumberAnimation { duration: Tema.normal > 0 ? 460 : 0; easing.type: Easing.OutQuint }
    }
    Behavior on islaAncho {
        enabled: ventana.asentado
        NumberAnimation { duration: Tema.normal > 0 ? 460 : 0; easing.type: Easing.OutQuint }
    }
    readonly property int bajoIslas: Tema.margenBarra + Tema.altoBarra
    readonly property bool vertical: Ajustes.vertical
    readonly property bool abajo: Ajustes.abajo

    // Alto máximo del recuadro en ESTA pantalla (bajo la barra, con margen).
    // Los paneles con listas largas las acortan con esto para caber también
    // en monitores pequeños (1080p, portátiles de 768...)
    readonly property int altoMax: modelData.height - (vertical ? 2 * Tema.margenLados + 12 : Tema.hueco) - 12

    // 0 = cerrado · 1 = abierto. La ventana sigue visible hasta que termina
    // la animación de cierre.
    // Al abrirse, con rebote (como el dock): se pasa un poco de 1 y vuelve,
    // así crece de más y se asienta (colgando de una isla, se ensancha de
    // más). Pegado a la minimalista, sin rebote: baja como una persiana.
    // Al cerrarse, rápido y sin rebote
    property real progreso: abierto ? 1 : 0
    Behavior on progreso {
        NumberAnimation {
            duration: Tema.normal === 0 ? 0 : !ventana.abierto ? 170 : caja.pegado ? 300 : 380
            easing.type: !ventana.abierto ? Easing.InCubic : caja.pegado ? Easing.OutQuint : Easing.OutBack
            easing.overshoot: 1.4
        }
    }
    // El progreso sin pasarse de 1: para lo que no debe rebotar (el sitio
    // bajo la barra o la isla y la transparencia)
    readonly property real hasta1: Math.min(1, progreso)

    // Al abrirse, el contenido baja desde un poco más arriba (1 → 0) tras
    // un momento, mientras la caja se despliega de arriba abajo
    property real subida: 0
    SequentialAnimation {
        id: animSubida
        PropertyAction { target: ventana; property: "subida"; value: 1 }
        PauseAnimation { duration: 80 }
        NumberAnimation { target: ventana; property: "subida"; to: 0; duration: 560; easing.type: Easing.OutQuart }
    }

    screen: modelData
    visible: abierto || progreso > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-panel"
    WlrLayershell.layer: WlrLayer.Top
    // Teclado para Esc y para escribir contraseñas
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Sin desenfoque detrás del recuadro (las islas de la barra sí lo
    // tienen): el de niri no se puede desvanecer, y al ponerse al final de
    // la animación el panel cambiaba de golpe de tono (parecía un parpadeo).

    // Clic fuera = cerrar. Menos en la franja de la barra: ahí los clics
    // pasan a la barra, así que pulsar otro botón con un panel abierto lo
    // abre a la primera (antes el primer clic solo cerraba este)
    mask: Region {
        item: entera
        Region { item: franjaBarra; intersection: Intersection.Subtract }
    }
    Item { id: entera; anchors.fill: parent }
    Item {
        id: franjaBarra
        width: ventana.vertical ? Tema.margenBarra + Tema.anchoBarra : parent.width
        y: ventana.abajo ? parent.height - height : 0
        height: ventana.vertical ? parent.height
            : ventana.abajo ? Tema.altoTareas
            : Ajustes.minimalista ? Tema.altoBarra + 2 : Tema.margenBarra + Tema.altoBarra
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Paneles.cerrar()
    }

    // Con la minimalista, el panel baja desde la barra como una persiana: se
    // recorta justo por debajo de ella para no pintarse encima mientras baja.
    // Fundido con la de abajo, igual pero subiendo (y tapando su línea de arriba)
    Item {
        id: recorte
        anchors.fill: parent
        anchors.topMargin: Ajustes.minimalista ? Tema.altoBarra + 2 : caja.colgado ? ventana.bajoIslas : 0
        anchors.bottomMargin: ventana.fundido ? Tema.altoTareas - 1 : 0
        clip: Ajustes.minimalista || ventana.fundido || caja.colgado

        Rectangle {
            id: caja

            readonly property bool anclado: ventana.ancla !== null && !ventana.vertical
            // Colgando de una isla: debajo de ella y al menos de su ancho
            readonly property bool colgado: ventana.isla !== null && !enMedio
            // Colgando, nace del ancho de la isla y se ensancha hasta el suyo
            readonly property real anchoFinal: colgado ? Math.max(anclado ? ventana.ancla.ancho : ventana.ancho, ventana.islaAncho)
                : anclado ? ventana.ancla.ancho : ventana.ancho
            readonly property real xFinal: Math.round(Math.max(Tema.margenLados, Math.min(parent.width - anchoFinal - Tema.margenLados,
                ventana.islaX + (ventana.islaAncho - anchoFinal) / 2)))
            width: colgado ? ventana.islaAncho + (anchoFinal - ventana.islaAncho) * ventana.progreso : anchoFinal
            // Lo que sobresale a cada lado de la isla (ahí van las curvas)
            readonly property real sobraIzquierda: colgado ? ventana.islaX - x : 0
            readonly property real sobraDerecha: colgado ? x + width - ventana.islaX - ventana.islaAncho : 0
            // Con las islas, como los paneles del dock: nace sin alto bajo la
            // isla (o la barra) y se estira con rebote (progreso pasa de 1)
            readonly property real altoFinal: interior.implicitHeight + 32
            height: comoDock ? Math.max(0, altoFinal * ventana.progreso) : altoFinal
            // (la minimalista también: pegado a su franja, se despliega igual)
            readonly property bool comoDock: colgado || (Ajustes.conPildoras && (!pegado || Ajustes.minimalista) && !enMedio && !ventana.vertical && !ventana.abajo)
            readonly property bool enMedio: ventana.lado === "medio"
            // Con la barra minimalista, pegado a ella: sin hueco, esquinas
            // rectas, su mismo fondo y un borde fino
            readonly property bool pegado: (Ajustes.minimalista || ventana.fundido) && !enMedio
            readonly property bool fundido: ventana.fundido && !enMedio
            readonly property string sitio: ventana.lado

            // Al abrirse se desliza un poco desde la barra (abajo: hacia arriba)
            readonly property real deslizar: (1 - ventana.hasta1) * 14

            x: enMedio ? Math.round((parent.width - width) / 2)
                // Centrado bajo la isla, sin salirse de la pantalla
                : colgado ? ventana.islaX + (xFinal - ventana.islaX) * ventana.progreso
                : anclado ? ventana.ancla.x
                : ventana.vertical ? Tema.hueco - deslizar
                // Pegado al borde de la pantalla, su borde de ese lado queda
                // fuera (si no, se veía una línea fina contra el borde)
                : sitio === "izquierda" ? (pegado ? -border.width : Tema.margenLados)
                : sitio === "centro" ? (parent.width - width) / 2
                : parent.width - width - (pegado ? -border.width : Tema.margenLados)
            // (en el recorte, que con la minimalista empieza bajo la barra)
            y: enMedio ? Math.round((ventana.height - height) / 2) - recorte.y
                : fundido ? parent.height - ventana.hasta1 * height
                : colgado ? 0
                : comoDock ? (pegado ? 0 : Tema.hueco)
                : pegado ? -(1 - ventana.hasta1) * height
                : ventana.abajo ? parent.height - height - Tema.hueco + deslizar
                : !ventana.vertical ? Tema.hueco - deslizar
                : sitio === "izquierda" ? Tema.margenLados + 6
                : sitio === "centro" ? Math.round((parent.height - height) / 2)
                : parent.height - height - Tema.margenLados - 6

            // Pegado a la barra baja como una persiana (ver «recorte»), sin
            // fundido ni encoger (se despegaría de ella)
            // (con las islas, al cerrarse se funde en el último tramo: si no,
            // quedaba una franja oscura bajo la isla en los últimos fotogramas)
            opacity: comoDock ? (ventana.abierto ? 1 : Math.min(1, ventana.progreso * 2.5))
                : pegado ? 1 : ventana.hasta1
            scale: pegado || comoDock ? 1 : (enMedio ? 0.94 : 0.96) + (enMedio ? 0.06 : 0.04) * ventana.progreso
            transformOrigin: enMedio ? Item.Center : ventana.vertical ? Item.Left : ventana.abajo ? Item.Bottom : Item.Top

            radius: Tema.radioPanel
            // Pegado a la barra minimalista: todo recto, como ella
            // (fundido con la de abajo: redondo arriba, recto contra ella y
            // contra el borde de la pantalla)
            // (colgado de una isla: recto donde sigue su borde)
            topLeftRadius: colgado ? Math.min(radius, Math.max(0, sobraIzquierda / 2))
                : pegado && (!fundido || sitio === "izquierda") ? 0 : radius
            topRightRadius: colgado ? Math.min(radius, Math.max(0, sobraDerecha / 2))
                : pegado && (!fundido || sitio === "derecha") ? 0 : radius
            bottomLeftRadius: pegado ? 0 : radius
            bottomRightRadius: pegado ? 0 : radius
            color: Tema.panel
            border.width: colgado ? 0 : pegado ? Tema.borde(1) : Tema.borde(2)
            border.color: pegado ? Tema.claro(0.08) : Tema.panelBorde
            clip: true

            // Como el dock: un brillo suave del acento arriba (colgando de
            // una isla, no: se notaba la costura con ella y con las curvas)
            Rectangle {
                visible: caja.comoDock && !caja.colgado && !caja.pegado
                anchors.fill: parent
                topLeftRadius: caja.topLeftRadius
                topRightRadius: caja.topRightRadius
                bottomLeftRadius: caja.bottomLeftRadius
                bottomRightRadius: caja.bottomRightRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Tema.claro(0.10) }
                    GradientStop { position: Math.min(1, 140 / Math.max(1, caja.altoFinal)); color: "transparent" }
                }
            }

            // Pegado: sin borde del lado de la barra (se funde con ella)
            Rectangle {
                visible: caja.pegado && caja.border.width > 0
                x: caja.border.width
                y: caja.fundido ? parent.height - height : 0
                width: parent.width - 2 * caja.border.width
                height: caja.border.width
                color: caja.color
                z: 1
            }

            // Solo con el panel ya abierto (al cambiar de sección o página): al
            // abrirse toma su tamaño directamente, sin arrastrar el de la última vez
            Behavior on height {
                enabled: ventana.abierto && ventana.progreso === 1 && !animSubida.running
                NumberAnimation { duration: Tema.rebote * 0.75; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            }

            // Los clics dentro del recuadro no lo cierran
            MouseArea {
                anchors.fill: parent
            }

            FocusScope {
                id: foco
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Paneles.cerrar()

                // Colgando, el contenido no se mueve ni se recoloca mientras el
                // recuadro se ensancha: está ya en su sitio y aparece con un fundido
                Item {
                    id: interior
                    x: 16 + (caja.colgado ? caja.xFinal - caja.x : 0)
                    y: 16
                    width: caja.anchoFinal - 32
                    implicitHeight: childrenRect.height
                    // El contenido llega mientras la caja se despliega hacia
                    // abajo: se funde y baja un poco desde arriba (ventana.subida)
                    // (la opacidad no depende de «subida»: al cambiar en cada
                    // fotograma reiniciaba el fundido y el contenido no llegaba
                    // hasta que la caja se paraba)
                    readonly property bool mostrar: ventana.abierto && ventana.progreso > 0.2
                    opacity: !caja.comoDock || mostrar ? 1 : 0
                    Behavior on opacity {
                        enabled: caja.comoDock
                        NumberAnimation { duration: interior.mostrar ? 360 : 90; easing.type: Easing.OutCubic }
                    }
                    transform: Translate {
                        y: caja.comoDock ? -ventana.subida * 14 : 0
                    }
                }
            }
        }
    }

    // Las curvas que unen la isla con el panel, a cada lado de la isla donde
    // el panel sobresale (crecen con él al abrirse)
    component Curva: Shape {
        property bool derecha: false
        property real r: 0
        visible: caja.colgado && r > 0.5
        // Se funden con la caja al cerrarse (si no, quedaban las esquinas)
        opacity: caja.opacity
        y: ventana.bajoIslas - r
        width: r
        height: r
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: caja.color
            strokeWidth: -1
            // La esquina de abajo pegada a la isla, hacia fuera un cuarto de círculo
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
    // (al llegar de otra isla, solo cuando el panel ya está bajo ella)
    readonly property real crece: cerca
    Curva {
        r: Math.min(12, Math.max(0, caja.sobraIzquierda / 2)) * ventana.crece
        x: ventana.islaX - r
    }
    Curva {
        derecha: true
        r: Math.min(12, Math.max(0, caja.sobraDerecha / 2)) * ventana.crece
        x: ventana.islaX + ventana.islaAncho
    }
}
