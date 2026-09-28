// ============================================================================
//  Portapapeles — historial de lo copiado (cliphist), en mitad de la pantalla
//  Atajo: Mod+Alt+V
//
//    Escribe para buscar · ↑ ↓ para moverte · Enter copia (pega con Ctrl+V)
//    Supr borra la entrada del historial · Esc para cerrar
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "portapapeles"
    lado: "medio"
    ancho: 640

    // Cada entrada: {linea: "id\ttexto" tal cual la da cliphist, texto, imagen}
    property var entradas: []
    property bool hayCliphist: true

    readonly property var resultados: {
        const q = busqueda.text.trim().toLowerCase();
        return q === "" ? entradas : entradas.filter(e => e.texto.toLowerCase().includes(q));
    }

    onAbiertoChanged: {
        if (abierto) {
            busqueda.text = "";
            lista.currentIndex = 0;
            busqueda.forceActiveFocus();
            leer.running = true;
        }
    }

    function copiar(e) {
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", e.linea]);
        Paneles.cerrar();
    }

    function borrar(e) {
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "_", e.linea]);
        const i = lista.currentIndex;
        entradas = entradas.filter(x => x !== e);
        lista.currentIndex = Math.min(i, resultados.length - 1);
    }

    Process {
        id: leer
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 3; cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.entradas = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const texto = l.slice(l.indexOf("\t") + 1);
                    return {linea: l, texto: texto, imagen: texto.startsWith("[[ binary data")};
                });
            }
        }
        onExited: codigo => panel.hayCliphist = codigo !== 3
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
                onClic: {
                    Quickshell.execDetached(["cliphist", "wipe"]);
                    panel.entradas = [];
                }
            }
        }

        // --------------------------------------------------------- Lista
        Lista {
            id: lista
            width: parent.width
            maximo: 480
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
