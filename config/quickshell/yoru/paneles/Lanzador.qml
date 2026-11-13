// ============================================================================
//  Lanzador de apps — sale por la izquierda, bajo el botón 󰀻 de la barra.
//  Con Mod+Space (sección "medio") sale en mitad de la pantalla, más ancho
//  y con las apps en dos columnas. Con la barra de píldoras (islas arriba o
//  minimalista), no: sale siempre arriba a la izquierda, bajo su ficha 󰍉.
//  Con la de Windows es su Inicio, como el de Windows 11: flota sobre 夜,
//  con el buscador arriba, las apps ancladas (las fijadas en la barra y las
//  que más abres; clic derecho = fijar o quitar), los archivos recientes,
//  «Todas ›» con la lista entera y abajo tú y el botón de apagar.
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
    // (con la barra de Windows, en el centro y flotando sobre ella, como su Inicio)
    lado: medio ? "medio" : Ajustes.windows ? "centro" : "izquierda"
    ancho: medio ? 820 : windows ? 640 : 480
    fundido: false

    readonly property bool windows: Ajustes.windows
    // Inicio de Windows: «Todas ›» (la lista entera, por nombre) y el menú de apagar
    property bool todas: false
    property bool menuApagar: false
    readonly property bool portada: windows && !todas && busqueda.text.trim() === ""

    // (con la barra de Windows, Mod+Space también lo abre sobre 夜)
    readonly property bool medio: Paneles.seccion === "medio" && !Ajustes.conPildoras && !Ajustes.windows
    readonly property int columnas: medio ? 2 : 1

    // Qué sale y cómo se abre: comun/Apps.qml
    readonly property var resultados: windows && todas && busqueda.text.trim() === ""
        ? Apps.buscar("").slice().sort((a, b) => a.name.localeCompare(b.name))
        : Apps.buscar(busqueda.text)

    // Ancladas: las fijadas en la barra y luego las que más abres (hasta 18)
    readonly property var ancladas: {
        const fijas = Favoritos.ids.map(id => DesktopEntries.byId(id)).filter(e => e && !e.noDisplay);
        const resto = Apps.buscar("").filter(a => !fijas.some(f => f.id === a.id));
        return fijas.concat(resto).slice(0, 18);
    }

    // Recomendado: los últimos archivos abiertos (~/.local/share/recently-used.xbel)
    property var recientes: []
    FileView {
        id: xbel
        path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const lista = [];
            const re = /<bookmark href="(file:\/\/[^"]+)"[^>]*?modified="([^"]+)"[\s\S]*?mime-type type="([^"]+)"/g;
            const t = text();
            let m;
            while ((m = re.exec(t)) !== null)
                lista.push({url: m[1], cuando: new Date(m[2]), tipo: m[3]});
            lista.sort((a, b) => b.cuando - a.cuando);
            panel.recientes = lista.slice(0, 6).map(r => {
                let nombre = r.url.substring(r.url.lastIndexOf("/") + 1);
                try { nombre = decodeURIComponent(nombre); } catch (e) {}
                return Object.assign(r, {nombre});
            });
        }
    }
    function haceCuanto(fecha) {
        const min = Math.floor((Date.now() - fecha) / 60000);
        if (min < 1) return "Ahora mismo";
        if (min < 60) return "Hace " + min + " min";
        const h = Math.floor(min / 60);
        if (h < 24) return "Hace " + h + " h";
        const d = Math.floor(h / 24);
        if (d === 1) return "Ayer";
        if (d < 7) return "Hace " + d + " días";
        return Qt.formatDate(fecha, "d MMM");
    }

    // Tu foto (~/.face, solo si existe) y tu nombre
    readonly property string usuario: Quickshell.env("USER") ?? ""
    property bool hayFoto: false
    Process {
        running: panel.windows
        command: ["test", "-f", Quickshell.env("HOME") + "/.face"]
        onExited: codigo => panel.hayFoto = codigo === 0
    }
    function abrir(app) {
        Apps.abrir(app, panel.modelData);
    }

    // Cada vez que se abre, la búsqueda vacía y la lista desde arriba (al
    // abrirse y no al cerrarse: así no cambia mientras se va)
    onAbiertoChanged: {
        if (!abierto)
            return;
        // (lo que se empezó a escribir en el buscador de la isla)
        busqueda.text = Paneles.textoLanzador;
        Paneles.textoLanzador = "";
        busqueda.cursorPosition = busqueda.text.length;
        todas = false;
        menuApagar = false;
        lista.currentIndex = 0;
        lista.positionViewAtBeginning();
    }

    // Título de sección del Inicio de Windows, con su botón a la derecha
    component Cabecera: Item {
        id: cabecera
        property string titulo: ""
        property string boton: ""
        signal pulsado()
        width: parent?.width ?? 0
        height: 28
        Texto {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: cabecera.titulo
            font.pixelSize: 13
        }
        Rectangle {
            visible: cabecera.boton !== ""
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: textoBoton.implicitWidth + 20
            height: 26
            radius: Tema.esquina(6)
            color: botonRaton.containsMouse ? Tema.claro(0.14) : Tema.claro(0.07)
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
            Texto {
                id: textoBoton
                anchors.centerIn: parent
                text: cabecera.boton
                font.pixelSize: 11
            }
            MouseArea {
                id: botonRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cabecera.pulsado()
            }
        }
    }

    Column {
        width: parent.width
        spacing: 12

        // ----------------------------------------------------- Búsqueda
        Rectangle {
            width: parent.width
            height: panel.windows ? 40 : 46
            radius: panel.windows ? Tema.esquina(20) : Tema.esquina(12)
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
                Keys.onReturnPressed: panel.abrir(panel.portada ? panel.ancladas[0] : panel.resultados[lista.currentIndex])
                Keys.onEnterPressed: panel.abrir(panel.portada ? panel.ancladas[0] : panel.resultados[lista.currentIndex])
                Keys.onEscapePressed: {
                    if (panel.menuApagar) panel.menuApagar = false;
                    else if (panel.todas) panel.todas = false;
                    else Paneles.cerrar();
                }

                Texto {
                    visible: busqueda.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.windows ? "Busca apps, ajustes y documentos" : "Buscar apps y ajustes…"
                    font.bold: false
                    font.pixelSize: 14
                    color: Tema.gris
                }
            }
        }

        // ------------------------------------- Inicio de Windows: portada
        Column {
            visible: panel.portada
            width: parent.width
            spacing: 10

            Cabecera {
                titulo: "Anclado"
                boton: "Todas  ›"
                onPulsado: panel.todas = true
            }
            Grid {
                columns: 6
                width: parent.width
                Repeater {
                    model: panel.ancladas
                    Rectangle {
                        id: anclada
                        required property var modelData
                        width: parent.width / 6
                        height: 80
                        radius: Tema.esquina(8)
                        color: ancladaRaton.containsMouse ? Tema.claro(0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        MouseArea {
                            id: ancladaRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => e.button === Qt.RightButton ? Favoritos.alternar(anclada.modelData.id)
                                : panel.abrir(anclada.modelData)
                        }
                        IconImage {
                            id: iconoAnclada
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
                            implicitSize: 32
                            source: Quickshell.iconPath(anclada.modelData.icon, true) || Quickshell.iconPath("application-x-executable")
                            asynchronous: true
                            scale: ancladaRaton.pressed ? 0.85 : ancladaRaton.containsMouse ? 1.08 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.rebote * 0.7; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                        }
                        // La fijada en la barra lleva un puntito
                        Rectangle {
                            visible: Favoritos.contiene(anclada.modelData.id)
                            anchors { left: iconoAnclada.right; leftMargin: 1; top: iconoAnclada.top }
                            width: 5; height: 5; radius: 2.5
                            color: Tema.claro(0.45)
                        }
                        Texto {
                            anchors { left: parent.left; right: parent.right; top: iconoAnclada.bottom; topMargin: 8; margins: 4 }
                            horizontalAlignment: Text.AlignHCenter
                            text: anclada.modelData.name
                            elide: Text.ElideRight
                            font.bold: false
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Item { width: 1; height: 4 }
            Cabecera {
                visible: panel.recientes.length > 0
                titulo: "Recomendado"
            }
            Grid {
                visible: panel.recientes.length > 0
                columns: 2
                width: parent.width
                Repeater {
                    model: panel.recientes
                    Rectangle {
                        id: reciente
                        required property var modelData
                        width: parent.width / 2
                        height: 50
                        radius: Tema.esquina(8)
                        color: recienteRaton.containsMouse ? Tema.claro(0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        MouseArea {
                            id: recienteRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Niri.lanzar(["xdg-open", reciente.modelData.url]);
                                Paneles.cerrar();
                            }
                        }
                        IconImage {
                            id: iconoReciente
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            implicitSize: 28
                            source: Quickshell.iconPath(reciente.modelData.tipo.replace("/", "-"), true)
                                || Quickshell.iconPath(reciente.modelData.tipo.split("/")[0] + "-x-generic", true)
                                || Quickshell.iconPath("text-x-generic")
                            asynchronous: true
                        }
                        Column {
                            anchors { left: iconoReciente.right; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            Texto {
                                width: parent.width
                                text: reciente.modelData.nombre
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                font.pixelSize: 12
                            }
                            Texto {
                                text: panel.haceCuanto(reciente.modelData.cuando)
                                font.bold: false
                                font.pixelSize: 10
                                color: Tema.gris
                            }
                        }
                    }
                }
            }
        }

        // Todas: volver a la portada
        Cabecera {
            visible: panel.windows && panel.todas && busqueda.text.trim() === ""
            titulo: "Todas"
            boton: "‹  Atrás"
            onPulsado: panel.todas = false
        }

        Texto {
            visible: !panel.windows || (!panel.portada && !panel.todas) || busqueda.text.trim() !== ""
            leftPadding: 4
            text: "󰀻  " + (busqueda.text.trim() === "" ? "Aplicaciones" : "Apps y ajustes") + "  <font color='" + Tema.gris + "'>" + panel.resultados.length + "</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
            color: Tema.gris
        }

        // --------------------------------------------------------- Lista
        GridView {
            id: lista
            visible: !panel.portada
            width: parent.width
            // 560, o menos si la pantalla es pequeña (117 = resto del panel,
            // y en el Inicio de Windows lo de abajo), en filas enteras: sin
            // una a medias cortada abajo
            height: Math.floor(Math.min(panel.windows ? 430 : 560, panel.altoMax - 117 - (panel.windows ? 140 : 0)) / cellHeight) * cellHeight - 2
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

            Vacio {
                visible: panel.resultados.length === 0
                anchors.centerIn: parent
                icono: "󰍉"
                titulo: "No hay nada que se llame así"
                detalle: "Prueba con otra palabra, o búscalo en la Tienda (Mod+Alt+S)"
            }

            delegate: Rectangle {
                id: fila
                required property var modelData
                required property int index
                readonly property bool elegida: GridView.isCurrentItem
                width: lista.cellWidth - (panel.columnas > 1 ? 4 : 0)
                height: 56
                radius: Tema.esquina(10)
                color: "transparent"
                Seleccion { activa: fila.elegida; radio: fila.radius }

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
                    color: Tema.caja
                    Texto {
                        anchors.centerIn: parent
                        text: fila.modelData.glifo ?? ""
                        font.pixelSize: 18
                        color: fila.elegida ? Tema.blanco : Tema.texto
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
                        color: fila.elegida ? Tema.blanco : Tema.texto
                    }
                    Texto {
                        width: parent.width
                        visible: text !== ""
                        text: fila.modelData.comment || fila.modelData.genericName || ""
                        elide: Text.ElideRight
                        font.bold: false
                        font.pixelSize: 11
                        color: Tema.gris
                    }
                }
            }
        }

        // ------------------------------- Inicio de Windows: tú y apagar
        Item {
            visible: panel.windows
            width: parent.width
            height: 52

            // La raya de lado a lado, por encima
            Rectangle {
                x: -16
                width: parent.width + 32
                height: 1
                color: Tema.claro(0.08)
            }

            Row {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                spacing: 12
                ClippingRectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Tema.claro(0.10)
                    Texto {
                        anchors.centerIn: parent
                        visible: foto.status !== Image.Ready
                        text: panel.usuario.charAt(0).toUpperCase()
                        font.pixelSize: 14
                        color: Tema.blanco
                    }
                    Image {
                        id: foto
                        anchors.fill: parent
                        source: panel.hayFoto ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.usuario
                    font.pixelSize: 13
                }
            }

            Rectangle {
                id: apagar
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                width: 36
                height: 36
                radius: Tema.esquina(8)
                color: panel.menuApagar ? Tema.claro(0.14) : apagarRaton.containsMouse ? Tema.claro(0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
                Texto {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.pixelSize: 17
                    scale: apagarRaton.pressed ? 0.85 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.rebote * 0.6; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                }
                MouseArea {
                    id: apagarRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.menuApagar = !panel.menuApagar
                }

                // El menú de apagar, encima del botón (comun/Sesion.qml)
                Rectangle {
                    visible: opacity > 0
                    opacity: panel.menuApagar ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                    anchors { right: parent.right; bottom: parent.top; bottomMargin: 6 + (panel.menuApagar ? 0 : -8) }
                    Behavior on anchors.bottomMargin { NumberAnimation { duration: Tema.rebote * 0.7; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                    width: 190
                    height: opcionesApagar.implicitHeight + 12
                    radius: Tema.esquina(10)
                    color: Tema.panel
                    border.width: Tema.borde(1)
                    border.color: Tema.claro(0.18)
                    z: 10
                    Column {
                        id: opcionesApagar
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                        spacing: 2
                        Repeater {
                            model: Sesion.opciones
                            Fila {
                                required property var modelData
                                width: opcionesApagar.width
                                icono: modelData.icono
                                titulo: modelData.titulo
                                onClic: Sesion.elegir(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
