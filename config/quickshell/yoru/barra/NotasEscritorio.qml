// ============================================================================
//  Notas adhesivas en el escritorio de esta pantalla (los datos, en
//  comun/Notas.qml). Van por debajo de las ventanas, como los widgets: se
//  ven en los escritorios vacíos. Con cualquier estilo de barra.
//
//    Arrastrar por arriba = moverla · esquina de abajo a la derecha =
//    agrandarla o encogerla · 󰐕 = otra nota · 󰅖 = borrarla (si tiene algo
//    escrito, pide un segundo clic)
//    Clic en el texto = escribir; se guarda solo.
//
//  En markdown: mientras escribes, el texto tal cual; al salir (Esc o clic
//  fuera), con formato: # títulos, - listas, 1. números, > citas, ---,
//  ```código```, **negrita**, *cursiva*, `código` y [enlaces](url).
//  Las tareas (- [ ] y - [x]) son casillas: un clic las marca o desmarca.
//
//  Cada nota es una capa del tamaño de la pantalla, transparente y que solo
//  recibe clics donde está la nota (mask): así se mueve dentro de ella,
//  pegada al ratón. (Moviendo una ventanita con el ratón encima, las
//  coordenadas cambiaban con la propia ventana y daba saltos)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.comun

Scope {
    id: raiz
    required property ShellScreen modelData

    Variants {
        // Solo los id: así escribir en una nota no rehace su ventana
        model: Notas.lista.filter(t => t.pantalla === raiz.modelData.name
            || !Quickshell.screens.some(s => s.name === t.pantalla) && raiz.modelData === Quickshell.screens[0])
            .map(t => t.id)

        PanelWindow {
            id: ventana
            required property string modelData
            readonly property var nota: Notas.lista.find(t => t.id === modelData) ?? null

            screen: raiz.modelData
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "yoru-notas"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            // Solo la nota recibe clics; el resto de la pantalla, como si no estuviera
            mask: Region { item: hoja }

            // Lo de la nota en el archivo: al soltar (moverla o cambiar su tamaño)
            function guardarSitio() {
                Notas.cambiar(modelData, {x: Math.round(hoja.x), y: Math.round(hoja.y),
                    ancho: Math.round(hoja.width), alto: Math.round(hoja.height)});
            }

            Rectangle {
                id: hoja
                readonly property int minAncho: 160
                readonly property int minAlto: 110
                // La posición y el tamaño guardados, una vez: luego mandan el
                // arrastre y la esquina
                // (dentro de la pantalla: la capa aún no tiene tamaño aquí)
                Component.onCompleted: {
                    width = ventana.nota?.ancho ?? 230;
                    height = ventana.nota?.alto ?? 210;
                    x = Math.max(0, Math.min(ventana.nota?.x ?? 80, raiz.modelData.width - width));
                    y = Math.max(0, Math.min(ventana.nota?.y ?? 80, raiz.modelData.height - height));
                }

                radius: Tema.esquina(14)
                color: Tema.sombra(Math.max(0.93, Ajustes.opacidadIslas))
                border.width: 1
                border.color: texto.activeFocus ? Tema.claro(0.35) : Tema.claro(0.08)

                property bool confirmar: false
                Timer {
                    id: olvidar
                    interval: 3000
                    onTriggered: hoja.confirmar = false
                }

                // Arriba: para arrastrarla, y sus botones
                Item {
                    id: cabeza
                    width: parent.width
                    height: 30

                    MouseArea {
                        id: asa
                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: hoja
                        drag.threshold: 0
                        drag.minimumX: 0
                        drag.minimumY: 0
                        drag.maximumX: ventana.width - hoja.width
                        drag.maximumY: ventana.height - hoja.height
                        onReleased: ventana.guardarSitio()
                    }

                    // El asa: tres puntitos
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Repeater {
                            model: 3
                            Rectangle { width: 4; height: 4; radius: 2; color: Tema.claro(0.25) }
                        }
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        BotonIcono {
                            width: 24; height: 24
                            icono: "󰐕"
                            colorIcono: Tema.gris
                            onClic: Notas.nueva(raiz.modelData)
                        }
                        BotonIcono {
                            width: 24; height: 24
                            icono: "󰅖"
                            colorIcono: hoja.confirmar ? Tema.rojo : Tema.gris
                            alerta: hoja.confirmar
                            onClic: {
                                if (texto.text.trim() !== "" && !hoja.confirmar) {
                                    hoja.confirmar = true;
                                    olvidar.restart();
                                    return;
                                }
                                Notas.borrar(ventana.modelData);
                            }
                        }
                    }
                }

                Texto {
                    visible: hoja.confirmar
                    anchors { left: parent.left; leftMargin: 14; bottom: parent.bottom; bottomMargin: 8 }
                    text: "Otra vez para borrarla"
                    font.pixelSize: 10
                    font.bold: false
                    color: Tema.rojo
                }

                // ------------------------------------------------- Escribir
                // El texto tal cual (markdown), mientras escribes
                Flickable {
                    id: hojaTexto
                    visible: texto.activeFocus || texto.text === ""
                    anchors { fill: parent; topMargin: cabeza.height; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
                    contentHeight: texto.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: texto
                        width: hojaTexto.width
                        height: Math.max(implicitHeight, hojaTexto.height)
                        wrapMode: TextEdit.Wrap
                        color: Tema.texto
                        selectionColor: Tema.claro(0.3)
                        font.family: Tema.mono
                        font.pixelSize: 12
                        // El texto guardado, una vez: luego manda lo que escribes
                        Component.onCompleted: {
                            text = ventana.nota?.texto ?? "";
                            if (Notas.nuevaId === ventana.modelData)
                                forceActiveFocus();
                        }
                        onTextChanged: if (ventana.nota && text !== ventana.nota.texto)
                            Notas.cambiar(ventana.modelData, {texto: text})
                        // Que el cursor no se esconda al escribir más de lo que cabe
                        onCursorRectangleChanged: {
                            if (cursorRectangle.y < hojaTexto.contentY)
                                hojaTexto.contentY = cursorRectangle.y;
                            else if (cursorRectangle.y + cursorRectangle.height > hojaTexto.contentY + hojaTexto.height)
                                hojaTexto.contentY = cursorRectangle.y + cursorRectangle.height - hojaTexto.height;
                        }
                        // Esc: dejar de escribir (y verla ya con formato)
                        Keys.onEscapePressed: focus = false

                        Text {
                            visible: texto.text === ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "Escribe aquí…\n\n# Título\n- [ ] tarea\n- lista\n**negrita** *cursiva* `código`"
                            font.family: Tema.mono
                            font.pixelSize: 12
                            color: Tema.claro(0.3)
                        }
                    }
                }

                // ------------------------------------------- Con formato
                // Línea a línea: así las tareas se marcan con un clic
                Flickable {
                    id: vista
                    visible: !hojaTexto.visible
                    anchors { fill: parent; topMargin: cabeza.height; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
                    contentHeight: lineas.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // Cada línea del texto, con lo que es (dentro de ``` todo es código)
                    readonly property var bloques: {
                        const salida = [];
                        let codigo = false;
                        texto.text.split("\n").forEach((l, i) => {
                            let m;
                            if (/^\s*```/.test(l)) { codigo = !codigo; return; }
                            if (codigo) salida.push({tipo: "codigo", texto: l, i: i});
                            else if ((m = l.match(/^(\s*)[-*+] \[( |x|X)\] (.*)$/))) salida.push({tipo: "tarea", hecha: m[2] !== " ", texto: m[3], sangria: m[1].length, i: i});
                            else if ((m = l.match(/^(#{1,3}) (.*)$/))) salida.push({tipo: "titulo", nivel: m[1].length, texto: m[2], i: i});
                            else if ((m = l.match(/^(\s*)[-*+] (.*)$/))) salida.push({tipo: "punto", texto: m[2], sangria: m[1].length, i: i});
                            else if ((m = l.match(/^(\s*)(\d+)[.)] (.*)$/))) salida.push({tipo: "numero", numero: m[2], texto: m[3], sangria: m[1].length, i: i});
                            else if ((m = l.match(/^> ?(.*)$/))) salida.push({tipo: "cita", texto: m[1], i: i});
                            else if (/^\s*(---|\*\*\*|___)\s*$/.test(l)) salida.push({tipo: "raya", i: i});
                            else if (l.trim() === "") salida.push({tipo: "hueco", i: i});
                            else salida.push({tipo: "texto", texto: l, i: i});
                        });
                        return salida;
                    }

                    // Marcar o desmarcar la tarea de esa línea (en el texto)
                    function alternarTarea(i) {
                        const l = texto.text.split("\n");
                        l[i] = l[i].replace(/\[( |x|X)\]/, m => m === "[ ]" ? "[x]" : "[ ]");
                        texto.text = l.join("\n");
                    }

                    // Clic en la nota (no en una casilla ni en un enlace): a escribir
                    MouseArea {
                        width: vista.width
                        height: Math.max(vista.contentHeight, vista.height)
                        cursorShape: Qt.IBeamCursor
                        onClicked: {
                            texto.forceActiveFocus();
                            texto.cursorPosition = texto.length;
                        }
                    }

                    // Negrita, cursiva, `código` y enlaces dentro de una línea
                    component Linea: Text {
                        width: parent?.width ?? 0
                        wrapMode: Text.Wrap
                        textFormat: Text.MarkdownText
                        color: Tema.texto
                        linkColor: Tema.blanco
                        font.family: Tema.fuente
                        font.pixelSize: 13
                        onLinkActivated: url => Qt.openUrlExternally(url)
                        HoverHandler {
                            enabled: parent.hoveredLink !== ""
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Column {
                        id: lineas
                        width: vista.width
                        spacing: 3

                        Repeater {
                            model: vista.bloques

                            Item {
                                id: linea
                                required property var modelData
                                readonly property var b: modelData
                                readonly property int sangria: Math.min(3, Math.floor((b.sangria ?? 0) / 2)) * 14
                                width: lineas.width
                                height: b.tipo === "hueco" ? 6 : b.tipo === "raya" ? 11 : contenido.implicitHeight

                                // Separador
                                Rectangle {
                                    visible: linea.b.tipo === "raya"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width; height: 1
                                    color: Tema.claro(0.15)
                                }

                                Row {
                                    id: contenido
                                    visible: linea.b.tipo !== "hueco" && linea.b.tipo !== "raya"
                                    x: linea.sangria
                                    width: parent.width - x
                                    spacing: 7

                                    // Casilla, viñeta, número o la barra de la cita
                                    Rectangle {
                                        visible: linea.b.tipo === "tarea"
                                        y: 2
                                        width: 14; height: 14
                                        radius: 4
                                        color: linea.b.hecha ? Tema.blanco : "transparent"
                                        border.width: 1.5
                                        border.color: linea.b.hecha ? Tema.blanco : Tema.claro(0.45)
                                        Text {
                                            anchors.centerIn: parent
                                            visible: linea.b.hecha === true
                                            text: "󰄬"
                                            font.family: Tema.mono
                                            font.pixelSize: 11
                                            color: Tema.oscuro
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: vista.alternarTarea(linea.b.i)
                                        }
                                    }
                                    Text {
                                        visible: linea.b.tipo === "punto" || linea.b.tipo === "numero"
                                        text: linea.b.tipo === "numero" ? linea.b.numero + "." : "•"
                                        color: Tema.blanco
                                        font.family: Tema.fuente
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                    Rectangle {
                                        visible: linea.b.tipo === "cita"
                                        width: 3
                                        height: cuerpo.implicitHeight
                                        radius: 1.5
                                        color: Tema.claro(0.35)
                                    }

                                    // El texto de la línea
                                    Rectangle {
                                        readonly property bool esCodigo: linea.b.tipo === "codigo"
                                        width: contenido.width - (linea.b.tipo === "tarea" ? 21 : linea.b.tipo === "punto" || linea.b.tipo === "numero" ? 7 + 16 : linea.b.tipo === "cita" ? 10 : 0)
                                        height: cuerpo.implicitHeight + (esCodigo ? 4 : 0)
                                        color: esCodigo ? Tema.claro(0.07) : "transparent"
                                        radius: Tema.esquina(4)
                                        Linea {
                                            id: cuerpo
                                            x: parent.esCodigo ? 6 : 0
                                            y: parent.esCodigo ? 2 : 0
                                            width: parent.width - 2 * x
                                            textFormat: parent.esCodigo ? Text.PlainText : Text.MarkdownText
                                            text: linea.b.texto ?? ""
                                            font.family: parent.esCodigo ? Tema.mono : Tema.fuente
                                            font.pixelSize: linea.b.tipo === "titulo" ? [0, 18, 15, 14][linea.b.nivel]
                                                : parent.esCodigo ? 11 : 13
                                            font.bold: linea.b.tipo === "titulo"
                                            font.italic: linea.b.tipo === "cita"
                                            font.strikeout: linea.b.hecha === true
                                            color: linea.b.hecha === true || linea.b.tipo === "cita" ? Tema.gris
                                                : linea.b.tipo === "titulo" ? Tema.blanco : Tema.texto
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Esquina de abajo a la derecha: agrandar o encoger
                Item {
                    id: esquina
                    anchors { right: parent.right; bottom: parent.bottom }
                    width: 18; height: 18

                    // Dos rayitas en diagonal
                    Repeater {
                        model: 2
                        Rectangle {
                            required property int index
                            width: 2
                            height: 6 + 5 * index
                            radius: 1
                            rotation: 45
                            color: estirar.containsMouse || estirar.pressed ? Tema.claro(0.6) : Tema.claro(0.22)
                            x: 11 - 3 * index
                            y: 8 - 3 * index
                        }
                    }

                    MouseArea {
                        id: estirar
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.SizeFDiagCursor
                        // Las cuentas en la capa (no se mueve): sin saltos
                        property point desde
                        property size tamano
                        onPressed: e => {
                            desde = mapToItem(null, e.x, e.y);
                            tamano = Qt.size(hoja.width, hoja.height);
                        }
                        onPositionChanged: e => {
                            if (!pressed)
                                return;
                            const p = mapToItem(null, e.x, e.y);
                            hoja.width = Math.max(hoja.minAncho, Math.min(ventana.width - hoja.x, tamano.width + p.x - desde.x));
                            hoja.height = Math.max(hoja.minAlto, Math.min(ventana.height - hoja.y, tamano.height + p.y - desde.y));
                        }
                        onReleased: ventana.guardarSitio()
                    }
                }
            }
        }
    }
}
