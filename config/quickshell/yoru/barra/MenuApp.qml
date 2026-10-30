// ============================================================================
//  MenuApp — el menú de una app del dock (Dock.qml) y de la barra de tareas
//  (BarraWindows.qml), encima de su icono
//
//    pulsar(app, item)      clic: sin ventanas la abre, con una va a ella y
//                           con varias saca la lista para elegir
//    abrir(app, item)       clic derecho: sus ventanas y las opciones
//                           (fijar / quitar, ventana nueva, cerrar)
//  Se cierra al sacar el ratón de él un momento o al elegir algo.
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Item {
    id: menu

    property string fijar: "Fijar en el dock"
    property string quitar: "Quitar del dock"
    property string clave: ""
    property bool soloVentanas: false
    property Item sobre: null
    // Se busca en Tareas.apps cada vez para que la lista siga al día si se
    // abre o se cierra una ventana con el menú abierto (y se cierre si la
    // app desaparece)
    readonly property var app: clave !== "" ? (Tareas.apps.find(a => a.clave === clave) ?? null) : null
    readonly property bool abierto: app !== null

    function abrir(a, item, solo) {
        sobre = item;
        soloVentanas = solo ?? false;
        clave = a.clave;
    }
    function cerrar() {
        clave = "";
    }
    function pulsar(a, item) {
        if (a.ventanas.length === 0)
            Tareas.lanzar(a);
        else if (a.ventanas.length === 1)
            Tareas.irA(a.ventanas[0]);
        else if (app?.clave === a.clave && soloVentanas)
            cerrar();
        else
            abrir(a, item, true);
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
                border.width: Tema.borde(1)
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
                        text: menu.app ? Tareas.nombre(menu.app) : ""
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
                            titulo: modelData.title || Tareas.nombre(menu.app)
                            formato: Text.PlainText
                            detalle: Tareas.lugar(modelData)
                            seleccionada: modelData.id === Niri.enfocada?.id
                            onClic: {
                                Tareas.irA(modelData);
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
                        titulo: menu.app?.fija ? menu.quitar : menu.fijar
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
                            Tareas.lanzar(menu.app);
                            menu.cerrar();
                        }
                    }
                    Fila {
                        width: parent.width
                        visible: !menu.soloVentanas && (menu.app?.ventanas.length ?? 0) > 0
                        icono: "󰅖"
                        titulo: (menu.app?.ventanas.length ?? 0) > 1 ? "Cerrar las " + menu.app.ventanas.length + " ventanas" : "Cerrar"
                        onClic: {
                            Tareas.cerrarTodas(menu.app);
                            menu.cerrar();
                        }
                    }
                }
            }
        }
    }
}
