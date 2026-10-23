// ============================================================================
//  Pestaña Teclado de Ajustes — distribución, repetición y teclas especiales
//
//    Distribución: una o varias (la primera es la principal), cómo pasar de
//                  una a otra y si cada ventana recuerda la suya
//    Repetición:   cuánto esperar y lo rápido que repite al dejar pulsada
//                  una tecla, con una caja para probarlo
//    Teclas:       qué hace Bloq Mayús y si Bloq Num empieza encendido
//
//  Se guarda junto al ratón en niri/raton.kdl con scripts/raton.py (también
//  lo usa la pantalla de inicio de sesión, para escribir la contraseña).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Item {
    id: pestana

    property bool activa: false
    property var datos: null          // lo de raton.py leer (aquí se usa .teclado)
    property var todas: []            // [{layout, variant, nombre}] de xkb
    property string error: ""

    readonly property var teclado: datos?.teclado ?? null
    readonly property bool varias: (teclado?.distribuciones.length ?? 0) > 1

    implicitHeight: columnas.height + 12 + pie.height
    onActivaChanged: if (activa) {
        lector.running = true;
        if (todas.length === 0)
            lectorTodas.running = true;
    }

    // Cambia un ajuste del teclado y guarda al rato
    function poner(clave, valor) {
        const d = JSON.parse(JSON.stringify(datos));
        d.teclado[clave] = valor;
        datos = d;
        espera.restart();
    }

    function nombre(d) {
        const una = todas.find(t => t.layout === d.layout && t.variant === d.variant);
        return una ? una.nombre : d.variant ? `${d.layout} (${d.variant})` : d.layout;
    }

    function quitar(i) {
        const lista = teclado.distribuciones.slice();
        lista.splice(i, 1);
        poner("distribuciones", lista);
    }

    function principal(i) {
        const lista = teclado.distribuciones.slice();
        lista.unshift(lista.splice(i, 1)[0]);
        poner("distribuciones", lista);
    }

    function anadir(d) {
        const lista = teclado.distribuciones.slice();
        if (!lista.some(x => x.layout === d.layout && x.variant === d.variant))
            lista.push({layout: d.layout, variant: d.variant});
        poner("distribuciones", lista);
        busqueda.text = "";
    }

    Timer {
        id: espera
        interval: 400
        onTriggered: {
            pestana.error = "";
            escritor.command = [Quickshell.shellPath("scripts/raton.py"), "guardar", JSON.stringify(pestana.datos)];
            escritor.running = true;
        }
    }

    Process {
        id: lector
        command: [Quickshell.shellPath("scripts/raton.py"), "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pestana.datos = JSON.parse(text);
                } catch (e) {
                    pestana.error = "No se pudieron leer los ajustes del teclado";
                }
            }
        }
    }

    Process {
        id: lectorTodas
        command: [Quickshell.shellPath("scripts/raton.py"), "distribuciones"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pestana.todas = JSON.parse(text);
                } catch (e) {
                    console.warn("Teclado: no se pudieron leer las distribuciones", e);
                }
            }
        }
    }

    Process {
        id: escritor
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            if (codigo !== 0)
                pestana.error = errores.text.trim() || "No se pudo guardar";
        }
    }

    Process {
        id: restablecedor
        command: [Quickshell.shellPath("scripts/raton.py"), "restablecer", "teclado"]
        onExited: lector.running = true
    }

    // Fila con un deslizador (como las de Ratón)
    component Regulador: Item {
        id: regulador
        property string titulo: ""
        property real valor: 0          // 0-1 en la barra
        property string mostrado: ""
        signal movido(real nuevo)
        width: parent.width
        height: 40
        Texto {
            id: etiqueta
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width: 96
            text: regulador.titulo
            font.pixelSize: 13
        }
        Deslizador {
            anchors {
                left: etiqueta.right; leftMargin: 8
                right: cifra.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            valor: regulador.valor
            onMovido: nuevo => regulador.movido(nuevo)
        }
        Texto {
            id: cifra
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: 56
            horizontalAlignment: Text.AlignRight
            text: regulador.mostrado
            font.pixelSize: 12
            color: Tema.gris
        }
    }

    // Caja de texto con un icono delante (la búsqueda y la de probar)
    component Caja: Rectangle {
        id: caja
        property string icono: ""
        property string pista: ""
        property alias text: texto.text
        signal enviar()
        width: parent.width
        height: 42
        radius: Tema.esquina(10)
        color: Tema.caja
        border.width: 1
        border.color: texto.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

        Texto {
            id: icono
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text: caja.icono
            font.pixelSize: 16
            color: Tema.gris
        }
        TextInput {
            id: texto
            anchors { left: icono.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            color: Tema.texto
            selectionColor: Tema.claro(0.3)
            font.family: Tema.fuente
            font.pixelSize: 13
            clip: true
            Keys.onReturnPressed: caja.enviar()
            Texto {
                visible: texto.text === ""
                text: caja.pista
                font.pixelSize: 13
                font.bold: false
                color: Tema.tenue
            }
        }
    }

    Row {
        id: columnas
        visible: pestana.datos !== null
        width: parent.width
        spacing: 16
        readonly property real mitad: (width - spacing) / 2

        // ---------------------------------------------------- Distribución
        Column {
            width: columnas.mitad
            spacing: 2

            Titular { texto: "Distribución"; width: parent.width }

            Repeater {
                model: pestana.teclado?.distribuciones ?? []

                Rectangle {
                    id: capa
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 40
                    radius: Tema.esquina(10)
                    color: capaRaton.containsMouse ? Tema.cajaHover : "transparent"

                    HoverHandler { id: capaRaton }

                    Texto {
                        anchors { left: parent.left; leftMargin: 12; right: botones.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: pestana.nombre(capa.modelData)
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Row {
                        id: botones
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            rightPadding: 6
                            visible: capa.index === 0 && pestana.varias
                            text: "Principal"
                            font.pixelSize: 11
                            color: Tema.gris
                        }
                        BotonIcono {
                            visible: capa.index > 0
                            icono: "󰁝"
                            onClic: pestana.principal(capa.index)
                        }
                        BotonIcono {
                            visible: pestana.varias
                            icono: "󰅖"
                            onClic: pestana.quitar(capa.index)
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }
            Caja {
                id: busqueda
                visible: (pestana.teclado?.distribuciones.length ?? 0) < 4
                icono: "󰍉"
                pista: "Añadir otra (inglés, latinoamericano, catalán...)"
                onEnviar: if (resultados.count > 0) pestana.anadir(resultados.model[0])
            }
            Repeater {
                id: resultados
                model: {
                    const q = busqueda.text.trim().toLowerCase();
                    if (q === "")
                        return [];
                    const sinTildes = t => t.normalize("NFD").replace(/[̀-ͯ]/g, "");
                    const qq = sinTildes(q);
                    return pestana.todas.filter(t => sinTildes(t.nombre.toLowerCase()).includes(qq)
                            || t.layout === q).slice(0, 8);
                }
                Rectangle {
                    id: resultado
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 38
                    radius: Tema.esquina(10)
                    color: resultadoRaton.containsMouse || index === 0 ? Tema.cajaHover : "transparent"
                    Texto {
                        anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        text: resultado.modelData.nombre
                        font.pixelSize: 13
                        font.bold: false
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: resultadoRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pestana.anadir(resultado.modelData)
                    }
                }
            }

            // Con más de una: cómo cambiar
            Column {
                width: parent.width
                spacing: 2
                visible: pestana.varias

                Item { width: 1; height: 8 }
                Texto {
                    leftPadding: 12
                    bottomPadding: 6
                    text: "Cambiar con"
                    font.pixelSize: 13
                }
                Opciones {
                    width: parent.width
                    opciones: [
                        {id: "alt_shift_toggle", texto: "Alt+Mayús"},
                        {id: "shifts_toggle", texto: "Las dos Mayús"},
                        {id: "caps_toggle", texto: "Bloq Mayús"}
                    ]
                    valor: pestana.teclado?.cambiar ?? ""
                    onElegir: id => pestana.poner("cambiar", id)
                }
                Item { width: 1; height: 4 }
                Interruptor {
                    width: parent.width
                    titulo: "Una por ventana"
                    detalle: "Cada ventana recuerda con cuál escribías"
                    activo: pestana.teclado?.porVentana ?? false
                    onCambiar: v => pestana.poner("porVentana", v)
                }
            }
        }

        // ------------------------------------------- Repetición y teclas
        Column {
            width: columnas.mitad
            spacing: 2

            Titular { texto: "Repetición"; width: parent.width }
            // Retardo: de 150 a 1000 ms, de 50 en 50
            Regulador {
                titulo: "Esperar"
                valor: pestana.teclado ? (pestana.teclado.retardo - 150) / 850 : 0
                mostrado: pestana.teclado ? pestana.teclado.retardo + " ms" : ""
                onMovido: nuevo => pestana.poner("retardo", 150 + Math.round(nuevo * 17) * 50)
            }
            // Velocidad: de 10 a 80 por segundo, de 5 en 5
            Regulador {
                titulo: "Velocidad"
                valor: pestana.teclado ? (pestana.teclado.velocidad - 10) / 70 : 0
                mostrado: pestana.teclado ? pestana.teclado.velocidad + " /s" : ""
                onMovido: nuevo => pestana.poner("velocidad", 10 + Math.round(nuevo * 14) * 5)
            }
            Item { width: 1; height: 4 }
            Caja {
                icono: "󰌌"
                pista: "Deja pulsada una tecla aquí para probar"
            }

            Item { width: 1; height: 10 }
            Titular { texto: "Teclas"; width: parent.width }
            Texto {
                leftPadding: 12
                bottomPadding: 6
                text: "Bloq Mayús"
                font.pixelSize: 13
            }
            Opciones {
                width: parent.width
                enabled: !(pestana.varias && pestana.teclado?.cambiar === "caps_toggle")
                opacity: enabled ? 1 : 0.4
                opciones: [
                    {id: "", texto: "Normal"},
                    {id: "escape", texto: "Escape"},
                    {id: "ctrl", texto: "Ctrl"},
                    {id: "nada", texto: "Nada"}
                ]
                valor: pestana.teclado?.mayus ?? ""
                onElegir: id => pestana.poner("mayus", id)
            }
            Item { width: 1; height: 4 }
            Interruptor {
                width: parent.width
                titulo: "Bloq Num encendido"
                detalle: "Al iniciar sesión, para usar los números de la derecha"
                activo: pestana.teclado?.numlock ?? false
                onCambiar: v => pestana.poner("numlock", v)
            }
        }
    }

    Column {
        id: pie
        anchors.top: columnas.bottom
        anchors.topMargin: 12
        width: parent.width
        spacing: 8

        Texto {
            width: parent.width
            visible: pestana.error !== ""
            text: pestana.error
            color: Tema.rojo
            font.pixelSize: 12
            font.bold: false
            wrapMode: Text.Wrap
        }
        Opciones {
            width: parent.width
            opciones: [{id: "restablecer", icono: "󰑓", texto: "Restablecer el teclado"}]
            onElegir: restablecedor.running = true
        }
        Texto {
            width: parent.width
            text: "Se aplica al momento. La pantalla de inicio de sesión lo coge al volver a instalar Yoru (./install.sh)."
            color: Tema.gris
            font.pixelSize: 11
            font.bold: false
            wrapMode: Text.Wrap
        }
    }
}
