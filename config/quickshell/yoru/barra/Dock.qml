// ============================================================================
//  Dock — barra de apps abajo, como la del Mac, con la estética de Yoru
//
//    [favoritas] │ [abiertas que no están fijadas]
//
//    Clic           = ir a su ventana (si tiene varias, cada clic pasa a la
//                     siguiente) · si no está abierta, la abre
//    Clic central   = ventana nueva
//    Clic derecho   = menú: fijar / quitar, ventana nueva, cerrar todas
//
//  Los puntitos de debajo son sus ventanas abiertas; el alargado, la app
//  que tiene el foco. Siempre visible: reserva su espacio abajo.
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
    readonly property int margen: Tema.margenBarra   // hasta el borde, como la barra

    // La ventana es más alta que el dock (para el nombre y el menú que salen
    // encima), pero solo reserva el alto del dock y solo recibe clics en él
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 260
    exclusiveZone: alto + 2 * margen
    color: "transparent"
    WlrLayershell.namespace: "yoru-dock"
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: isla
        Region { item: menu.visible ? menu : null }
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

    // Última ventana con el foco de cada app: al volver a ella, se va a esa
    property var ultima: ({})
    Connections {
        target: Niri
        function onEnfocadaChanged() {
            const v = Niri.enfocada;
            if (!v)
                return;
            const clave = DesktopEntries.heuristicLookup(v.app_id)?.id ?? v.app_id;
            dock.ultima[clave] = v.id;
        }
    }

    function nombre(app) {
        return app.entrada?.name ?? app.appId;
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
    }

    function pulsar(app) {
        if (app.ventanas.length === 0) {
            lanzar(app);
            return;
        }
        const actual = app.ventanas.findIndex(v => v.id === Niri.enfocada?.id);
        const destino = actual >= 0
            ? app.ventanas[(actual + 1) % app.ventanas.length]            // la siguiente
            : app.ventanas.find(v => v.id === ultima[app.clave]) ?? app.ventanas[0];
        Niri.accion("focus-window", "--id", String(destino.id));
    }

    function cerrarTodas(app) {
        for (const v of app.ventanas)
            Niri.accion("close-window", "--id", String(v.id));
    }

    // ------------------------------------------------------------- Isla
    Rectangle {
        id: isla
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: dock.margen }
        width: fila.implicitWidth + 12
        height: dock.alto
        radius: Tema.radio + 2
        color: Tema.isla
        border.width: 1
        border.color: Tema.islaBorde
        visible: dock.apps.length > 0
        Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

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
                                    menu.abrir(hueco.app, elemento);
                                } else {
                                    menu.cerrar();
                                    if (e.button === Qt.MiddleButton)
                                        dock.lanzar(hueco.app);
                                    else
                                        dock.pulsar(hueco.app);
                                }
                            }
                        }

                        // Nombre encima del icono (tras un momento con el ratón)
                        Timer {
                            id: retraso
                            interval: 450
                            running: raton.containsMouse && !menu.visible
                        }
                        Rectangle {
                            visible: opacity > 0
                            opacity: raton.containsMouse && !retraso.running && !menu.visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                            parent: dock.contentItem
                            x: isla.x + fila.x + hueco.x + elemento.x + (elemento.width - width) / 2
                            y: isla.y - height - 10
                            width: etiqueta.implicitWidth + 24
                            height: etiqueta.implicitHeight + 14
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

    // ------------------------------------------------- Menú (clic derecho)
    // Se cierra al sacar el ratón de él un momento, al elegir algo o con Esc
    Rectangle {
        id: menu

        property var app: null
        property Item sobre: null

        function abrir(a, item) {
            app = a;
            sobre = item;
            visible = true;
        }
        function cerrar() {
            visible = false;
            app = null;
        }

        visible: false
        width: 230
        height: opciones.implicitHeight + 12
        x: {
            if (!sobre)
                return 0;
            const centro = sobre.mapToItem(dock.contentItem, sobre.width / 2, 0).x;
            return Math.max(8, Math.min(dock.width - width - 8, centro - width / 2));
        }
        y: isla.y - height - 10
        radius: 12
        color: Tema.panel
        border.width: 1
        border.color: Tema.claro(0.25)

        HoverHandler { id: dentro }
        Timer {
            interval: 700
            running: menu.visible && !dentro.hovered
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
            Fila {
                width: parent.width
                visible: menu.app?.entrada !== null && menu.app?.entrada !== undefined
                icono: menu.app?.fija ? "󰐄" : "󰐃"
                titulo: menu.app?.fija ? "Quitar del dock" : "Fijar en el dock"
                onClic: {
                    Favoritos.alternar(menu.app.clave);
                    menu.cerrar();
                }
            }
            Fila {
                width: parent.width
                visible: menu.app?.entrada !== null && menu.app?.entrada !== undefined
                icono: "󰐕"
                titulo: "Ventana nueva"
                onClic: {
                    dock.lanzar(menu.app);
                    menu.cerrar();
                }
            }
            Fila {
                width: parent.width
                visible: (menu.app?.ventanas.length ?? 0) > 0
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
