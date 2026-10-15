// ============================================================================
//  Fondos — elegir fondo de pantalla con miniaturas, en mitad de la pantalla
//  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin panel
//
//    ↑ ↓ ← → para moverte · Enter para ponerlo · Esc para cerrar
//
//  Los fondos salen de ~/.local/share/wallpapers (scripts/fondos.sh hace
//  las miniaturas la primera vez) y se ponen con niri/scripts/wallpaper.sh,
//  que también los lleva al bloqueo, al inicio de sesión y a «yoru tema fondo».
//
//  Pestaña Descubrir: busca fondos nuevos en wallhaven.cc (populares, por
//  tema o por palabra) con scripts/wallhaven.py. Clic = se baja y se pone.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Panel {
    id: panel
    nombre: "fondos"
    lado: "medio"
    ancho: 1000

    readonly property int columnas: 5
    readonly property string casa: Quickshell.env("HOME")

    property var fondos: []          // [{ruta, miniatura, nombre}]
    property string actual: ""
    property bool cargando: false
    property string vista: "mios"    // "mios" · "descubrir"

    // ------------------------------------------------------ Descubrir
    readonly property var temas: [
        {id: "populares", icono: "󰈸", texto: "Populares"},
        {id: "naturaleza", icono: "󰔱", texto: "Naturaleza"},
        {id: "anime", icono: "󰙃", texto: "Anime"},
        {id: "minimalista", icono: "󰝤", texto: "Minimalista"},
        {id: "noche", icono: "󰖔", texto: "Noche"}
    ]
    property string consulta: "populares"   // un tema o lo que se haya escrito
    property var nuevos: []          // [{id, url, miniatura, resolucion, megas, bajado}]
    property int pagina: 0
    property int ultima: 1
    property string error: ""
    property string bajando: ""      // id del que se está bajando

    function buscar(consulta) {
        consulta = consulta.trim();
        if (consulta === "")
            return;
        panel.consulta = consulta;
        nuevos = [];
        pagina = 0;
        ultima = 1;
        error = "";
        mas();
    }

    // Siguiente página de resultados (al llegar al final de la rejilla)
    function mas() {
        if (buscador.running || pagina >= ultima)
            return;
        buscador.command = [Quickshell.shellPath("scripts/wallhaven.py"), "buscar", consulta, String(pagina + 1)];
        buscador.running = true;
    }

    function bajar(fondo) {
        if (!fondo || bajador.running)
            return;
        bajando = fondo.id;
        bajador.command = [Quickshell.shellPath("scripts/wallhaven.py"), "bajar", fondo.id, fondo.url];
        bajador.running = true;
    }

    Process {
        id: buscador
        stdout: StdioCollector {
            onStreamFinished: {
                let r;
                try {
                    r = JSON.parse(text);
                } catch (e) {
                    panel.error = "Wallhaven no responde";
                    return;
                }
                if (r.error) {
                    panel.error = r.error;
                    return;
                }
                // Sin repetidos (las listas de populares se mueven entre páginas)
                const vistos = new Set(panel.nuevos.map(f => f.id));
                panel.nuevos = panel.nuevos.concat(r.fondos.filter(f => !vistos.has(f.id)));
                panel.pagina = r.pagina;
                panel.ultima = r.ultima;
            }
        }
    }

    Process {
        id: bajador
        stdout: StdioCollector {
            onStreamFinished: {
                const ruta = text.trim();
                const id = panel.bajando;
                panel.bajando = "";
                if (!ruta.startsWith("/")) {
                    panel.error = "No se pudo bajar el fondo";
                    return;
                }
                panel.nuevos = panel.nuevos.map(f => f.id === id ? Object.assign({}, f, {bajado: true}) : f);
                panel.poner({ruta});
                leer.running = true;
            }
        }
    }

    onAbiertoChanged: {
        if (abierto) {
            // Se puede abrir directamente en Descubrir:
            // qs -c yoru ipc call panel alternar fondos descubrir
            if (Paneles.seccion === "descubrir") {
                vista = "descubrir";
                if (nuevos.length === 0)
                    buscar(consulta);
            }
            cargando = fondos.length === 0;
            leer.running = true;
            actualFile.reload();
            if (vista === "mios")
                rejilla.forceActiveFocus();
            else
                busqueda.forceActiveFocus();
        }
    }

    function poner(fondo) {
        if (!fondo)
            return;
        actual = fondo.ruta;
        Niri.lanzar([casa + "/.config/niri/scripts/wallpaper.sh", fondo.ruta]);
        Paneles.cerrar();
    }

    FileView {
        id: actualFile
        path: panel.casa + "/.cache/wallpaper-actual"
        onLoaded: panel.actual = text().trim()
    }

    Process {
        id: leer
        command: [Quickshell.shellPath("scripts/fondos.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.fondos = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [ruta, miniatura] = l.split("\t");
                    return {ruta, miniatura, nombre: ruta.split("/").pop().replace(/\.[^.]+$/, "")};
                });
                panel.cargando = false;
                const i = panel.fondos.findIndex(f => f.ruta === panel.actual);
                rejilla.currentIndex = Math.max(i, 0);
                rejilla.positionViewAtIndex(rejilla.currentIndex, GridView.Contain);
            }
        }
    }

    Column {
        width: parent.width
        spacing: 12

        Opciones {
            width: parent.width
            opciones: [
                {id: "mios", icono: "󰸉", texto: "Mis fondos"},
                {id: "descubrir", icono: "󰍉", texto: "Descubrir"}
            ]
            valor: panel.vista
            onElegir: id => {
                panel.vista = id;
                if (id === "descubrir") {
                    if (panel.nuevos.length === 0)
                        panel.buscar(panel.consulta);
                    busqueda.forceActiveFocus();
                } else {
                    rejilla.forceActiveFocus();
                }
            }
        }

        Titular {
            visible: panel.vista === "mios"
            width: parent.width
            texto: "Fondos · " + panel.fondos.length

            BotonIcono {
                icono: "󰒝"
                ayuda: "Uno al azar"
                visible: panel.fondos.length > 1
                onClic: panel.poner(panel.fondos[Math.floor(Math.random() * panel.fondos.length)])
            }
        }

        GridView {
            id: rejilla
            visible: panel.vista === "mios"
            width: parent.width
            height: Math.min(Math.ceil(Math.max(panel.fondos.length, 1) / panel.columnas), 3) * cellHeight
            clip: true
            cellWidth: Math.floor(width / panel.columnas)
            cellHeight: cellWidth
            model: panel.fondos
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            keyNavigationWraps: true
            focus: true

            Keys.onReturnPressed: panel.poner(panel.fondos[currentIndex])
            Keys.onEnterPressed: panel.poner(panel.fondos[currentIndex])
            Keys.onEscapePressed: Paneles.cerrar()

            Texto {
                visible: panel.fondos.length === 0
                anchors.centerIn: parent
                text: panel.cargando ? "Preparando miniaturas…"
                    : "No hay fondos: echa imágenes en wallpapers/ o ejecuta wallpapers/descargar.sh"
                font.bold: false
                color: Tema.gris
            }

            delegate: Item {
                id: celda
                required property var modelData
                required property int index
                readonly property bool elegida: GridView.isCurrentItem
                readonly property bool puesto: modelData.ruta === panel.actual
                width: rejilla.cellWidth
                height: rejilla.cellHeight

                Rectangle {
                    anchors { fill: parent; margins: 5 }
                    radius: 12
                    color: Tema.caja
                    border.width: celda.elegida ? 3 : celda.puesto ? 1 : 0
                    border.color: celda.elegida ? Tema.blanco : Tema.claro(0.5)

                    ClippingRectangle {
                        anchors { fill: parent; margins: celda.elegida ? 5 : 3 }
                        radius: 9
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: "file://" + celda.modelData.miniatura
                            sourceSize: Qt.size(256, 256)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: celda.elegida ? 1 : 0.8
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                        }
                    }

                    // El que está puesto ahora
                    Rectangle {
                        visible: celda.puesto
                        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                        width: 24; height: 24; radius: 12
                        color: Tema.blanco
                        Texto {
                            anchors.centerIn: parent
                            text: "󰄬"
                            font.pixelSize: 14
                            color: Tema.oscuro
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: rejilla.currentIndex = celda.index
                    onClicked: panel.poner(celda.modelData)
                }
            }
        }

        Texto {
            visible: panel.vista === "mios"
            leftPadding: 4
            width: parent.width
            elide: Text.ElideRight
            text: (panel.fondos[rejilla.currentIndex]?.nombre ?? "") + "  <font color='" + Tema.gris + "'>·  Enter lo pone  ·  Esc cierra</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
        }

        // --------------------------------------------------------- Descubrir
        Row {
            visible: panel.vista === "descubrir"
            width: parent.width
            spacing: 8

            Rectangle {
                width: 260
                height: 36
                radius: 10
                color: Tema.caja
                border.width: 1
                border.color: busqueda.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

                Texto {
                    id: lupa
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    font.pixelSize: 15
                    color: Tema.gris
                }
                TextInput {
                    id: busqueda
                    anchors { left: lupa.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: Tema.texto
                    selectionColor: Tema.claro(0.3)
                    font.family: Tema.fuente
                    font.pixelSize: 13
                    clip: true
                    onAccepted: panel.buscar(text)
                    Keys.onEscapePressed: Paneles.cerrar()

                    Texto {
                        visible: busqueda.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar en inglés…"
                        font.bold: false
                        font.pixelSize: 12
                        color: Tema.gris
                    }
                }
            }

            Opciones {
                width: parent.width - 260 - parent.spacing
                opciones: panel.temas
                valor: panel.consulta
                onElegir: id => {
                    busqueda.text = "";
                    panel.buscar(id);
                }
            }
        }

        GridView {
            id: descubiertos
            visible: panel.vista === "descubrir"
            width: parent.width
            height: 3 * cellHeight
            clip: true
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.round(cellWidth * 10 / 16)
            model: panel.nuevos
            boundsBehavior: Flickable.StopAtBounds
            // Cerca del final, la página siguiente
            onContentYChanged: if (contentHeight > 0 && contentY + height > contentHeight - cellHeight) panel.mas()

            Texto {
                visible: panel.nuevos.length === 0
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: panel.error !== "" ? "No se pudo buscar: " + panel.error
                    : buscador.running ? "Buscando en Wallhaven…"
                    : "Nada por aquí: prueba con otra palabra"
                font.bold: false
                color: Tema.gris
            }

            delegate: Item {
                id: nuevo
                required property var modelData
                readonly property bool bajandolo: panel.bajando === modelData.id
                width: descubiertos.cellWidth
                height: descubiertos.cellHeight

                Rectangle {
                    anchors { fill: parent; margins: 5 }
                    radius: 12
                    color: Tema.caja
                    border.width: sobre.containsMouse ? 3 : 0
                    border.color: Tema.blanco

                    ClippingRectangle {
                        anchors { fill: parent; margins: sobre.containsMouse ? 5 : 3 }
                        radius: 9
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: nuevo.modelData.miniatura
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: nuevo.bajandolo ? 0.4 : sobre.containsMouse ? 1 : 0.85
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                        }
                    }

                    // Resolución y peso, al pasar el ratón
                    Rectangle {
                        visible: sobre.containsMouse && !nuevo.bajandolo
                        anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
                        width: info.width + 12
                        height: 20
                        radius: 6
                        color: Qt.alpha(Tema.oscuro, 0.75)
                        Texto {
                            id: info
                            anchors.centerIn: parent
                            text: nuevo.modelData.resolucion + " · " + nuevo.modelData.megas + " MB"
                            font.pixelSize: 10
                            font.bold: false
                        }
                    }

                    // Ya lo tienes · o bajándose
                    Rectangle {
                        visible: nuevo.modelData.bajado || nuevo.bajandolo
                        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                        width: 24; height: 24; radius: 12
                        color: Tema.blanco
                        Texto {
                            anchors.centerIn: parent
                            text: nuevo.bajandolo ? "󰇚" : "󰄬"
                            font.pixelSize: 14
                            color: Tema.oscuro
                            SequentialAnimation on opacity {
                                running: nuevo.bajandolo
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 400 }
                                NumberAnimation { to: 1; duration: 400 }
                            }
                        }
                    }
                }

                MouseArea {
                    id: sobre
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.bajar(nuevo.modelData)
                }
            }
        }

        Texto {
            visible: panel.vista === "descubrir"
            leftPadding: 4
            width: parent.width
            elide: Text.ElideRight
            text: (panel.error !== "" && panel.nuevos.length > 0 ? panel.error + "  ·  " : "")
                + "<font color='" + Tema.gris + "'>De wallhaven.cc · clic lo baja y lo pone (queda en Mis fondos)"
                + (buscador.running && panel.nuevos.length > 0 ? "  ·  cargando más…" : "") + "</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
        }
    }
}
