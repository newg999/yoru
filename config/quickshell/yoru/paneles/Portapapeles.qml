// ============================================================================
//  Portapapeles — historial de lo copiado (cliphist), bajo su botón de la barra
//  Atajo: Mod+Alt+V
//
//    Escribe para buscar · ↑ ↓ para moverte · Enter copia (pega con Ctrl+V)
//    Supr borra la entrada del historial · Esc para cerrar
//  (con la barra en píldora es una página de la píldora: PaginaPortapapeles.qml)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "portapapeles"
    lado: "derecha"
    ancho: 640

    // El historial: comun/Copiados.qml (lo comparte con la píldora)
    readonly property var entradas: Copiados.entradas
    readonly property bool hayCliphist: Copiados.hayCliphist
    readonly property var resultados: Copiados.buscar(busqueda.text)

    onAbiertoChanged: {
        if (abierto) {
            busqueda.text = "";
            lista.currentIndex = 0;
            busqueda.forceActiveFocus();
            Copiados.leer();
        }
    }

    function copiar(e) {
        Copiados.copiar(e);
    }

    function borrar(e) {
        if (!e)
            return;
        const i = lista.currentIndex;
        Copiados.borrar(e);
        lista.currentIndex = Math.min(i, resultados.length - 1);
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
                text: "󰅌"
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

                Keys.onDownPressed: lista.incrementCurrentIndex()
                Keys.onUpPressed: lista.decrementCurrentIndex()
                Keys.onTabPressed: lista.incrementCurrentIndex()
                Keys.onReturnPressed: panel.copiar(panel.resultados[lista.currentIndex])
                Keys.onEnterPressed: panel.copiar(panel.resultados[lista.currentIndex])
                Keys.onDeletePressed: event => {
                    // Con texto escrito, Supr borra letras; sin él, la entrada
                    if (busqueda.text === "" || event.modifiers & Qt.AltModifier)
                        panel.borrar(panel.resultados[lista.currentIndex]);
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
        }

        Titular {
            width: parent.width
            texto: "Historial · " + panel.resultados.length

            BotonIcono {
                icono: "󰆴"
                ayuda: "Borrar todo"
                colorIcono: Tema.gris
                visible: panel.entradas.length > 0
                onClic: Copiados.borrarTodo()
            }
        }

        // --------------------------------------------------------- Lista
        Lista {
            id: lista
            width: parent.width
            // 480, o menos si la pantalla es pequeña (159 = resto del panel)
            maximo: Math.min(480, panel.altoMax - 159)
            height: Math.max(implicitHeight, 60)
            model: panel.resultados
            highlightMoveDuration: 0
            keyNavigationWraps: true

            Texto {
                visible: panel.resultados.length === 0
                anchors.centerIn: parent
                text: !panel.hayCliphist ? "cliphist no está instalado"
                    : panel.entradas.length === 0 ? "Aún no has copiado nada"
                    : "Nada coincide"
                font.bold: false
                color: Tema.gris
            }

            delegate: Fila {
                id: entrada
                required property var modelData
                required property int index
                width: lista.width
                icono: modelData.imagen ? "󰋩" : "󰦨"
                // Las entradas de varias líneas, en una sola
                titulo: modelData.imagen ? "Imagen" : modelData.texto.slice(0, 300).replace(/\s+/g, " ")
                formato: Text.PlainText
                detalle: modelData.imagen ? modelData.texto.replace(/^\[\[ binary data |\]\]$/g, "") : ""
                seleccionada: ListView.isCurrentItem
                onHoverChanged: if (hover) lista.currentIndex = index
                onClic: panel.copiar(modelData)

                BotonIcono {
                    icono: "󰅖"
                    colorIcono: entrada.seleccionada ? Tema.oscuro : Tema.gris
                    onClic: panel.borrar(entrada.modelData)
                }
            }
        }

        Texto {
            leftPadding: 4
            text: "Enter copia  ·  Supr borra  ·  Esc cierra"
            font.bold: false
            font.pixelSize: 11
            color: Tema.gris
        }
    }
}
