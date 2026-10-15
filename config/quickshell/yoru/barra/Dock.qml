// ============================================================================
//  Dock — barra de apps abajo, como la del Mac, con la estética de Yoru
//
//    [favoritas] │ [abiertas que no están fijadas]
//
//    Clic           = ir a su ventana · si tiene varias, una lista para elegir
//                     a cuál · si no está abierta, la abre
//    Clic central   = ventana nueva
//    Clic derecho   = menú: sus ventanas, fijar / quitar, ventana nueva,
//                     cerrar todas
//
//  Los puntitos de debajo son sus ventanas abiertas; el alargado, la app
//  que tiene el foco. Cuándo sale se elige en Ajustes (Barra y dock):
//    · con el overview (Mod+Tab), como en GNOME: no reserva espacio y al
//      elegir una app el overview se cierra (lo normal)
//    · siempre, pegado abajo y reservando su espacio
//    · nunca
//  Las favoritas se guardan en comun/Favoritos.qml.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.comun

PanelWindow {
    id: dock
    required property ShellScreen modelData
    screen: modelData

    // Medidas
    readonly property int celda: 40          // hueco de cada app
    readonly property int icono: 28
    readonly property int alto: 44           // alto de la isla
    readonly property bool siempre: Ajustes.dock === "siempre"
    readonly property bool mostrado: siempre || (Ajustes.dock === "overview" && Niri.overview)
    readonly property int margen: siempre ? Tema.margenBarra : 12   // hasta el borde de abajo

    // La ventana mide justo lo que la isla (centrada abajo). El nombre y el
    // menú salen en ventanitas aparte que solo existen mientras se ven.
    // (Antes era una franja transparente de 2560×260 y niri tenía que
    // mezclarla en cada fotograma: con un vídeo, la gráfica iba al 40 %)
    anchors.bottom: true
    margins.bottom: margen
    implicitWidth: isla.width
    implicitHeight: alto
    visible: Ajustes.dock !== "nunca"
    exclusionMode: siempre ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: siempre ? alto + margen : 0
    color: "transparent"
    WlrLayershell.namespace: "yoru-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Escondido: sin zona de clic, para que los clics lleguen a las ventanas
    mask: mostrado ? null : vacia
    Region { id: vacia }
    Connections {
        target: Niri
        function onOverviewChanged() {
            if (!Niri.overview)
                menu.cerrar();
        }
    }

    // ------------------------------------------------------------ Datos
    // Una entrada por app: las favoritas primero (en su orden) y luego las
    // abiertas que no lo son, en el orden en que se abrieron
    readonly property var apps: {
        DesktopEntries.applications.values;   // recalcular cuando carguen las apps
        const grupos = new Map();
        for (const id of Favoritos.ids) {
            const entrada = DesktopEntries.byId(id);
            if (entrada)
                grupos.set(id, {clave: id, entrada, appId: id, fija: true, ventanas: []});
        }
        const ventanas = Object.values(Niri.ventanas).sort((a, b) => a.id - b.id);
        for (const v of ventanas) {
            const entrada = DesktopEntries.heuristicLookup(v.app_id);
            const clave = entrada?.id ?? v.app_id;
            if (!grupos.has(clave))
                grupos.set(clave, {clave, entrada, appId: v.app_id, fija: false, ventanas: []});
            grupos.get(clave).ventanas.push(v);
        }
        return [...grupos.values()];
    }
    readonly property int fijas: apps.filter(a => a.fija).length

    function nombre(app) {
        return app.entrada?.name ?? app.appId;
    }

    // Dónde está una ventana: «Escritorio 2» (y la pantalla, si hay varias)
    function lugar(v) {
        const e = Niri.escritorios.find(e => e.id === v.workspace_id);
        if (!e)
            return "";
        return "Escritorio " + e.idx + (Quickshell.screens.length > 1 ? " · " + e.output : "");
    }

    function lanzar(app) {
        const e = app.entrada;
        if (!e)
            return;
        // Como el lanzador: lo abre niri (sobrevive a reiniciar la barra)
        const orden = e.runInTerminal ? ["kitty", "--", ...e.command] : e.command;
        Niri.lanzar(e.workingDirectory
            ? ["sh", "-c", 'cd "$1" && shift && exec "$@"', "_", e.workingDirectory, ...orden]
            : orden);
        Niri.accion("close-overview");
    }

    // Ir a una ventana. Primero el foco y luego cerrar el overview: así se
    // acerca a esa ventana
    function irA(v) {
        Quickshell.execDetached(["sh", "-c",
            `niri msg action focus-window --id ${v.id} && niri msg action close-overview`]);
    }

    // Clic: sin ventanas la abre, con una va a ella y con varias deja elegir
    function pulsar(app, item) {
        if (app.ventanas.length === 0)
            lanzar(app);
        else if (app.ventanas.length === 1)
            irA(app.ventanas[0]);
        else if (menu.app?.clave === app.clave && menu.soloVentanas)
            menu.cerrar();
        else
            menu.abrir(app, item, true);
    }

    function cerrarTodas(app) {
        for (const v of app.ventanas)
            Niri.accion("close-window", "--id", String(v.id));
    }

    // ------------------------------------------------------------- Isla
    Rectangle {
        id: isla
        width: fila.implicitWidth + 12
        height: dock.alto
        radius: Tema.radio + 2
        color: Tema.isla
        border.width: 1
        border.color: Tema.islaBorde
        visible: dock.apps.length > 0

        // Sube desde abajo al abrir el overview, como la barra baja desde arriba
        opacity: dock.mostrado ? 1 : 0
        transform: Translate {
            y: dock.mostrado ? 0 : dock.alto + dock.margen
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }

        Row {
            id: fila
            anchors.centerIn: parent

            Repeater {
                model: dock.apps

                Row {
                    id: hueco
                    required property var modelData
                    required property int index
                    readonly property var app: modelData
                    readonly property bool enfocada: app.ventanas.some(v => v.id === Niri.enfocada?.id)

                    // Rayita entre las favoritas y las demás
                    Rectangle {
                        visible: hueco.index === dock.fijas && dock.fijas > 0
                        width: 1
                        height: dock.icono - 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tema.claro(0.15)
                    }
                    Item { visible: hueco.index === dock.fijas && dock.fijas > 0; width: 6; height: 1 }

                    Item {
                        id: elemento
                        width: dock.celda
                        height: dock.alto

                        // Brillo al pasar el ratón
                        Rectangle {
                            anchors.centerIn: imagen
                            width: dock.icono + 8; height: width
                            radius: 9
                            color: Tema.blanco
                            opacity: raton.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                        }

                        IconImage {
                            id: imagen
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                            implicitSize: dock.icono
                            source: Quickshell.iconPath(hueco.app.entrada?.icon ?? hueco.app.appId, true)
                                || Quickshell.iconPath("application-x-executable")
                            asynchronous: true
                            // Crece un poco hacia arriba al pasar el ratón
                            transformOrigin: Item.Bottom
                            scale: raton.pressed ? 1.05 : raton.containsMouse ? 1.16 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                        }

                        // Ventanas abiertas: hasta 3 puntitos; el de la app con el
                        // foco es alargado, como el escritorio activo de la barra
                        Row {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
                            spacing: 3
                            Repeater {
                                model: Math.min(3, hueco.app.ventanas.length)
                                Rectangle {
                                    required property int index
                                    height: 3
                                    width: hueco.enfocada && index === 0 ? 10 : 3
                                    radius: 1.5
                                    color: hueco.enfocada ? Tema.blanco : Tema.claro(0.55)
                                    Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                                }
                            }
                        }

                        MouseArea {
                            id: raton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: e => {
                                if (e.button === Qt.RightButton) {
                                    menu.abrir(hueco.app, elemento, false);
                                } else if (e.button === Qt.MiddleButton) {
                                    menu.cerrar();
                                    dock.lanzar(hueco.app);
                                } else {
                                    dock.pulsar(hueco.app, elemento);
                                }
                            }
                        }

                        // Nombre encima del icono (tras un momento con el ratón)
                        Timer {
                            id: retraso
                            interval: 450
                            running: raton.containsMouse && !menu.abierto
                        }
                        LazyLoader {
                            active: raton.containsMouse && !retraso.running && !menu.abierto
                            PopupWindow {
                                anchor.item: elemento
                                anchor.rect.y: -8
                                anchor.rect.width: elemento.width
                                anchor.rect.height: 1
                                anchor.edges: Edges.Top
                                anchor.gravity: Edges.Top
                                implicitWidth: etiqueta.implicitWidth + 24
                                implicitHeight: etiqueta.implicitHeight + 14
                                color: "transparent"
                                visible: true
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: Tema.panel
                                    border.width: 1
                                    border.color: Tema.claro(0.25)
                                    Texto {
                                        id: etiqueta
                                        anchors.centerIn: parent
                                        text: dock.nombre(hueco.app)
                                            + (hueco.app.ventanas.length > 1 ? Tema.suave("  ×" + hueco.app.ventanas.length) : "")
                                        textFormat: Text.StyledText
                                        font.bold: false
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------- Menú (clic y clic derecho)
    // Con clic (app con varias ventanas) solo la lista de ventanas; con clic
    // derecho, la lista y las opciones. Se cierra al sacar el ratón de él un
    // momento o al elegir algo.
    QtObject {
        id: menu
        property string clave: ""
        property bool soloVentanas: false
        property Item sobre: null
        // Se busca en «apps» cada vez para que la lista siga al día si se abre
        // o se cierra una ventana con el menú abierto (y se cierre si la app
        // desaparece del dock)
        readonly property var app: clave !== "" ? (dock.apps.find(a => a.clave === clave) ?? null) : null
        readonly property bool abierto: app !== null

        function abrir(a, item, solo) {
            sobre = item;
            soloVentanas = solo;
            clave = a.clave;
        }
        function cerrar() {
            clave = "";
        }
    }

    LazyLoader {
        active: menu.abierto && menu.sobre !== null

        PopupWindow {
            anchor.item: menu.sobre
            anchor.rect.y: -8
            anchor.rect.width: menu.sobre?.width ?? 0
            anchor.rect.height: 1
            anchor.edges: Edges.Top
            anchor.gravity: Edges.Top
            implicitWidth: (menu.app?.ventanas.length ?? 0) > 1 ? 300 : 230
            implicitHeight: opciones.implicitHeight + 12
            color: "transparent"
            visible: true

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Tema.panel
                border.width: 1
                border.color: Tema.claro(0.25)

                HoverHandler { id: dentro }
                Timer {
                    // Margen al abrir: el ratón aún está en el icono, no en el menú
                    interval: 900
                    running: !dentro.hovered
                    onTriggered: menu.cerrar()
                }

                Column {
                    id: opciones
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                    spacing: 2

                    Texto {
                        width: parent.width
                        leftPadding: 10
                        height: 28
                        text: menu.app ? dock.nombre(menu.app) : ""
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: Tema.gris
                    }

                    // Sus ventanas (si tiene más de una): título y escritorio
                    Repeater {
                        model: (menu.app?.ventanas.length ?? 0) > 1 ? menu.app.ventanas : []
                        Fila {
                            required property var modelData
                            width: opciones.width
                            icono: "󰖯"
                            titulo: modelData.title || dock.nombre(menu.app)
                            formato: Text.PlainText
                            detalle: dock.lugar(modelData)
                            seleccionada: modelData.id === Niri.enfocada?.id
                            onClic: {
                                dock.irA(modelData);
                                menu.cerrar();
                            }
                        }
                    }
                    Rectangle {
                        visible: !menu.soloVentanas && (menu.app?.ventanas.length ?? 0) > 1
                        width: parent.width - 20
                        x: 10
                        height: 1
                        color: Tema.claro(0.12)
                    }

                    Fila {
                        width: parent.width
                        visible: !menu.soloVentanas && !!menu.app?.entrada
                        icono: menu.app?.fija ? "󰐄" : "󰐃"
                        titulo: menu.app?.fija ? "Quitar del dock" : "Fijar en el dock"
                        onClic: {
                            Favoritos.alternar(menu.app.clave);
                            menu.cerrar();
                        }
                    }
                    Fila {
                        width: parent.width
                        visible: !menu.soloVentanas && !!menu.app?.entrada
                        icono: "󰐕"
                        titulo: "Ventana nueva"
                        onClic: {
                            dock.lanzar(menu.app);
                            menu.cerrar();
                        }
                    }
                    Fila {
                        width: parent.width
                        visible: !menu.soloVentanas && (menu.app?.ventanas.length ?? 0) > 0
                        icono: "󰅖"
                        titulo: (menu.app?.ventanas.length ?? 0) > 1 ? "Cerrar las " + menu.app.ventanas.length + " ventanas" : "Cerrar"
                        onClic: {
                            dock.cerrarTodas(menu.app);
                            menu.cerrar();
                        }
                    }
                }
            }
        }
    }
}
