// ============================================================================
//  Página «portapapeles» de la píldora (Mod+Alt+V con la barra en píldora)
//
//    ( 󰅌  Buscar en el portapapeles…          󰆴 )
//      󰦨 lo que copiaste                     ✕
//      󰋩 Imagen · 1920x1080 png
//
//  Enter copia (pega con Ctrl+V) · Supr borra · Esc cierra.
//  El historial: comun/Copiados.qml (el mismo que paneles/Portapapeles.qml)
// ============================================================================
import QtQuick
import qs.comun

Column {
    id: pagina

    property bool activa: false
    spacing: 8

    readonly property var resultados: Copiados.buscar(busqueda.text)

    onActivaChanged: {
        if (activa) {
            busqueda.text = "";
            lista.currentIndex = 0;
            busqueda.forceActiveFocus();
            Copiados.leer();
        }
    }

    function borrar(e) {
        const i = lista.currentIndex;
        Copiados.borrar(e);
        lista.currentIndex = Math.min(i, resultados.length - 1);
    }

    Rectangle {
        width: parent.width
        height: 44
        radius: Tema.esquina(22)
        color: Tema.caja

        Texto {
            id: icono
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: "󰅌"
            font.pixelSize: 16
            color: Tema.gris
        }
        TextInput {
            id: busqueda
            anchors { left: icono.right; leftMargin: 12; right: papelera.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 14
            clip: true
            onTextChanged: lista.currentIndex = 0

            Keys.onDownPressed: lista.incrementCurrentIndex()
            Keys.onUpPressed: lista.decrementCurrentIndex()
            Keys.onTabPressed: lista.incrementCurrentIndex()
            Keys.onReturnPressed: Copiados.copiar(pagina.resultados[lista.currentIndex])
            Keys.onEnterPressed: Copiados.copiar(pagina.resultados[lista.currentIndex])
            Keys.onDeletePressed: event => {
                // Con texto escrito, Supr borra letras; sin él, la entrada
                if (busqueda.text === "" || event.modifiers & Qt.AltModifier)
                    pagina.borrar(pagina.resultados[lista.currentIndex]);
                else
                    event.accepted = false;
            }
            Keys.onEscapePressed: Paneles.cerrar()

            Texto {
                visible: busqueda.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar en el portapapeles…"
                font.bold: false
                font.pixelSize: 14
                color: Tema.gris
            }
        }
        // Borrar todo el historial
        Texto {
            id: papelera
            visible: Copiados.entradas.length > 0
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            text: "󰆴"
            font.pixelSize: 15
            color: papeleraRaton.containsMouse ? Tema.rojo : Tema.gris
            MouseArea {
                id: papeleraRaton
                anchors { fill: parent; margins: -6 }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Copiados.borrarTodo()
            }
        }
    }

    ListView {
        id: lista
        width: parent.width
        height: Math.max(1, Math.min(count, 7)) * 42
        clip: true
        model: pagina.resultados
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        keyNavigationWraps: true

        Texto {
            visible: pagina.resultados.length === 0
            anchors.centerIn: parent
            text: !Copiados.hayCliphist ? "cliphist no está instalado"
                : Copiados.entradas.length === 0 ? "Aún no has copiado nada"
                : "Nada coincide"
            font.bold: false
            color: Tema.gris
        }

        delegate: Rectangle {
            id: fila
            required property var modelData
            required property int index
            readonly property bool elegida: ListView.isCurrentItem
            width: lista.width
            height: 42
            radius: Tema.esquina(21)
            color: elegida ? Tema.claro(0.10) : "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: lista.currentIndex = fila.index
                onClicked: Copiados.copiar(fila.modelData)
            }
            Texto {
                id: tipo
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: fila.modelData.imagen ? "󰋩" : "󰦨"
                font.pixelSize: 14
                color: Tema.gris
            }
            Texto {
                anchors { left: tipo.right; leftMargin: 12; right: quitar.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                // Las entradas de varias líneas, en una sola
                text: fila.modelData.imagen
                    ? "Imagen  ·  " + fila.modelData.texto.replace(/^\[\[ binary data |\]\]$/g, "")
                    : fila.modelData.texto.slice(0, 300).replace(/\s+/g, " ")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.bold: false
                font.pixelSize: 13
                color: fila.elegida ? Tema.blanco : Tema.texto
            }
            Texto {
                id: quitar
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                visible: fila.elegida
                text: "󰅖"
                font.pixelSize: 13
                color: quitarRaton.containsMouse ? Tema.rojo : Tema.gris
                MouseArea {
                    id: quitarRaton
                    anchors { fill: parent; margins: -6 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pagina.borrar(fila.modelData)
                }
            }
        }
    }
}
