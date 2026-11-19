// ============================================================================
//  Isla — recuadro translúcido de la barra que agrupa uno o varios módulos
//  Los módulos se ponen dentro y se colocan en fila (o en columna, con la
//  barra a la izquierda: Ajustes.vertical).
//  Si no hay nada visible dentro (u oculta: true), la isla se desvanece.
//  Con pulsable: true, la isla entera es un solo botón (avisa con clic(boton)
//  y rueda(pasos)); al pasar el ratón se iluminan sus módulos, como los demás
//  (resaltado: isla.hover), sin cambiar el fondo.
//  Con ayuda: "...", al dejar el ratón encima sale un recuadro con más
//  información (ver Ayuda.qml).
//  Con un panel colgando de ella (fusion: 0-1, al ritmo de su animación;
//  lo lleva Panel.qml con aportar()), sus esquinas de abajo se vuelven
//  rectas y toma el color del panel: los dos son una sola pieza.
//  Con «Paneles que salen de su isla», la isla SE CONVIERTE en el panel: su
//  fondo se ensancha hacia los lados hasta el ancho del panel (ensanchar(),
//  sin mover nada de la barra) y el panel crece pegado debajo; sus iconos
//  siguen arriba, a mano. Las islas que quedan debajo de ese fondo se
//  desvanecen mientras (Paneles.tapas).
// ============================================================================
import QtQuick
import Quickshell

