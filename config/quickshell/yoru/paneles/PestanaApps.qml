// ============================================================================
//  Pestaña Apps de Ajustes — con qué app se abre cada cosa
//
//    ┌ Navegador     󰖟 ┐   ABRIR MÚSICA CON
//    │ Música        ● │   ● Elisa             ✓
//    │ Vídeo           │     mpv
//    │ ...             │     VLC
//    └ [ .flac      ]  ┘
//
//  A la izquierda, las categorías (con el icono de la app que tienen); a la
//  derecha, las apps que pueden abrirla: un clic y queda puesta para todos
//  sus tipos. Abajo, «otro tipo»: escribe una extensión (.flac, mkv...) para
//  elegir solo para ella.
//  Lo hace scripts/predeterminadas.py (Gio, ~/.config/mimeapps.list).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Item {
    id: pestana

    property bool activa: false
    property var categorias: []        // de «predeterminadas.py leer»
    property string elegida: "web"     // id de categoría, o "tipo" (la extensión buscada)
    property var tipo: null            // {mime, descripcion, actual, apps} de «tipo»
    property string error: ""
    property string poniendo: ""       // app que se está poniendo

    readonly property string script: Quickshell.shellPath("scripts/predeterminadas.py")
    readonly property var actual: elegida === "tipo" ? tipo : categorias.find(c => c.id === elegida) ?? null

    implicitHeight: Math.max(izquierda.height, derecha.height)
    onActivaChanged: if (activa) lector.running = true

    function icono(nombre) {
        return nombre.startsWith("/") ? "file://" + nombre : Quickshell.iconPath(nombre, "application-x-executable");
    }

    function poner(app) {
        if (poniendo !== "" || !actual || app === actual.actual)
            return;
        error = "";
        poniendo = app;
        escritor.command = elegida === "tipo"
            ? [script, "poner-tipo", tipo.mime, app]
            : [script, "poner", elegida, app];
        escritor.running = true;
    }

    function buscarTipo(texto) {
        if (texto.trim() === "")
            return;
        error = "";
        buscador.command = [script, "tipo", texto.trim()];
        buscador.running = true;
    }

    Process {
        id: lector
        command: [pestana.script, "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pestana.categorias = JSON.parse(text);
                } catch (e) {
                    pestana.error = "No se pudieron leer las apps predeterminadas";
                }
            }
        }
    }

    Process {
        id: escritor
        stderr: StdioCollector { id: erroresEscritor }
        onExited: codigo => {
            if (codigo !== 0)
                pestana.error = erroresEscritor.text.trim() || "No se pudo cambiar";
            pestana.poniendo = "";
            lector.running = true;
            if (pestana.elegida === "tipo")
                pestana.buscarTipo(pestana.tipo.mime);
        }
    }

    Process {
        id: buscador
        stdout: StdioCollector { id: salidaBuscador }
        stderr: StdioCollector { id: erroresBuscador }
        onExited: codigo => {
            if (codigo !== 0) {
                pestana.error = erroresBuscador.text.trim() || "No conozco ese tipo de archivo";
                return;
            }
            try {
                pestana.tipo = JSON.parse(salidaBuscador.text);
                pestana.elegida = "tipo";
            } catch (e) {
                pestana.error = "No conozco ese tipo de archivo";
            }
        }
    }

    // ------------------------------------------------------- Categorías
    Column {
        id: izquierda
        width: Math.round(parent.width * 0.42)
        spacing: 2

        Titular { texto: "Abrir…"; width: parent.width }

        Repeater {
            model: pestana.categorias
            Rectangle {
                id: fila
                required property var modelData
                readonly property bool esta: pestana.elegida === modelData.id
                readonly property var app: modelData.apps.find(a => a.id === modelData.actual) ?? null
                width: izquierda.width
                height: 38
                radius: 10
                color: esta ? Tema.activo : zonaFila.containsMouse ? Tema.cajaHover : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.rapida } }

                Texto {
                    id: glifo
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 20
                    text: fila.modelData.icono
                    font.pixelSize: 15
                    color: fila.esta ? Tema.blanco : Tema.gris
                }
                Texto {
                    anchors {
                        left: glifo.right; leftMargin: 8
                        right: iconoApp.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: fila.modelData.nombre
                    font.pixelSize: 13
                    font.bold: fila.esta
                    elide: Text.ElideRight
                }
                IconImage {
                    id: iconoApp
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    implicitSize: 20
                    visible: fila.app !== null
                    source: fila.app ? pestana.icono(fila.app.icono) : ""
                }
                MouseArea {
                    id: zonaFila
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pestana.elegida = fila.modelData.id;
                        pestana.error = "";
                    }
                }
            }
        }

        Item { width: 1; height: 8 }
        Titular { texto: "Otro tipo de archivo"; width: parent.width }
        Rectangle {
            width: parent.width
            height: 38
            radius: 10
            color: pestana.elegida === "tipo" ? Tema.activo : Tema.caja
            border.width: 1
            border.color: entrada.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

            TextInput {
                id: entrada
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                verticalAlignment: TextInput.AlignVCenter
                color: Tema.texto
                selectionColor: Tema.claro(0.3)
                font.family: Tema.fuente
                font.pixelSize: 13
                clip: true
                onAccepted: pestana.buscarTipo(text)

                Texto {
                    visible: entrada.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Extensión (.flac, mkv…) e Intro"
                    font.bold: false
                    font.pixelSize: 12
                    color: Tema.gris
                }
            }
        }
    }

    // ------------------------------------------------------------- Apps
    Column {
        id: derecha
        anchors { left: izquierda.right; leftMargin: 16; right: parent.right }
        spacing: 2

        Titular {
            width: parent.width
            texto: !pestana.actual ? ""
                : pestana.elegida === "tipo" ? "Abrir " + (pestana.tipo.descripcion || pestana.tipo.mime) + " con"
                : "Abrir " + pestana.actual.nombre.toLowerCase() + " con"
        }

        Texto {
            visible: pestana.elegida === "tipo" && pestana.tipo !== null
            width: parent.width
            leftPadding: 4
            bottomPadding: 4
            text: pestana.tipo?.mime ?? ""
            font.pixelSize: 11
            font.bold: false
            color: Tema.gris
        }
        Texto {
            visible: pestana.actual?.mezcla ?? false
            width: parent.width
            leftPadding: 4
            bottomPadding: 6
            text: "Ahora cada tipo se abre con una app distinta: elige una y valdrá para todos."
            font.pixelSize: 11
            font.bold: false
            color: Tema.amarillo
            wrapMode: Text.Wrap
        }

        Repeater {
            model: pestana.actual?.apps ?? []
            Rectangle {
                id: opcion
                required property var modelData
                readonly property bool puesta: modelData.id === pestana.actual.actual
                width: derecha.width
                height: 44
                radius: 10
                color: puesta ? Tema.activo : zonaOpcion.containsMouse ? Tema.cajaHover : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.rapida } }

                IconImage {
                    id: iconoOpcion
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    implicitSize: 26
                    source: pestana.icono(opcion.modelData.icono)
                }
                Texto {
                    anchors {
                        left: iconoOpcion.right; leftMargin: 12
                        right: marca.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: opcion.modelData.nombre
                    font.pixelSize: 13
                    font.bold: opcion.puesta
                    elide: Text.ElideRight
                }
                Texto {
                    id: marca
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: pestana.poniendo === opcion.modelData.id ? "󰔟" : opcion.puesta ? "󰄬" : ""
                    font.pixelSize: 16
                    color: Tema.blanco
                }
                MouseArea {
                    id: zonaOpcion
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: opcion.puesta ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: pestana.poner(opcion.modelData.id)
                }
            }
        }

        Texto {
            visible: pestana.actual !== null && pestana.actual.apps.length === 0
            width: parent.width
            leftPadding: 4
            text: "No hay ninguna app instalada que lo abra. Búscala en la Tienda (Mod+Alt+S)."
            font.pixelSize: 12
            font.bold: false
            color: Tema.gris
            wrapMode: Text.Wrap
        }

        Texto {
            visible: pestana.error !== ""
            width: parent.width
            topPadding: 6
            leftPadding: 4
            text: pestana.error
            color: Tema.rojo
            font.pixelSize: 12
            font.bold: false
            wrapMode: Text.Wrap
        }
    }
}
