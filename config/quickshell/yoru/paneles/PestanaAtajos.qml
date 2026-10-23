// ============================================================================
//  Pestaña Atajos de Ajustes — todos los atajos de teclado, con buscador
//
//  Los lee de niri/binds.kdl con scripts/atajos.py cada vez que se abre: si
//  cambias un atajo allí, aquí sale el nuevo. Para cambiarlos, el botón
//  abre binds.kdl (niri lo aplica al guardar).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Column {
    id: pestana

    property bool activa: false
    property var grupos: []        // lo de atajos.py

    spacing: 14
    onActivaChanged: if (activa) lector.running = true

    // Los grupos con solo los atajos que casan con la búsqueda
    readonly property var vistos: {
        const q = busqueda.text.trim().toLowerCase();
        if (q === "")
            return grupos;
        return grupos.map(g => ({
            grupo: g.grupo,
            atajos: g.atajos.filter(a => (g.grupo + " " + a.que + " " + a.teclas.map(t => t.join("+")).join(" "))
                .toLowerCase().includes(q))
        })).filter(g => g.atajos.length > 0);
    }

    Process {
        id: lector
        command: [Quickshell.shellPath("scripts/atajos.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pestana.grupos = JSON.parse(text);
                } catch (e) {
                    console.warn("Atajos: no se pudieron leer", e);
                }
            }
        }
    }

    // Buscador
    Rectangle {
        width: parent.width
        height: 42
        radius: Tema.esquina(10)
        color: Tema.caja
        border.width: 1
        border.color: busqueda.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

        Texto {
            id: lupa
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: "󰍉"
            font.pixelSize: 16
            color: Tema.gris
        }
        TextInput {
            id: busqueda
            anchors { left: lupa.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 13
            clip: true
            Texto {
                visible: busqueda.text === ""
                text: "Buscar (captura, escritorio, Super+Alt...)"
                font.pixelSize: 13
                font.bold: false
                color: Tema.tenue
            }
        }
    }

    Texto {
        visible: pestana.vistos.length === 0 && pestana.grupos.length > 0
        leftPadding: 12
        text: "Ningún atajo con eso"
        font.pixelSize: 12
        font.bold: false
        color: Tema.gris
    }

    Repeater {
        model: pestana.vistos

        Column {
            id: grupo
            required property var modelData
            width: pestana.width
            spacing: 0

            Titular { texto: grupo.modelData.grupo; width: parent.width }

            Repeater {
                model: grupo.modelData.atajos

                Rectangle {
                    id: fila
                    required property var modelData
                    width: grupo.width
                    height: 38
                    radius: Tema.esquina(10)
                    color: filaRaton.hovered ? Tema.cajaHover : "transparent"

                    HoverHandler { id: filaRaton }

                    Texto {
                        anchors { left: parent.left; leftMargin: 12; right: teclas.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: fila.modelData.que
                        font.pixelSize: 13
                        font.bold: false
                        elide: Text.ElideRight
                    }

                    // Cada combinación, con sus teclas en cajitas; si hay
                    // varias, separadas por «o»
                    Row {
                        id: teclas
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        Repeater {
                            model: fila.modelData.teclas

                            Row {
                                id: combo
                                required property var modelData
                                required property int index
                                spacing: 4

                                Texto {
                                    visible: combo.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    rightPadding: 4
                                    text: "o"
                                    font.pixelSize: 11
                                    font.bold: false
                                    color: Tema.gris
                                }
                                Repeater {
                                    model: combo.modelData
                                    Rectangle {
                                        id: caja
                                        required property string modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(24, nombre.implicitWidth + 14)
                                        height: 24
                                        radius: Tema.esquina(6)
                                        color: Tema.caja
                                        border.width: 1
                                        border.color: Tema.claro(0.12)
                                        Texto {
                                            id: nombre
                                            anchors.centerIn: parent
                                            text: caja.modelData
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item { width: 1; height: 2 }
    Opciones {
        width: parent.width
        opciones: [
            {id: "editar", icono: "󰏫", texto: "Cambiar atajos (binds.kdl)"},
            {id: "chuleta", icono: "󰌌", texto: "Chuleta de niri en pantalla"}
        ]
        onElegir: id => {
            if (id === "editar")
                Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.config/niri/binds.kdl"]);
            else
                Quickshell.execDetached(["niri", "msg", "action", "show-hotkey-overlay"]);
        }
    }
    Texto {
        width: parent.width
        text: "Super es la tecla de Windows. Lo que cambies en binds.kdl se aplica al guardar y sale aquí al volver a abrir esta sección."
        color: Tema.gris
        font.pixelSize: 11
        font.bold: false
        wrapMode: Text.Wrap
    }
}
