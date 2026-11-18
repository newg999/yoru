// ============================================================================
//  VentanaMusica — «Música de Yoru», el reproductor de la música local
//  Una ventana normal de niri, como los Ajustes (VentanaAjustes.qml):
//
//    ┌──────────┬─────────────────────────────────┬──────────┐
//    │ Música   │  Discos                         │ A        │
//    │ [buscar] │  ┌────┐ ┌────┐ ┌────┐ ┌────┐    │ continua-│
//    │ Discos   │  │    │ │    │ │    │ │    │    │ ción     │
//    │ Artistas │  └────┘ └────┘ └────┘ └────┘    │ (la cola)│
//    │ Géneros  │                                 │          │
//    │ Canciones│                                 │          │
//    ├──────────┴─────────────────────────────────┴──────────┤
//    │ ▣ Canción · Artista     ⤮ ⏮ ⏯ ⏭ ⟳  ━━━━○────    🔊 ☰ │
//    └───────────────────────────────────────────────────────┘
//
//  Todo lo de sonar lo hace comun/Tocadiscos.qml (un mpv aparte): cerrar la
//  ventana no para la música; se sigue manejando desde la isla.
//  Se abre con Mod+M, «Música» en el lanzador o «yoru musica».
//  Teclas: Espacio = pausa · ←/→ = 5 s · Ctrl+F = buscar · Esc = atrás/cerrar
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Scope {
    LazyLoader {
        active: Paneles.musicaAbierta

        FloatingWindow {
            id: ventana

            title: Paneles.tituloMusica
            implicitWidth: Math.max(860, Tocadiscos.sitio.ancho)
            implicitHeight: Math.max(520, Tocadiscos.sitio.alto)
            minimumSize: Qt.size(860, 520)
            color: Tema.panel
            visible: true
            onVisibleChanged: if (!visible) Paneles.musicaAbierta = false
            Component.onCompleted: Tocadiscos.ponerAlDia()

            // ------------------------------- Abrirse donde la dejaste
            // niri no deja a una app elegir su sitio: al aparecer, se le
            // pide que la mueva (y que la haga columna si no era flotante).
            // Luego, cada cambio de tamaño o de sitio se guarda
            readonly property var enNiri: Object.values(Niri.ventanas).find(v => v.title === Paneles.tituloMusica) ?? null
            property bool colocada: false
            onEnNiriChanged: {
                if (!enNiri)
                    return;
                if (!colocada) {
                    const s = Tocadiscos.sitio, id = String(enNiri.id);
                    const p = enNiri.layout?.tile_pos_in_workspace_view;
                    if (s.flotante && !p)
                        return;     // aún no tiene sitio: al siguiente aviso
                    colocada = true;
                    if (!s.flotante)
                        Niri.accion("toggle-window-floating", "--id", id);
                    else if (s.x >= 0 && s.y >= 0) {
                        // Se mueve lo que falta desde donde ha salido: «-x 100»
                        // cuenta desde debajo de la barra, pero niri dice la
                        // posición desde el borde de la pantalla
                        const paso = n => (n >= 0 ? "+" : "") + Math.round(n);
                        Niri.accion("move-floating-window", "--id", id,
                            "-x", paso(s.x - p[0]), "-y", paso(s.y - p[1]));
                    }
                    return;
                }
                guardarSitio.restart();
            }
            // Se le pregunta a niri: la posición de sus avisos
            // (WindowLayoutsChanged) no siempre es la buena al moverla
            Timer {
                id: guardarSitio
                interval: 400
                onTriggered: preguntar.running = true
            }
            Process {
                id: preguntar
                command: ["niri", "msg", "-j", "windows"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let v = null;
                        try { v = JSON.parse(text).find(w => w.title === Paneles.tituloMusica); } catch (e) {}
                        const l = v?.layout;
                        if (!l)
                            return;
                        const s = Tocadiscos.sitio;
                        s.flotante = v.is_floating === true;
                        if (!s.flotante)
                            return;     // como columna, el tamaño lo pone niri
                        s.ancho = Math.round(l.window_size[0]);
                        s.alto = Math.round(l.window_size[1]);
                        if (l.tile_pos_in_workspace_view) {
                            s.x = Math.round(l.tile_pos_in_workspace_view[0]);
                            s.y = Math.round(l.tile_pos_in_workspace_view[1]);
                        }
                    }
                }
            }

            // ------------------------------------------------ Qué se ve
            // "discos" | "artistas" | "generos" | "canciones" | "disco"
            property string vista: "discos"
            property var disco: null               // en la vista "disco"
            property string filtroCampo: ""        // "artista" | "genero"
            property string filtroValor: ""
            property bool verCola: true
            property var historial: []             // para volver con Esc / ‹

            function ir(v, extra) {
                historial = historial.concat([{vista, disco, filtroCampo, filtroValor}]);
                vista = v;
                if (v === "disco")
                    disco = extra;
                else if (extra) {
                    filtroCampo = extra.campo;
                    filtroValor = extra.valor;
                } else {
                    filtroCampo = "";
                    filtroValor = "";
                }
                contenido.arriba();
            }
            function seccion(v) {
                historial = [];
                buscador.text = "";
                vista = v;
                filtroCampo = "";
                filtroValor = "";
                contenido.arriba();
            }
            function volver() {
                if (historial.length === 0)
                    return false;
                const h = historial[historial.length - 1];
                historial = historial.slice(0, -1);
                vista = h.vista;
                disco = h.disco;
                filtroCampo = h.filtroCampo;
                filtroValor = h.filtroValor;
                return true;
            }
            function verDisco(id) {
                const d = Tocadiscos.porDisco[id];
                if (d)
                    ir("disco", d);
            }

            // ------------------------------------------------ Buscar
            readonly property string buscado: buscador.text.trim()
            function sinTildes(t) {
                return String(t ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
            }
            readonly property string q: sinTildes(buscado)
            readonly property var discosVistos: {
                let l = Tocadiscos.discos;
                if (filtroCampo)
                    l = l.filter(d => (d[filtroCampo] || "Desconocido") === filtroValor);
                if (q)
                    l = l.filter(d => sinTildes(d.titulo + " " + d.artista + " " + d.genero).includes(q));
                return l;
            }
            readonly property var cancionesVistas: q
                ? Tocadiscos.canciones.filter(c => sinTildes(c.titulo + " " + c.artista + " " + c.album).includes(q))
                : Tocadiscos.canciones
            readonly property var gruposVistos: {
                const l = vista === "generos" ? Tocadiscos.generos : Tocadiscos.artistas;
                return q ? l.filter(a => sinTildes(a.nombre).includes(q)) : l;
            }

            // ------------------------------------------------ Teclado
            Shortcut { sequence: "Space"; onActivated: Tocadiscos.pausa() }
            Shortcut { sequence: "Right"; onActivated: Tocadiscos.avanzar(5) }
            Shortcut { sequence: "Left"; onActivated: Tocadiscos.avanzar(-5) }
            Shortcut { sequence: "Ctrl+F"; onActivated: buscador.forceActiveFocus() }
            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (menu.visible)
                        menu.cerrar();
                    else if (buscador.text !== "")
                        buscador.text = "";
                    else if (!ventana.volver())
                        Paneles.musicaAbierta = false;
                }
            }

            // ======================================================== Lateral
            Rectangle {
                id: lateral
                anchors { left: parent.left; top: parent.top; bottom: barra.top }
                width: 230
                color: Tema.claro(0.03)
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Tema.claro(0.08)
                }

                Column {
                    anchors { fill: parent; margins: 14; topMargin: 22; rightMargin: 15 }
                    spacing: 4

                    Row {
                        leftPadding: 6
                        bottomPadding: 16
                        spacing: 12
                        Rectangle {
                            width: 40; height: 40
                            radius: Tema.esquina(12)
                            color: Tema.claro(0.10)
                            border.width: 1
                            border.color: Tema.claro(0.15)
                            Texto { anchors.centerIn: parent; text: "󰝚"; font.pixelSize: 20; color: Tema.blanco }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Texto { text: "Música"; font.pixelSize: 15; color: Tema.blanco }
                            Texto {
                                text: Tocadiscos.canciones.length + " canciones"
                                font.pixelSize: 11
                                font.bold: false
                                color: Tema.gris
                            }
                        }
                    }

                    // Buscador
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: Tema.esquina(10)
                        color: Tema.caja
                        border.width: 1
                        border.color: buscador.activeFocus ? Tema.claro(0.5) : Tema.claro(0.08)
                        Texto {
                            id: lupa
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: "󰍉"
                            font.pixelSize: 14
                            color: Tema.gris
                        }
                        TextInput {
                            id: buscador
                            anchors { left: lupa.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            color: Tema.texto
                            selectionColor: Tema.claro(0.3)
                            font.family: Tema.fuente
                            font.pixelSize: 13
                            clip: true
                            // Buscar en Discos o Artistas sale de un disco
                            onTextChanged: if (text !== "" && ventana.vista === "disco") ventana.volver()
                            Texto {
                                visible: buscador.text === ""
                                text: "Buscar"
                                font.pixelSize: 13
                                font.bold: false
                                color: Tema.tenue
                            }
                        }
                    }
                    Item { width: 1; height: 10 }

                    Repeater {
                        model: [
                            {id: "discos", icono: "󰀥", texto: "Discos"},
                            {id: "artistas", icono: "󰠃", texto: "Artistas"},
                            {id: "generos", icono: "󰲸", texto: "Géneros"},
                            {id: "canciones", icono: "󰎈", texto: "Canciones"}
                        ]
                        Rectangle {
                            id: fila
                            required property var modelData
                            readonly property bool elegida: ventana.vista === modelData.id
                                || (modelData.id === "discos" && ventana.vista === "disco")
                            width: parent.width
                            height: 38
                            radius: Tema.esquina(10)
                            color: !elegida && filaRaton.containsMouse ? Tema.cajaHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            Seleccion { activa: fila.elegida; radio: fila.radius }
                            Row {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 14
                                Texto {
                                    width: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: fila.modelData.icono
                                    font.pixelSize: 17
                                    color: fila.elegida ? Tema.blanco : Tema.texto
                                }
                                Texto {
                                    text: fila.modelData.texto
                                    font.pixelSize: 14
                                    color: fila.elegida ? Tema.blanco : Tema.texto
                                }
                            }
                            MouseArea {
                                id: filaRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ventana.seccion(fila.modelData.id)
                            }
                        }
                    }
                }

                // Abajo: si se está poniendo al día o falta una carpeta
                Column {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
                    spacing: 6
                    Row {
                        visible: Tocadiscos.sinMontar.length > 0
                        width: parent.width
                        spacing: 8
                        Texto { text: "󰀦"; font.pixelSize: 13; color: Tema.amarillo }
                        Texto {
                            width: parent.width - 22
                            text: "El NAS no está montado: se ve lo que había"
                            wrapMode: Text.Wrap
                            font.pixelSize: 11
                            font.bold: false
                            color: Tema.gris
                        }
                    }
                    Row {
                        spacing: 8
                        Texto {
                            id: girar
                            text: "󰑓"
                            font.pixelSize: 13
                            color: Tocadiscos.escaneando ? Tema.blanco : Tema.gris
                            RotationAnimation on rotation {
                                running: Tocadiscos.escaneando
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                                onRunningChanged: if (!running) girar.rotation = 0
                            }
                            MouseArea {
                                anchors { fill: parent; margins: -6 }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Tocadiscos.escanear()
                            }
                        }
                        Texto {
                            text: Tocadiscos.escaneando
                                ? (Tocadiscos.leidas > 0 ? "Leyendo canciones nuevas… " + Tocadiscos.leidas : "Buscando cambios…")
                                : "Biblioteca al día"
                            font.pixelSize: 11
                            font.bold: false
                            color: Tema.gris
                        }
                    }
                }
            }

            // ======================================================== Contenido
            Item {
                id: contenido
                anchors { left: lateral.right; right: cola.left; top: parent.top; bottom: barra.top }
                clip: true
                function arriba() {
                    rejilla.contentY = rejilla.originY;
                    listaGrupos.contentY = listaGrupos.originY;
                    listaCanciones.positionViewAtBeginning();
                    listaDisco.positionViewAtBeginning();
                }

                // Título de la vista (y «‹» si se puede volver)
                Row {
                    id: cabecera
                    visible: ventana.vista !== "disco"
                    x: 32; y: 26
                    spacing: 10
                    BotonIcono {
                        visible: ventana.historial.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        icono: "󰁍"
                        onClic: ventana.volver()
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ventana.filtroValor !== "" ? ventana.filtroValor
                            : ({discos: "Discos", artistas: "Artistas", generos: "Géneros", canciones: "Canciones"})[ventana.vista] ?? ""
                        font.pixelSize: 26
                        color: Tema.blanco
                    }
                    Texto {
                        anchors.baseline: parent.children[1].baseline
                        text: ventana.vista === "discos" ? ventana.discosVistos.length + " discos"
                            : ventana.vista === "canciones" ? ventana.cancionesVistas.length + " canciones"
                            : ventana.gruposVistos.length + ""
                        font.pixelSize: 12
                        font.bold: false
                        color: Tema.gris
                    }
                }
                // Reproducir todo lo que se ve
                Row {
                    visible: cabecera.visible && (ventana.vista === "discos" || ventana.vista === "canciones")
                    anchors { right: parent.right; rightMargin: 32; verticalCenter: cabecera.verticalCenter }
                    spacing: 8
                    Boton {
                        icono: "󰐊"; texto: "Reproducir"; principal: true
                        onClic: Tocadiscos.reproducir(ventana.rutasVistas(), 0)
                    }
                    Boton {
                        icono: "󰒝"; texto: "Aleatorio"
                        onClic: ventana.aleatorioDe(ventana.rutasVistas())
                    }
                }

                // --------------------------------------------- Discos
                GridView {
                    id: rejilla
                    visible: ventana.vista === "discos"
                    anchors { fill: parent; topMargin: 80; leftMargin: 24; rightMargin: 16 }
                    readonly property int columnas: Math.max(2, Math.floor(width / 196))
                    cellWidth: Math.floor(width / columnas)
                    cellHeight: cellWidth + 56
                    model: visible ? ventana.discosVistos : []
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 600
                    delegate: TarjetaDisco {
                        width: rejilla.cellWidth
                        height: rejilla.cellHeight
                    }
                    Vacio {
                        visible: rejilla.count === 0
                        anchors.centerIn: parent
                        icono: Tocadiscos.discos.length === 0 ? "󰝚" : "󰍉"
                        titulo: Tocadiscos.discos.length === 0
                            ? (Tocadiscos.escaneando ? "Leyendo la biblioteca" : "No hay música")
                            : "Nada con «" + ventana.buscado + "»"
                        detalle: Tocadiscos.discos.length === 0
                            ? (Tocadiscos.escaneando ? "La primera vez tarda un rato" : "Elige las carpetas en Ajustes › Apps") : ""
                    }
                }

                // ------------------------------------- Artistas / Géneros
                ListView {
                    id: listaGrupos
                    visible: ventana.vista === "artistas" || ventana.vista === "generos"
                    anchors { fill: parent; topMargin: 80; leftMargin: 24; rightMargin: 24; bottomMargin: 8 }
                    model: visible ? ventana.gruposVistos : []
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2
                    delegate: Rectangle {
                        id: grupo
                        required property var modelData
                        width: listaGrupos.width
                        height: 52
                        radius: Tema.esquina(10)
                        color: grupoRaton.containsMouse ? Tema.cajaHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        // Las carátulas de sus primeros discos, en abanico
                        Item {
                            id: mini
                            x: 10
                            width: 72; height: 40
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property var suyos: Tocadiscos.discos.filter(d =>
                                (d[ventana.vista === "generos" ? "genero" : "artista"] || "Desconocido") === grupo.modelData.nombre && d.caratula).slice(0, 3)
                            Repeater {
                                model: mini.suyos
                                ClippingRectangle {
                                    required property var modelData
                                    required property int index
                                    x: index * 16
                                    z: 3 - index
                                    width: 40; height: 40
                                    radius: Tema.esquina(6)
                                    color: Tema.caja
                                    border.width: 1
                                    border.color: Tema.sombra(0.6)
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + modelData.caratula
                                        sourceSize: Qt.size(80, 80)
                                        asynchronous: true
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                            }
                        }
                        Texto {
                            anchors { left: mini.right; leftMargin: 18; verticalCenter: parent.verticalCenter }
                            text: grupo.modelData.nombre
                            font.pixelSize: 14
                            color: Tema.texto
                        }
                        Texto {
                            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            text: grupo.modelData.discos + (grupo.modelData.discos === 1 ? " disco" : " discos")
                            font.pixelSize: 12
                            font.bold: false
                            color: Tema.gris
                        }
                        MouseArea {
                            id: grupoRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            readonly property string campo: ventana.vista === "generos" ? "genero" : "artista"
                            onClicked: e => {
                                const sus = Tocadiscos.discos.filter(d => (d[campo] || "Desconocido") === grupo.modelData.nombre);
                                if (e.button === Qt.RightButton)
                                    menu.abrir(Tocadiscos.rutasDe(sus), mapToItem(ventana.contentItem, e.x, e.y), null);
                                else
                                    ventana.ir("discos", {campo, valor: grupo.modelData.nombre});
                            }
                        }
                    }
                }

                // ------------------------------------------- Canciones
                ListView {
                    id: listaCanciones
                    visible: ventana.vista === "canciones"
                    anchors { fill: parent; topMargin: 80; leftMargin: 24; rightMargin: 24; bottomMargin: 8 }
                    model: visible ? ventana.cancionesVistas : []
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 800
                    delegate: FilaCancion {
                        width: listaCanciones.width
                        conDisco: true
                        lista: ventana.cancionesVistas
                    }
                }

                // ----------------------------------------------- Un disco
                ListView {
                    id: listaDisco
                    visible: ventana.vista === "disco"
                    anchors { fill: parent; leftMargin: 24; rightMargin: 24; bottomMargin: 8 }
                    readonly property var canciones: ventana.disco
                        ? ventana.disco.canciones.map(r => Tocadiscos.porRuta[r]).filter(c => c) : []
                    model: visible ? canciones : []
                    boundsBehavior: Flickable.StopAtBounds
                    header: Item {
                        width: listaDisco.width
                        height: 300
                        BotonIcono {
                            x: 0; y: 22
                            icono: "󰁍"
                            onClic: ventana.volver() || ventana.seccion("discos")
                        }
                        ClippingRectangle {
                            id: portada
                            x: 44; y: 44
                            width: 220; height: 220
                            radius: Tema.esquina(12)
                            color: Tema.caja
                            border.width: 1
                            border.color: Tema.claro(0.08)
                            Texto {
                                anchors.centerIn: parent
                                visible: !(ventana.disco?.caratula)
                                text: "󰀥"; font.pixelSize: 64; color: Tema.tenue
                            }
                            Image {
                                anchors.fill: parent
                                source: ventana.disco?.caratula ? "file://" + ventana.disco.caratula : ""
                                sourceSize: Qt.size(440, 440)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                        Column {
                            anchors { left: portada.right; leftMargin: 28; right: parent.right; bottom: portada.bottom }
                            spacing: 6
                            Texto {
                                text: "DISCO" + (ventana.disco?.genero ? "  ·  " + ventana.disco.genero.toUpperCase() : "")
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                color: Tema.gris
                            }
                            Texto {
                                width: parent.width
                                text: ventana.disco?.titulo ?? ""
                                font.pixelSize: 30
                                color: Tema.blanco
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            Texto {
                                text: ventana.disco?.artista ?? ""
                                font.pixelSize: 15
                                color: Tema.texto
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ventana.ir("discos", {campo: "artista", valor: ventana.disco.artista})
                                }
                            }
                            Texto {
                                text: [ventana.disco?.anio, listaDisco.count + (listaDisco.count === 1 ? " canción" : " canciones"),
                                    Tocadiscos.tiempo(ventana.disco?.duracion)].filter(x => x).join("  ·  ")
                                font.pixelSize: 12
                                font.bold: false
                                color: Tema.gris
                            }
                            Item { width: 1; height: 8 }
                            Row {
                                spacing: 8
                                Boton {
                                    icono: "󰐊"; texto: "Reproducir"; principal: true
                                    onClic: Tocadiscos.reproducir(ventana.disco.canciones, 0)
                                }
                                Boton {
                                    icono: "󰒝"; texto: "Aleatorio"
                                    onClic: ventana.aleatorioDe(ventana.disco.canciones)
                                }
                                Boton {
                                    icono: "󰐒"; texto: "A la cola"
                                    onClic: Tocadiscos.anadir(ventana.disco.canciones)
                                }
                            }
                        }
                    }
                    delegate: FilaCancion {
                        width: listaDisco.width
                        lista: listaDisco.canciones
                    }
                }
            }

            function rutasVistas() {
                return vista === "canciones" ? cancionesVistas.map(c => c.ruta) : Tocadiscos.rutasDe(discosVistos);
            }
            function aleatorioDe(rutas) {
                const r = rutas.slice();
                for (let i = r.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [r[i], r[j]] = [r[j], r[i]];
                }
                Tocadiscos.reproducir(r, 0);
            }

            // ======================================================== La cola
            Rectangle {
                id: cola
                anchors { right: parent.right; top: parent.top; bottom: barra.top }
                width: ventana.verCola ? 300 : 0
                Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                clip: true
                color: Tema.claro(0.03)
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Tema.claro(0.08)
                }
                Texto {
                    id: tituloCola
                    x: 22; y: 30
                    text: "A continuación"
                    font.pixelSize: 15
                    color: Tema.blanco
                }
                Texto {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: tituloCola.verticalCenter }
                    visible: Tocadiscos.cola.length > 0
                    text: "Vaciar"
                    font.pixelSize: 12
                    font.bold: false
                    color: vaciarRaton.containsMouse ? Tema.blanco : Tema.gris
                    MouseArea {
                        id: vaciarRaton
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Tocadiscos.vaciar()
                    }
                }
                ListView {
                    id: listaCola
                    anchors { fill: parent; topMargin: 64; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                    model: Tocadiscos.cola
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    currentIndex: Tocadiscos.indiceCola
                    onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        id: enCola
                        required property var modelData
                        required property int index
                        readonly property var c: Tocadiscos.porRuta[modelData.ruta] ?? {titulo: modelData.ruta.split("/").pop(), artista: ""}
                        readonly property bool suena: index === Tocadiscos.indiceCola
                        width: listaCola.width
                        height: 48
                        radius: Tema.esquina(8)
                        color: !suena && encima.hovered ? Tema.cajaHover : "transparent"
                        Seleccion { activa: enCola.suena; radio: enCola.radius }
                        HoverHandler { id: encima }
                        ClippingRectangle {
                            id: miniCola
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34; height: 34
                            radius: Tema.esquina(5)
                            color: Tema.caja
                            readonly property string img: Tocadiscos.porDisco[enCola.c.disco_id]?.caratula ?? ""
                            Image {
                                anchors.fill: parent
                                visible: miniCola.img !== ""
                                source: miniCola.img ? "file://" + miniCola.img : ""
                                sourceSize: Qt.size(68, 68)
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                        Column {
                            anchors { left: miniCola.right; leftMargin: 10; right: quitar.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            Texto {
                                width: parent.width
                                text: enCola.c.titulo
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: enCola.suena ? Tema.blanco : Tema.texto
                            }
                            Texto {
                                width: parent.width
                                text: enCola.c.artista
                                elide: Text.ElideRight
                                font.pixelSize: 11
                                font.bold: false
                                color: Tema.gris
                            }
                        }
                        MouseArea {
                            id: colaRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            onDoubleClicked: Tocadiscos.saltar(enCola.index)
                        }
                        BotonIcono {
                            id: quitar
                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            width: 26; height: 26
                            visible: encima.hovered
                            icono: "󰅖"
                            colorIcono: Tema.gris
                            onClic: Tocadiscos.quitar(enCola.index)
                        }
                    }
                    Vacio {
                        visible: listaCola.count === 0
                        anchors.centerIn: parent
                        icono: "󰲸"
                        titulo: "La cola está vacía"
                        detalle: "Lo que pongas a sonar sale aquí"
                    }
                }
            }

            // ======================================================== Barra de abajo
            Rectangle {
                id: barra
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 92
                color: Tema.claro(0.04)
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 1
                    color: Tema.claro(0.08)
                }

                // Lo que suena
                Item {
                    id: queSuena
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    width: Math.min(340, parent.width * 0.28)
                    height: 60
                    ClippingRectangle {
                        id: caratula
                        width: 60; height: 60
                        radius: Tema.esquina(8)
                        color: Tema.caja
                        border.width: 1
                        border.color: Tema.claro(0.08)
                        Texto {
                            anchors.centerIn: parent
                            visible: !(Tocadiscos.discoActual?.caratula)
                            text: "󰝚"; font.pixelSize: 22; color: Tema.tenue
                        }
                        Image {
                            anchors.fill: parent
                            source: Tocadiscos.discoActual?.caratula ? "file://" + Tocadiscos.discoActual.caratula : ""
                            sourceSize: Qt.size(120, 120)
                            fillMode: Image.PreserveAspectCrop
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Tocadiscos.discoActual ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (Tocadiscos.discoActual) ventana.verDisco(Tocadiscos.discoActual.id)
                        }
                    }
                    Column {
                        anchors { left: caratula.right; leftMargin: 14; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Texto {
                            width: parent.width
                            text: Tocadiscos.actual?.titulo ?? "Nada sonando"
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            color: Tocadiscos.actual ? Tema.blanco : Tema.gris
                        }
                        Texto {
                            width: parent.width
                            text: Tocadiscos.actual ? [Tocadiscos.actual.artista, Tocadiscos.actual.album].filter(x => x).join("  ·  ") : "Elige un disco o una canción"
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            font.bold: false
                            color: Tema.gris
                        }
                    }
                }

                // Botones y progreso, en el centro
                Column {
                    anchors.centerIn: parent
                    width: Math.min(560, parent.width - 2 * queSuena.width - 80)
                    spacing: 4
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14
                        BotonIcono {
                            anchors.verticalCenter: parent.verticalCenter
                            icono: "󰒝"
                            colorIcono: Tocadiscos.aleatorio ? Tema.blanco : Tema.gris
                            onClic: Tocadiscos.alternarAleatorio()
                            Rectangle {
                                visible: Tocadiscos.aleatorio
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                                width: 4; height: 4; radius: 2
                                color: Tema.blanco
                            }
                        }
                        BotonIcono {
                            anchors.verticalCenter: parent.verticalCenter
                            icono: "󰒮"
                            onClic: Tocadiscos.anterior()
                        }
                        // Reproducir / pausa: un círculo claro
                        Rectangle {
                            width: 40; height: 40
                            radius: 20
                            color: playRaton.containsMouse ? Tema.blanco : Tema.claro(0.88)
                            scale: playRaton.pressed ? 0.92 : 1
                            Behavior on scale { NumberAnimation { duration: Tema.rapida } }
                            Texto {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: Tocadiscos.sonando ? 0 : 1
                                text: Tocadiscos.sonando ? "󰏤" : "󰐊"
                                font.pixelSize: 20
                                color: Tema.oscuro
                            }
                            MouseArea {
                                id: playRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Tocadiscos.pausa()
                            }
                        }
                        BotonIcono {
                            anchors.verticalCenter: parent.verticalCenter
                            icono: "󰒭"
                            onClic: Tocadiscos.siguiente()
                        }
                        BotonIcono {
                            anchors.verticalCenter: parent.verticalCenter
                            icono: Tocadiscos.repetir === "una" ? "󰑘" : "󰑖"
                            colorIcono: Tocadiscos.repetir !== "no" ? Tema.blanco : Tema.gris
                            onClic: Tocadiscos.alternarRepetir()
                            Rectangle {
                                visible: Tocadiscos.repetir !== "no"
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                                width: 4; height: 4; radius: 2
                                color: Tema.blanco
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        Texto {
                            width: 40
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Tocadiscos.tiempo(progreso.arrastrando ? progreso.mostrado * Tocadiscos.duracion : Tocadiscos.posicion)
                            font.pixelSize: 11
                            font.bold: false
                            color: Tema.gris
                        }
                        Deslizador {
                            id: progreso
                            width: parent.width - 100
                            anchors.verticalCenter: parent.verticalCenter
                            conOndas: true
                            ondas: Tocadiscos.sonando
                            apagado: Tocadiscos.duracion <= 0
                            valor: Tocadiscos.duracion > 0 ? Tocadiscos.posicion / Tocadiscos.duracion : 0
                            onMovido: nuevo => Tocadiscos.ir(nuevo * Tocadiscos.duracion)
                        }
                        Texto {
                            width: 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tocadiscos.tiempo(Tocadiscos.duracion)
                            font.pixelSize: 11
                            font.bold: false
                            color: Tema.gris
                        }
                    }
                }

                // Volumen y la cola, a la derecha
                Row {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    BotonIcono {
                        anchors.verticalCenter: parent.verticalCenter
                        icono: Tocadiscos.volumen <= 0 ? "󰝟" : Tocadiscos.volumen < 50 ? "󰖀" : "󰕾"
                        onClic: Tocadiscos.ponerVolumen(Tocadiscos.volumen > 0 ? 0 : 70)
                    }
                    Deslizador {
                        width: 110
                        anchors.verticalCenter: parent.verticalCenter
                        valor: Tocadiscos.volumen / 100
                        onMovido: nuevo => Tocadiscos.ponerVolumen(Math.round(nuevo * 100))
                    }
                    Item { width: 6; height: 1 }
                    BotonIcono {
                        anchors.verticalCenter: parent.verticalCenter
                        icono: "󰲸"
                        colorIcono: ventana.verCola ? Tema.blanco : Tema.gris
                        onClic: ventana.verCola = !ventana.verCola
                    }
                }
            }

            // ======================================================== Piezas
            // Botón con icono y texto (Reproducir, Aleatorio...)
            component Boton: Rectangle {
                id: boton
                property string icono: ""
                property string texto: ""
                property bool principal: false
                signal clic()
                width: filaBoton.width + 28
                height: 34
                radius: Tema.esquina(10)
                color: principal ? (botonRaton.containsMouse ? Tema.blanco : Tema.claro(0.88))
                    : botonRaton.containsMouse ? Tema.cajaHover : Tema.caja
                border.width: principal ? 0 : 1
                border.color: Tema.claro(0.08)
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
                Row {
                    id: filaBoton
                    anchors.centerIn: parent
                    spacing: 8
                    Texto { text: boton.icono; font.pixelSize: 15; color: boton.principal ? Tema.oscuro : Tema.texto }
                    Texto { text: boton.texto; font.pixelSize: 13; color: boton.principal ? Tema.oscuro : Tema.texto }
                }
                MouseArea {
                    id: botonRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: boton.clic()
                }
            }

            // Un disco en la rejilla: la carátula (con ▶ al pasar por
            // encima) y debajo título y artista
            component TarjetaDisco: Item {
                id: tarjeta
                required property var modelData
                readonly property bool suena: Tocadiscos.discoActual?.id === modelData.id
                Item {
                    anchors { fill: parent; margins: 8 }
                    ClippingRectangle {
                        id: tapa
                        width: parent.width; height: width
                        radius: Tema.esquina(10)
                        color: Tema.caja
                        border.width: tarjeta.suena ? 2 : 1
                        border.color: tarjeta.suena ? Tema.claro(0.7) : Tema.claro(0.06)
                        Texto {
                            anchors.centerIn: parent
                            visible: !tarjeta.modelData.caratula
                            text: "󰀥"; font.pixelSize: 44; color: Tema.tenue
                        }
                        Image {
                            anchors.fill: parent
                            source: tarjeta.modelData.caratula ? "file://" + tarjeta.modelData.caratula : ""
                            sourceSize: Qt.size(384, 384)
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Tema.sombra(0.25)
                            opacity: tarjetaRaton.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                        }
                        // ▶ abajo a la derecha
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                            width: 40; height: 40; radius: 20
                            color: playDisco.containsMouse ? Tema.blanco : Tema.claro(0.88)
                            opacity: tarjetaRaton.containsMouse || playDisco.containsMouse ? 1 : 0
                            scale: opacity > 0 ? 1 : 0.8
                            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                            Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                            Texto { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; text: "󰐊"; font.pixelSize: 20; color: Tema.oscuro }
                            MouseArea {
                                id: playDisco
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Tocadiscos.reproducir(tarjeta.modelData.canciones, 0)
                            }
                        }
                    }
                    MouseArea {
                        id: tarjetaRaton
                        anchors.fill: tapa
                        z: -1
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: e => {
                            if (e.button === Qt.RightButton)
                                menu.abrir(tarjeta.modelData.canciones, mapToItem(ventana.contentItem, e.x, e.y), tarjeta.modelData.carpeta);
                            else
                                ventana.ir("disco", tarjeta.modelData);
                        }
                    }
                    Column {
                        anchors { top: tapa.bottom; topMargin: 8; left: parent.left; right: parent.right }
                        spacing: 1
                        Texto {
                            width: parent.width
                            text: tarjeta.modelData.titulo
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            color: tarjeta.suena ? Tema.blanco : Tema.texto
                        }
                        Texto {
                            width: parent.width
                            text: tarjeta.modelData.artista + (tarjeta.modelData.anio ? "  ·  " + tarjeta.modelData.anio : "")
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            font.bold: false
                            color: Tema.gris
                        }
                    }
                }
            }

            // Una canción en una lista: nº (o el ▶ si suena), título,
            // artista, disco (en «Canciones») y duración. Doble clic: suena
            // la lista desde ella
            component FilaCancion: Rectangle {
                id: filaC
                required property var modelData
                required property int index
                property bool conDisco: false
                property var lista: []
                readonly property bool suena: Tocadiscos.ruta === modelData.ruta
                height: 42
                radius: Tema.esquina(8)
                color: !suena && filaCRaton.containsMouse ? Tema.cajaHover : "transparent"
                Seleccion { activa: filaC.suena; radio: filaC.radius }
                Texto {
                    id: numero
                    x: 6
                    width: 32
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: filaC.suena ? (Tocadiscos.sonando ? "󰝚" : "󰏤")
                        : filaCRaton.containsMouse ? "󰐊"
                        : filaC.conDisco ? "" : (filaC.modelData.pista || filaC.index + 1)
                    font.pixelSize: filaC.suena || filaCRaton.containsMouse ? 14 : 12
                    font.bold: false
                    color: filaC.suena ? Tema.blanco : Tema.gris
                }
                Row {
                    anchors { left: numero.right; leftMargin: 10; right: duracion.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    spacing: 16
                    readonly property real col: filaC.conDisco ? (width - 32) / 3 : (width - 16) / 2
                    Texto {
                        width: filaC.conDisco ? parent.col : parent.width * 0.6
                        text: filaC.modelData.titulo
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        color: filaC.suena ? Tema.blanco : Tema.texto
                    }
                    Texto {
                        width: filaC.conDisco ? parent.col : parent.width * 0.4 - 16
                        text: filaC.modelData.artista
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        font.bold: false
                        color: Tema.gris
                    }
                    Texto {
                        visible: filaC.conDisco
                        width: parent.col
                        text: filaC.modelData.album
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        font.bold: false
                        color: Tema.gris
                    }
                }
                Texto {
                    id: duracion
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: Tocadiscos.tiempo(filaC.modelData.duracion)
                    font.pixelSize: 12
                    font.bold: false
                    color: Tema.gris
                }
                MouseArea {
                    id: filaCRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => {
                        if (e.button === Qt.RightButton)
                            menu.abrir([filaC.modelData.ruta], mapToItem(ventana.contentItem, e.x, e.y), null, filaC.modelData);
                        else if (e.x < numero.x + numero.width + 6)
                            Tocadiscos.reproducir(filaC.lista.map(c => c.ruta), filaC.index);
                    }
                    onDoubleClicked: Tocadiscos.reproducir(filaC.lista.map(c => c.ruta), filaC.index)
                }
            }

            // ======================================================== Menú (clic derecho)
            MouseArea {
                anchors.fill: parent
                visible: menu.visible
                z: 99
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: menu.cerrar()
            }
            Rectangle {
                id: menu
                property var rutas: []
                property string carpeta: ""
                property var cancion: null
                function abrir(r, p, carpetaDe, c) {
                    rutas = r;
                    carpeta = carpetaDe ?? "";
                    cancion = c ?? null;
                    x = Math.min(p.x, ventana.width - width - 8);
                    y = Math.min(p.y, ventana.height - height - 8);
                    visible = true;
                }
                function cerrar() { visible = false; }
                readonly property var opciones: [
                    {icono: "󰐊", texto: "Reproducir", hacer: () => Tocadiscos.reproducir(rutas, 0)},
                    {icono: "󰒝", texto: "Reproducir en aleatorio", oculta: rutas.length < 2, hacer: () => ventana.aleatorioDe(rutas)},
                    {icono: "󰐒", texto: "Añadir a la cola", hacer: () => Tocadiscos.anadir(rutas)},
                    {icono: "󰼛", texto: "Reproducir después", hacer: () => Tocadiscos.despues(rutas)},
                    {icono: "󰀥", texto: "Ir al disco", oculta: !cancion || ventana.vista === "disco", hacer: () => ventana.verDisco(cancion.disco_id)},
                    {icono: "󰉋", texto: "Mostrar en Archivos", oculta: !carpeta && !cancion,
                        hacer: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/niri/scripts/archivos.sh"].concat(
                            cancion ? ["--select", cancion.ruta] : [carpeta]))}
                ].filter(o => !o.oculta)
                visible: false
                z: 100
                width: 230
                height: columnaMenu.height + 12
                radius: Tema.esquina(10)
                color: Tema.sombra(0.97)
                border.width: 1
                border.color: Tema.claro(0.12)
                Column {
                    id: columnaMenu
                    x: 6; y: 6
                    width: parent.width - 12
                    Repeater {
                        model: menu.opciones
                        Rectangle {
                            id: opcion
                            required property var modelData
                            width: columnaMenu.width
                            height: 32
                            radius: Tema.esquina(8)
                            color: opcionRaton.containsMouse ? Tema.cajaHover : "transparent"
                            Texto {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: opcion.modelData.icono
                                font.pixelSize: 15
                                color: Tema.gris
                            }
                            Texto {
                                x: 36
                                anchors.verticalCenter: parent.verticalCenter
                                text: opcion.modelData.texto
                                font.pixelSize: 13
                                font.bold: false
                                color: Tema.texto
                            }
                            MouseArea {
                                id: opcionRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const h = opcion.modelData.hacer;
                                    menu.cerrar();
                                    h();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
