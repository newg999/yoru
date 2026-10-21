// ============================================================================
//  Descubrir — buscar fondos nuevos en wallhaven.cc y ponerlos
//  Está en Ajustes › Fondo (PestanaAjustes.qml). Populares, por tema o por
//  palabra, con scripts/wallhaven.py. Clic = vista previa en grande (← → para
//  pasar, Enter = se baja y se pone, «Volver» = a la rejilla). Lo que bajas
//  queda en tus fondos (~/.local/share/wallpapers) y sale en Mod+Alt+W.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Column {
    id: descubrir
    spacing: 12

    property bool activa: false      // a la vista: la primera vez, busca
    onActivaChanged: if (activa && nuevos.count === 0) buscar(consulta)
    property int filas: 3            // filas de la rejilla que se ven

    function poner(ruta) {
        Niri.lanzar([Quickshell.env("HOME") + "/.config/niri/scripts/wallpaper.sh", ruta]);
    }

    readonly property var temas: [
        {id: "populares", icono: "󰈸", texto: "Populares"},
        {id: "naturaleza", icono: "󰔱", texto: "Naturaleza"},
        {id: "anime", icono: "󰙃", texto: "Anime"},
        {id: "minimalista", icono: "󰝤", texto: "Minimalista"},
        {id: "noche", icono: "󰖔", texto: "Noche"}
    ]
    property string consulta: "populares"   // un tema o lo que se haya escrito
    // Los resultados: {ident, url, miniatura, resolucion, megas, bajado}.
    // Un ListModel y no una lista: al añadir una página se añaden filas y la
    // rejilla se queda donde estabas (con una lista nueva entera, volvía arriba)
    ListModel { id: nuevos }
    property int pagina: 0
    property int ultima: 1
    property string error: ""
    property string bajando: ""      // id del que se está bajando

    function buscar(consulta) {
        consulta = consulta.trim();
        if (consulta === "")
            return;
        descubrir.consulta = consulta;
        nuevos.clear();
        previa = -1;
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

    // Vista previa de Descubrir: índice en «nuevos» (-1 = cerrada)
    property int previa: -1
    property int marcaPrevia: 0      // sube al bajar uno, para que la previa lo vea
    function verPrevia(i) {
        if (i < 0 || i >= nuevos.count)
            return;
        previa = i;
        descubiertos.positionViewAtIndex(i, GridView.Contain);
        // Cerca del final, la página siguiente (como al bajar con la rueda)
        if (i >= nuevos.count - 4)
            mas();
    }
    function usarPrevia() {
        if (previa < 0 || bajador.running)
            return;
        const f = nuevos.get(previa);
        bajar({id: f.ident, url: f.url});
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
                    descubrir.error = "Wallhaven no responde";
                    return;
                }
                if (r.error) {
                    descubrir.error = r.error;
                    return;
                }
                // Sin repetidos (las listas de populares se mueven entre páginas)
                const vistos = new Set();
                for (let i = 0; i < nuevos.count; i++)
                    vistos.add(nuevos.get(i).ident);
                for (const f of r.fondos)
                    if (!vistos.has(f.id))
                        nuevos.append({ident: f.id, url: f.url, miniatura: f.miniatura,
                                       resolucion: f.resolucion, megas: f.megas, bajado: f.bajado});
                descubrir.pagina = r.pagina;
                descubrir.ultima = r.ultima;
            }
        }
    }

    Process {
        id: bajador
        stdout: StdioCollector {
            onStreamFinished: {
                const ruta = text.trim();
                const id = descubrir.bajando;
                descubrir.bajando = "";
                if (!ruta.startsWith("/")) {
                    descubrir.error = "No se pudo bajar el fondo";
                    return;
                }
                for (let i = 0; i < nuevos.count; i++)
                    if (nuevos.get(i).ident === id)
                        nuevos.setProperty(i, "bajado", true);
                descubrir.marcaPrevia++;
                descubrir.poner(ruta);
            }
        }
    }


    // --------------------------------------------------------- Descubrir
    Row {
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
                onAccepted: descubrir.buscar(text)

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
            opciones: descubrir.temas
            valor: descubrir.consulta
            onElegir: id => {
                busqueda.text = "";
                descubrir.buscar(id);
            }
        }
    }

    Item {
        width: parent.width
        height: descubiertos.height

        GridView {
            id: descubiertos
            width: parent.width
            height: descubrir.filas * cellHeight
            clip: true
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.round(cellWidth * 10 / 16)
            model: nuevos
            boundsBehavior: Flickable.StopAtBounds
            // Cerca del final, la página siguiente
            onContentYChanged: if (contentHeight > 0 && contentY + height > contentHeight - cellHeight) descubrir.mas()

            Texto {
                visible: nuevos.count === 0
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: descubrir.error !== "" ? "No se pudo buscar: " + descubrir.error
                    : buscador.running ? "Buscando en Wallhaven…"
                    : "Nada por aquí: prueba con otra palabra"
                font.bold: false
                color: Tema.gris
            }

            delegate: Item {
                id: nuevo
                required property var model
                required property int index
                readonly property var modelData: model
                readonly property bool bajandolo: descubrir.bajando === modelData.ident
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
                    onClicked: descubrir.verPrevia(nuevo.index)
                }
            }
        }

        // ------------------------------------------- Vista previa
        // Clic en una miniatura: el fondo en grande (primero la miniatura,
        // luego el de verdad en cuanto llega). ← → pasan al anterior y al
        // siguiente, Enter lo baja y lo pone, Esc vuelve a la rejilla
        Rectangle {
            id: vistaPrevia
            anchors.fill: parent
            visible: descubrir.previa >= 0
            radius: 12
            color: Tema.sombra(0.97)
            focus: visible
            onVisibleChanged: if (visible) forceActiveFocus(); else busqueda.forceActiveFocus()

            readonly property var fondo: descubrir.previa >= 0 && descubrir.previa < nuevos.count ? nuevos.get(descubrir.previa) : null
            // nuevos.get() no avisa de cambios: se vuelve a mirar al bajarlo
            readonly property bool bajado: descubrir.marcaPrevia >= 0 && (fondo?.bajado ?? false)
            readonly property bool bajandolo: fondo !== null && descubrir.bajando === fondo.ident

            Keys.onEscapePressed: descubrir.previa = -1
            Keys.onLeftPressed: descubrir.verPrevia(descubrir.previa - 1)
            Keys.onRightPressed: descubrir.verPrevia(descubrir.previa + 1)
            Keys.onReturnPressed: descubrir.usarPrevia()
            Keys.onEnterPressed: descubrir.usarPrevia()

            // Que los clics no lleguen a la rejilla de debajo
            MouseArea { anchors.fill: parent }

            ClippingRectangle {
                id: marco
                anchors { fill: parent; margins: 10; bottomMargin: 56 }
                radius: 10
                color: Tema.caja

                Image {
                    anchors.fill: parent
                    source: vistaPrevia.fondo?.miniatura ?? ""
                    fillMode: Image.PreserveAspectFit
                    visible: grande.status !== Image.Ready
                }
                Image {
                    id: grande
                    anchors.fill: parent
                    source: vistaPrevia.fondo?.url ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(width * 1.5, height * 1.5)
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                }
                Rectangle {
                    visible: grande.status === Image.Loading
                    anchors { right: parent.right; top: parent.top; margins: 10 }
                    width: cargaTexto.width + 16
                    height: 24
                    radius: 8
                    color: Tema.sombra(0.75)
                    Texto {
                        id: cargaTexto
                        anchors.centerIn: parent
                        text: "Cargando " + Math.round(grande.progress * 100) + "%"
                        font.pixelSize: 11
                        font.bold: false
                    }
                }
            }

            // Pie: info · anterior / siguiente · cerrar · usar
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
                height: 38

                Texto {
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    text: !vistaPrevia.fondo ? ""
                        : vistaPrevia.fondo.resolucion + "  ·  " + String(vistaPrevia.fondo.megas).replace(".", ",") + " MB"
                          + "  <font color='" + Tema.gris + "'>·  " + (descubrir.previa + 1) + " de " + nuevos.count + "</font>"
                    textFormat: Text.StyledText
                    font.pixelSize: 12
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6

                    BotonIcono {
                        icono: "󰅁"
                        ayuda: "Anterior (←)"
                        visible: descubrir.previa > 0
                        onClic: descubrir.verPrevia(descubrir.previa - 1)
                    }
                    BotonIcono {
                        icono: "󰅂"
                        ayuda: "Siguiente (→)"
                        visible: descubrir.previa < nuevos.count - 1
                        onClic: descubrir.verPrevia(descubrir.previa + 1)
                    }
                    Rectangle {
                        width: textoCerrar.width + 28
                        height: 34
                        radius: 10
                        color: zonaCerrar.containsMouse ? Tema.cajaHover : Tema.caja
                        Texto {
                            id: textoCerrar
                            anchors.centerIn: parent
                            text: "Volver"
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: zonaCerrar
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: descubrir.previa = -1
                        }
                    }
                    Rectangle {
                        width: textoUsar.width + 28
                        height: 34
                        radius: 10
                        color: zonaUsar.containsMouse ? Tema.blanco : Tema.claro(0.9)
                        opacity: vistaPrevia.bajandolo ? 0.6 : 1
                        Texto {
                            id: textoUsar
                            anchors.centerIn: parent
                            text: vistaPrevia.bajandolo ? "󰇚  Bajando…" : vistaPrevia.bajado ? "󰸉  Ponerlo" : "󰸉  Bajarlo y ponerlo"
                            font.pixelSize: 13
                            color: Tema.oscuro
                        }
                        MouseArea {
                            id: zonaUsar
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: descubrir.usarPrevia()
                        }
                    }
                }
            }
        }
    }

    Texto {
        leftPadding: 4
        width: parent.width
        elide: Text.ElideRight
        text: (descubrir.error !== "" && nuevos.count > 0 ? descubrir.error + "  ·  " : "")
            + "<font color='" + Tema.gris + "'>De wallhaven.cc · clic: verlo en grande · Enter lo baja y lo pone (queda en Mis fondos)"
            + (buscador.running && nuevos.count > 0 ? "  ·  cargando más…" : "") + "</font>"
        textFormat: Text.StyledText
        font.pixelSize: 11
    }
}