Rectangle {
    id: isla

    default property alias contenido: fila.data
    property int relleno: 14            // margen a izquierda y derecha (arriba y abajo en vertical)
    property alias espacio: fila.spacing
    property bool oculta: false         // quitada en Ajustes
    readonly property bool vertical: Ajustes.vertical
    // Lo que ocupan los módulos visibles. No vale fila.implicitWidth: Grid
    // cuenta la separación de los ocultos (la batería en un PC, el Repeater...)
    // y dejaba más margen a un lado de la isla que al otro
    // Mientras la isla está oculta sus hijos también lo parecen (visible es
    // heredado) y salía 0: entonces vale la medida aproximada de Grid. (No se
    // mira isla.visible: depende de esto mismo y sería un bucle)
    readonly property real ocupado: {
        let fin = 0;
        for (const hijo of fila.children)
            if (hijo.visible)
                fin = Math.max(fin, vertical ? hijo.y + hijo.height : hijo.x + hijo.width);
        return fin > 0 ? Math.ceil(fin) : (vertical ? fila.implicitHeight : fila.implicitWidth);
    }
    property bool vacia: oculta || ocupado <= 0
    // Lo que ocuparía a lo largo de la barra aunque esté oculta (la barra lo
    // usa para ver si cabe sin chocar con las de al lado)
    readonly property int largoNatural: vertical ? ocupado + 2 * rellenoVertical
                                                 : ocupado + 2 * relleno
    // En vertical sobra tanto margen: los módulos ya llevan el suyo
    readonly property int rellenoVertical: Math.min(relleno, 6)
    property bool pulsable: false
    readonly property alias hover: raton.containsMouse
    property string ayuda: ""
    signal clic(int boton)
    signal rueda(int pasos)
    // Cada panel aporta su progreso; manda el mayor (al pasar de un panel a
    // otro de la misma isla, uno se cierra mientras el otro se abre)
    property var aportes: ({})
    property real fusion: 0
    function aportar(clave, cuanto) {
        aportes[clave] = cuanto;
        let mayor = 0;
        for (const k in aportes)
            mayor = Math.max(mayor, aportes[k]);
        fusion = mayor;
    }
    // Con «Paneles que salen de su isla» (Panel.qml): la isla se convierte
    // en su panel y deja su hueco vacío mientras está fuera (0 = aquí,
    // 1 = ida). Manda el panel que más se la lleve
    property var idas: ({})
    property real ida: 0
    function irse(clave, cuanto) {
        idas[clave] = cuanto;
        let mayor = 0;
        for (const k in idas)
            mayor = Math.max(mayor, idas[k]);
        ida = mayor;
    }
    // Lo que se ensancha el fondo a cada lado (manda el panel que más)
    property var ensanches: ({})
    property real extraIzq: 0
    property real extraDer: 0
    function ensanchar(clave, izq, der) {
        ensanches[clave] = [izq, der];
        let a = 0, b = 0;
        for (const k in ensanches) {
            a = Math.max(a, ensanches[k][0]);
            b = Math.max(b, ensanches[k][1]);
        }
        extraIzq = a;
        extraDer = b;
    }
    readonly property bool ensanchada: extraIzq + extraDer > 0.5
    // Encima de las de al lado mientras se ensancha
    z: ensanchada ? 5 : 0
    // Su ventana (para no desvanecerse por un panel de otra pantalla)
    readonly property var ventana: Window.window
    // Dónde está en su ventana (sumando los x de sus padres, como Panel.qml)
    readonly property real xVentana: {
        let x = 0;
        for (let p = isla; p; p = p.parent)
            x += p.x;
        return x;
    }
    // Tapada por el fondo ensanchado de otra isla: se desvanece al ritmo
    readonly property real tapada: {
        let t = 0;
        const tapas = Paneles.tapas;
        for (const k in tapas) {
            const e = tapas[k];
            if (e.isla === isla || e.ventana !== ventana)
                continue;
            if (xVentana < e.x1 && xVentana + width > e.x0)
                t = Math.max(t, e.f);
        }
        return t;
    }
    function mezcla(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // Al irse, primero sube entera y, ya fuera, deja su hueco (si encogía
    // mientras subía, parecía irse de lado); al volver, el hueco se abre a
    // la vez que baja
    // (valores sueltos, no enlazados a «vacia»: «visible» depende de ellos
    // y «vacia» de lo visible de dentro; enlazados, era un bucle)
    property bool plegada: false
    property bool recogida: true            // y su hueco ya cerrado
    Component.onCompleted: {
        plegada = vacia;
        recogida = vacia;
    }
    // (un instante después: cambiarlo dentro del propio aviso de «vacia»
    // volvía a tocar lo visible y, con ello, la misma «vacia»)
    onVaciaChanged: Qt.callLater(cambiarVacia)
    function cambiarVacia() {
        if (vacia) {
            if (!plegada && !plegar.running)
                plegar.restart();
        } else {
            plegar.stop();
            recoger.stop();
            plegada = false;
            recogida = false;
        }
    }
    Timer {
        id: plegar
        interval: Tema.rebote * 0.8
        onTriggered: {
            isla.plegada = isla.vacia;
            recoger.restart();
        }
    }
    Timer {
        id: recoger
        interval: Tema.rebote * 1.15
        onTriggered: isla.recogida = isla.vacia
    }
    implicitWidth: vertical ? Tema.anchoBarra : plegada ? 0 : ocupado + 2 * relleno
    implicitHeight: !vertical ? Tema.altoBarra : plegada ? 0 : ocupado + 2 * rellenoVertical
    radius: Tema.radioIsla
    // El fondo lo pinta «fondo» (abajo), que puede salirse por los lados
    color: "transparent"
    // (ensanchada, sin recortar: si no, no se vería el fondo de los lados)
    clip: !ensanchada && fusion === 0

    // Fundida con su panel: las esquinas de abajo, rectas; el color y el
    // borde, los del panel; y baja un poco más que la ventana de la barra,
    // que recorta su borde de abajo (la costura con el panel)
    Rectangle {
        id: fondo
        z: -1
        x: -isla.extraIzq
        width: isla.width + isla.extraIzq + isla.extraDer
        height: isla.height + Math.round(4 * isla.fusion)
        radius: isla.radius
        bottomLeftRadius: radius * (1 - isla.fusion)
        bottomRightRadius: radius * (1 - isla.fusion)
        // Con la minimalista, sin fondo: las islas van sobre su franja entera
        color: Ajustes.minimalista ? "transparent" : isla.mezcla(Tema.isla, Tema.panel, isla.fusion)
        border.width: Ajustes.minimalista ? 0 : isla.fusion > 0.5 ? Tema.borde(2) : Tema.borde(1)
        border.color: isla.mezcla(Tema.islaBorde, Tema.panelBorde, isla.fusion)
    }

    // Al irse, sube y se esconde por arriba de la pantalla (con la barra
    // abajo, por abajo; con la vertical, por el lado) mientras se funde; al
    // aparecer, baja desde ahí
    opacity: vacia ? 0 : (1 - ida) * (1 - tapada)
    // Tapada por el panel de otra isla no se ve: tampoco atiende al ratón
    // (si no, se pasaba de canción pulsando en el calendario sin verla).
    // «enabled» se hereda: apaga también los MouseArea de sus módulos
    enabled: tapada === 0
    // (sigue en la fila, ya invisible, hasta que su hueco se ha cerrado)
    visible: opacity > 0 || !recogida
    transform: Translate {
        readonly property real fuera: (isla.vertical ? Tema.anchoBarra : Tema.altoBarra) + Tema.margenBarra + 4
        x: isla.vertical && isla.vacia ? -fuera : 0
        y: !isla.vertical && isla.vacia ? (Ajustes.abajo ? fuera : -fuera) : 0
        Behavior on x { NumberAnimation { duration: Tema.rebote; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Tema.rebote; easing.type: Easing.OutCubic } }
    }
    // (mientras su panel se la lleva, sin retraso: va al ritmo del panel)
    Behavior on opacity { enabled: isla.ida === 0 && isla.tapada === 0; NumberAnimation { duration: Tema.normal * 1.4; easing.type: Easing.OutCubic } }
    // Al crecer o encoger (sale la música, una ficha...), se estira y frena
    // despacio, sin pasarse
    Behavior on implicitWidth { NumberAnimation { duration: Tema.rebote * 1.15; easing.type: Easing.OutQuint } }
    Behavior on implicitHeight { NumberAnimation { duration: Tema.rebote * 1.15; easing.type: Easing.OutQuint } }

    MouseArea {
        id: raton
        anchors.fill: parent
        enabled: isla.pulsable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => isla.clic(e.button)
        onWheel: e => {
            if (e.angleDelta.y !== 0)
                isla.rueda(e.angleDelta.y > 0 ? 1 : -1);
        }
    }

    // Ayuda: tras un momento con el ratón encima; se quita al abrir o cerrar
    // un panel (lo normal después de un clic)
    HoverHandler { id: sobre }
    Timer {
        id: retraso
        property bool mostrar: false
        interval: 600
        running: sobre.hovered && !mostrar
        onTriggered: mostrar = true
    }
    Connections {
        target: sobre
        function onHoveredChanged() {
            if (!sobre.hovered)
                retraso.mostrar = false;
        }
    }
    Connections {
        target: Paneles
        function onAbiertoChanged() {
            retraso.mostrar = false;
        }
    }
    Ayuda {
        objetivo: isla
        texto: isla.ayuda
        mostrar: retraso.mostrar && Paneles.abierto === "" && !Niri.overview
    }

    // Una fila (barra arriba) o una columna (barra a la izquierda)
    Grid {
        id: fila
        // Solo cambian las columnas: una (en columna) o de sobra (en fila).
        // Cambiar filas y columnas a la vez pasa un momento por 1×1 y Qt avisa
        columns: isla.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        x: isla.vertical ? Math.round((isla.width - width) / 2) : isla.relleno
        y: isla.vertical ? isla.rellenoVertical : Math.round((isla.height - height) / 2)
        spacing: 0
    }
}
