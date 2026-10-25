// ============================================================================
//  Página «lanzador» de la píldora (Mod+Espacio con la barra en píldora):
//  la píldora se hace buscador
//
//    ( 󰍉  Buscar apps y ajustes…        )
//      [▣] Firefox                         ← la elegida, resaltada
//      [▣] Kitty
//
//  Escribe para buscar · ↑ ↓ para moverte · Enter abre · Esc cierra.
//  Qué sale y en qué orden: comun/Apps.qml (lo mismo que paneles/Lanzador.qml)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun

Column {
    id: pagina

    required property var pantalla
    property bool activa: false
    spacing: 8

    readonly property var resultados: Apps.buscar(busqueda.text)
    readonly property int filas: 7

    onActivaChanged: {
        if (activa) {
            busqueda.text = "";
            lista.currentIndex = 0;
            busqueda.forceActiveFocus();
        }
    }

    Rectangle {
        width: parent.width
        height: 44
        radius: Tema.esquina(22)
        color: Tema.caja

        Texto {
            id: lupa
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "󰍉"
            font.pixelSize: 16
            color: Tema.gris
        }
        TextInput {
            id: busqueda
            anchors { left: lupa.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 14
            clip: true
            onTextChanged: lista.currentIndex = 0

            Keys.onDownPressed: lista.incrementCurrentIndex()
            Keys.onUpPressed: lista.decrementCurrentIndex()
            Keys.onTabPressed: lista.incrementCurrentIndex()
            Keys.onReturnPressed: Apps.abrir(pagina.resultados[lista.currentIndex], pagina.pantalla)
            Keys.onEnterPressed: Apps.abrir(pagina.resultados[lista.currentIndex], pagina.pantalla)
            Keys.onEscapePressed: Paneles.cerrar()

            Texto {
                visible: busqueda.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar apps y ajustes…"
                font.bold: false
                font.pixelSize: 14
                color: Tema.gris
            }
        }
    }

    ListView {
        id: lista
        width: parent.width
        height: Math.max(1, Math.min(count, pagina.filas)) * 46
        clip: true
        model: pagina.resultados
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        keyNavigationWraps: true

        Texto {
            visible: pagina.resultados.length === 0
            anchors.centerIn: parent
            text: "No hay nada que se llame así"
            font.bold: false
            color: Tema.gris
        }

        delegate: Rectangle {
            id: fila
            required property var modelData
            required property int index
            readonly property bool elegida: ListView.isCurrentItem
            width: lista.width
            height: 46
            radius: Tema.esquina(23)
            color: elegida ? Tema.claro(0.10) : "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: lista.currentIndex = fila.index
                onClicked: Apps.abrir(fila.modelData, pagina.pantalla)
            }

            IconImage {
                id: icono
                visible: !fila.modelData.ajuste
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                implicitSize: 28
                source: fila.modelData.ajuste ? "" : Quickshell.iconPath(fila.modelData.icon, true) || Quickshell.iconPath("application-x-executable")
                asynchronous: true
            }
            // Los ajustes de Yoru llevan su glifo
            Rectangle {
                visible: fila.modelData.ajuste ?? false
                anchors.centerIn: icono
                width: 28; height: 28; radius: Tema.esquina(14)
                color: Tema.caja
                Texto {
                    anchors.centerIn: parent
                    text: fila.modelData.glifo ?? ""
                    font.pixelSize: 14
                }
            }
            Texto {
                anchors { left: icono.right; leftMargin: 12; right: detalle.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                text: fila.modelData.name
                elide: Text.ElideRight
                font.pixelSize: 13
                color: fila.elegida ? Tema.blanco : Tema.texto
            }
            Texto {
                id: detalle
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                visible: fila.elegida
                width: Math.min(implicitWidth, lista.width * 0.45)
                text: fila.modelData.comment || fila.modelData.genericName || ""
                elide: Text.ElideRight
                font.bold: false
                font.pixelSize: 11
                color: Tema.gris
            }
        }
    }
}
