// ============================================================================
//  Lanzador de apps — sale por la izquierda, bajo el botón 󰀻 de la barra
//
//    Escribe para buscar (nombre, descripción o palabras clave)
//    ↑ ↓ para moverte · Enter para abrir · Esc para cerrar
//
//  Las apps que más abres salen primero (se cuentan en usos.json, en
//  ~/.local/state/quickshell/.../).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Panel {
    id: panel
    nombre: "lanzador"
    lado: "izquierda"
    ancho: 480

    property var usos: ({})      // id de la app → veces abierta

    onAbiertoChanged: {
        if (abierto) {
            busqueda.text = "";
            lista.currentIndex = 0;
            busqueda.forceActiveFocus();
        }
    }

    readonly property var resultados: {
        const q = busqueda.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const puntuar = a => {
            if (q === "")
                return 1;
            const nombre = (a.name ?? "").toLowerCase();
            if (nombre.startsWith(q)) return 4;
            if (nombre.split(/\s+/).some(p => p.startsWith(q))) return 3;
            if (nombre.includes(q)) return 2;
            const resto = [a.genericName, a.comment, ...(a.keywords ?? [])].join(" ").toLowerCase();
            return resto.includes(q) ? 1 : 0;
        };
        return apps
            .map(a => ({app: a, puntos: puntuar(a), usos: panel.usos[a.id] ?? 0}))
            .filter(r => r.puntos > 0)
            .sort((x, y) => (y.puntos - x.puntos) || (y.usos - x.usos) || x.app.name.localeCompare(y.app.name))
            .map(r => r.app);
    }

    function abrir(app) {
        if (!app)
            return;
        const u = Object.assign({}, usos);
        u[app.id] = (u[app.id] ?? 0) + 1;
        usos = u;
        archivoUsos.setText(JSON.stringify(u));
        app.execute();
        Paneles.cerrar();
    }

    FileView {
        id: archivoUsos
        path: Quickshell.stateDir + "/usos.json"
        onLoaded: {
            try {
                panel.usos = JSON.parse(text());
            } catch (e) {}
        }
    }

    Column {
        width: parent.width
        spacing: 12

        // ----------------------------------------------------- Búsqueda
        Rectangle {
            width: parent.width
            height: 46
            radius: 12
            color: Tema.caja
            border.width: 1
            border.color: busqueda.activeFocus ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.1)

            Texto {
                id: lupa
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: "󰍉"
                font.pixelSize: 18
                color: Tema.gris
            }
            TextInput {
                id: busqueda
                anchors { left: lupa.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                color: Tema.texto
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                font.family: Tema.fuente
                font.pixelSize: 14
                focus: true
                clip: true
                onTextChanged: lista.currentIndex = 0

                Keys.onDownPressed: lista.incrementCurrentIndex()
                Keys.onUpPressed: lista.decrementCurrentIndex()
                Keys.onTabPressed: lista.incrementCurrentIndex()
                Keys.onReturnPressed: panel.abrir(panel.resultados[lista.currentIndex])
                Keys.onEnterPressed: panel.abrir(panel.resultados[lista.currentIndex])
                Keys.onEscapePressed: Paneles.cerrar()

                Texto {
                    visible: busqueda.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Buscar apps…"
                    font.bold: false
                    font.pixelSize: 14
                    color: Tema.gris
                }
            }
        }

        Texto {
            leftPadding: 4
            text: "󰀻  Aplicaciones  <font color='#8a8f98'>" + panel.resultados.length + "</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
            color: Tema.gris
        }

        // --------------------------------------------------------- Lista
        ListView {
            id: lista
            width: parent.width
            height: 560
            clip: true
            spacing: 2
            model: panel.resultados
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            keyNavigationWraps: true

            Texto {
                visible: panel.resultados.length === 0
                anchors.centerIn: parent
                text: "Ninguna app se llama así"
                font.bold: false
                color: Tema.gris
            }

            delegate: Rectangle {
                id: fila
                required property var modelData
                required property int index
                readonly property bool elegida: ListView.isCurrentItem
                width: lista.width
                height: 56
                radius: 10
                color: elegida ? Qt.rgba(1, 1, 1, 0.90) : "transparent"

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: lista.currentIndex = fila.index
                    onClicked: panel.abrir(fila.modelData)
                }

                IconImage {
                    id: iconoApp
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    implicitSize: 34
                    // Si la app no trae icono (o no existe en el tema), uno genérico
                    source: Quickshell.iconPath(fila.modelData.icon, true) || Quickshell.iconPath("application-x-executable")
                    asynchronous: true
                }
                Column {
                    anchors {
                        left: iconoApp.right; leftMargin: 14
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    Texto {
                        width: parent.width
                        text: fila.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 14
                        color: fila.elegida ? Tema.oscuro : Tema.texto
                    }
                    Texto {
                        width: parent.width
                        visible: text !== ""
                        text: fila.modelData.comment || fila.modelData.genericName || ""
                        elide: Text.ElideRight
                        font.bold: false
                        font.pixelSize: 11
                        color: fila.elegida ? Qt.rgba(26 / 255, 27 / 255, 30 / 255, 0.6) : Tema.gris
                    }
                }
            }
        }
    }
}
