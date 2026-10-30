// ============================================================================
//  Lanzador de apps — sale por la izquierda, bajo el botón 󰀻 de la barra.
//  Con Mod+Space (sección "medio") sale en mitad de la pantalla, más ancho
//  y con las apps en dos columnas. Con la barra de píldoras (islas arriba o
//  minimalista), no: sale siempre arriba a la izquierda, bajo su ficha 󰍉.
//  Con la de Windows tampoco: sale siempre fundido con ella, sobre 夜.
//
//    Escribe para buscar (nombre, descripción o palabras clave)
//    ↑ ↓ ← → para moverte · Enter para abrir · Esc para cerrar
//
//  Las apps que más abres salen primero, y al buscar salen también los
//  ajustes de Yoru: comun/Apps.qml.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.comun

Panel {
    id: panel
    nombre: "lanzador"
    // (con la barra de Windows, en el centro y fundido con ella, como su Inicio)
    lado: medio ? "medio" : Ajustes.windows ? "centro" : "izquierda"
    ancho: medio ? 820 : 480

    // (con la barra de Windows, Mod+Space también lo abre sobre 夜)
    readonly property bool medio: Paneles.seccion === "medio" && !Ajustes.conPildoras && !Ajustes.windows
    readonly property int columnas: medio ? 2 : 1

    // Qué sale y cómo se abre: comun/Apps.qml
    readonly property var resultados: Apps.buscar(busqueda.text)
    function abrir(app) {
        Apps.abrir(app, panel.modelData);
    }

    Column {
        width: parent.width
        spacing: 12

        // ----------------------------------------------------- Búsqueda
        Rectangle {
            width: parent.width
            height: 46
            radius: Tema.esquina(12)
            color: Tema.caja
            border.width: 1
            border.color: busqueda.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

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
                selectionColor: Tema.claro(0.3)
                font.family: Tema.fuente
                font.pixelSize: 14
                focus: true
                clip: true
                onTextChanged: lista.currentIndex = 0

                Keys.onDownPressed: lista.moveCurrentIndexDown()
                Keys.onUpPressed: lista.moveCurrentIndexUp()
                // Con dos columnas, ← → cambian de columna; con una, mueven el cursor del texto
                Keys.onLeftPressed: event => {
                    if (panel.columnas > 1) lista.moveCurrentIndexLeft();
                    else event.accepted = false;
                }
                Keys.onRightPressed: event => {
                    if (panel.columnas > 1) lista.moveCurrentIndexRight();
                    else event.accepted = false;
                }
                Keys.onTabPressed: lista.incrementCurrentIndex()
                Keys.onReturnPressed: panel.abrir(panel.resultados[lista.currentIndex])
                Keys.onEnterPressed: panel.abrir(panel.resultados[lista.currentIndex])
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

        Texto {
            leftPadding: 4
            text: "󰀻  " + (busqueda.text.trim() === "" ? "Aplicaciones" : "Apps y ajustes") + "  <font color='" + Tema.gris + "'>" + panel.resultados.length + "</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
            color: Tema.gris
        }

        // --------------------------------------------------------- Lista
        GridView {
            id: lista
            width: parent.width
            // 560, o menos si la pantalla es pequeña (117 = resto del panel),
            // en filas enteras: sin una a medias cortada abajo
            height: Math.floor(Math.min(560, panel.altoMax - 117) / cellHeight) * cellHeight - 2
            clip: true
            cellWidth: Math.floor(width / panel.columnas)
            cellHeight: 58
            // Al pasar de 1 a 2 columnas (o al revés) GridView no siempre
            // recoloca las filas que ya existían y se quedan unas encima de otras
            onCellWidthChanged: forceLayout()
            model: panel.resultados
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            keyNavigationWraps: true

            Texto {
                visible: panel.resultados.length === 0
                anchors.centerIn: parent
                text: "No hay nada que se llame así"
                font.bold: false
                color: Tema.gris
            }

            delegate: Rectangle {
                id: fila
                required property var modelData
                required property int index
                readonly property bool elegida: GridView.isCurrentItem
                width: lista.cellWidth - (panel.columnas > 1 ? 4 : 0)
                height: 56
                radius: Tema.esquina(10)
                color: elegida ? Tema.claro(0.90) : "transparent"

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: lista.currentIndex = fila.index
                    onClicked: panel.abrir(fila.modelData)
                }

                IconImage {
                    id: iconoApp
                    visible: !fila.modelData.ajuste
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    implicitSize: 34
                    // Si la app no trae icono (o no existe en el tema), uno genérico
                    source: fila.modelData.ajuste ? "" : Quickshell.iconPath(fila.modelData.icon, true) || Quickshell.iconPath("application-x-executable")
                    asynchronous: true
                }
                // Los ajustes de Yoru llevan su icono de la barra
                Rectangle {
                    visible: fila.modelData.ajuste ?? false
                    anchors.centerIn: iconoApp
                    width: 34; height: 34; radius: Tema.esquina(10)
                    color: fila.elegida ? Tema.sombra(0.15) : Tema.caja
                    Texto {
                        anchors.centerIn: parent
                        text: fila.modelData.glifo ?? ""
                        font.pixelSize: 18
                        color: fila.elegida ? Tema.oscuro : Tema.texto
                    }
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
                        color: fila.elegida ? Tema.sombra(0.6) : Tema.gris
                    }
                }
            }
        }
    }
}
