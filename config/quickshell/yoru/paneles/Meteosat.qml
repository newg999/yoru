// ============================================================================
//  Meteosat — el mapa del tiempo de Canarias, como una app de Yoru
//  Una ventana normal de niri (se abre con Mod+Alt+E o «Meteosat» en el
//  lanzador: Paneles.alternarMeteosat). Solo existe mientras está abierta.
//
//  El trabajo pesado lo hace scripts/meteosat.py (Python): descarga el
//  modelo (Open-Meteo) y el mapa y el satélite (EUMETSAT), y dibuja la vista
//  pedida en un PNG. Se le pide una vista por línea (JSON) y responde con la
//  ruta de la imagen, la rejilla del modelo y los valores de las ciudades.
//  Aquí se pinta lo demás, nítido y en vivo:
//    · el mapa se arrastra y se acerca con la rueda al momento (la imagen
//      se estira mientras llega la nueva, que se pide al soltar)
//    · las partículas del viento, que siguen la rejilla del modelo
//    · las ciudades con su valor, y el valor bajo el ratón
//    · los modos, la línea de tiempo (con reproducir) y la leyenda
//
//  Teclas: V R L N T modo · ← → hora · ↑ ↓ día · 0 ahora · P reproducir
//          + − zoom · W A S D mover · C centrar · Esc cerrar
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Scope {
    LazyLoader {
        active: Paneles.meteosatAbierto

        FloatingWindow {
            id: ventana

            title: Paneles.tituloMeteosat
            implicitWidth: 1240
            implicitHeight: 780
            minimumSize: Qt.size(720, 480)
            color: "#0d1820"
            visible: true
            onVisibleChanged: if (!visible) Paneles.meteosatAbierto = false

            // ------------------------------------------------------ estado
            readonly property var inicio: [28.3, -15.8]
            readonly property real altoInicial: 10
            property string modo: "r"
            property real lat: inicio[0]
            property real lon: inicio[1]
            property real alto: altoInicial       // grados de latitud visibles
            property int desfase: 0               // horas desde «ahora»
            property bool reproduciendo: false

            property var arranque: null           // paletas, marcas, unidades (del motor)
            property var info: null               // la última vista recibida
            property int pedidas: 0
            property int recibida: 0
            readonly property bool cargando: recibida < pedidas
            property string error: ""

            readonly property var modos: [
                {id: "v", icono: "󰖝", texto: "Viento"},
                {id: "r", icono: "󰼸", texto: "Rachas"},
                {id: "l", icono: "󰖗", texto: "Lluvia"},
                {id: "n", icono: "󰖐", texto: "Nubes"},
                {id: "t", icono: "󰔏", texto: "Temperatura"}
            ]
            readonly property string unidad: arranque?.unidades?.[modo] ?? ""
            readonly property bool sat: info?.sat ?? false
            readonly property bool conViento: (modo === "v" || modo === "r") && (info?.rejilla ?? null) !== null

            // La vista ahora (como en scripts/meteosat.py: grados por igual en los dos ejes)
            readonly property real anchoGrados: alto * mapa.width / Math.max(1, mapa.height)
            readonly property real vLat0: lat - alto / 2
            readonly property real vLat1: lat + alto / 2
            readonly property real vLon0: lon - anchoGrados / 2
            readonly property real vLon1: lon + anchoGrados / 2
            function xDe(lo) { return (lo - vLon0) / anchoGrados * mapa.width; }
            function yDe(la) { return (vLat1 - la) / alto * mapa.height; }
            function lonDe(x) { return vLon0 + x / mapa.width * anchoGrados; }
            function latDe(y) { return vLat1 - y / mapa.height * alto; }

            // ------------------------------------------------------ el motor
            Process {
                id: motor
                running: true
                command: ["python3", Quickshell.shellDir + "/scripts/meteosat.py"]
                stdinEnabled: true
                stdout: SplitParser {
                    onRead: linea => ventana.recibir(linea)
                }
                stderr: StdioCollector {
                    onStreamFinished: if (text.trim() !== "") console.warn("meteosat:", text.trim())
                }
                onExited: (codigo, estado) => {
                    if (ventana.visible)
                        ventana.error = "El motor de Meteosat se ha parado (" + codigo + ")";
                }
            }
            function pedir() {
                if (!arranque || mapa.width < 64 || mapa.height < 64)
                    return;
                pedidas++;
                motor.write(JSON.stringify({
                    n: pedidas, lat: lat, lon: lon, alto: alto, modo: modo, desfase: desfase,
                    w: Math.round(mapa.width), h: Math.round(mapa.height)
                }) + "\n");
            }
            // Agrupa los cambios seguidos (arrastrar, la rueda, redimensionar)
            Timer {
                id: pedirLuego
                interval: 160
                onTriggered: ventana.pedir()
            }
            function recibir(linea) {
                let d;
                try {
                    d = JSON.parse(linea);
                } catch (e) {
                    return;
                }
                if (d.paletas) {
                    arranque = d;
                    pedir();
                    return;
                }
                recibida = Math.max(recibida, d.n ?? 0);
                if (d.error) {
                    error = d.error;
                    reintentar.restart();
                    return;
                }
                error = "";
                // (si llega una vieja después de otra más nueva, no vale)
                if (info && d.n < info.n)
                    return;
                if (!reproduciendo || d.desfase === desfase)
                    desfase = d.desfase;
                capa.mostrar(d);
            }
            // ¿Lleva un rato cargando? (para el aviso de «Actualizando…»)
            Timer {
                id: cargaLenta
                property bool lenta: false
                interval: 700
                running: ventana.cargando
                onRunningChanged: if (!running) lenta = false
                onTriggered: lenta = true
            }
            Timer {
                id: reintentar
                interval: 60000
                onTriggered: ventana.pedir()
            }
            // El satélite se renueva cada pocos minutos; el modelo, cada hora
            Timer {
                interval: 5 * 60 * 1000
                running: true
                repeat: true
                onTriggered: ventana.pedir()
            }

            // ------------------------------------------------------ acciones
            function elegirModo(m) {
                if (m === modo)
                    return;
                modo = m;
                pedir();
            }
            function irHora(n) {
                const min = info?.min ?? 0, max = info?.max ?? 0;
                const nuevo = Math.max(min, Math.min(max, n));
                if (nuevo === desfase)
                    return;
                desfase = nuevo;
                pedirLuego.restart();
            }
            function zoom(f, x, y) {
                // Acercar o alejar dejando quieto el punto bajo el ratón
                const px = x ?? mapa.width / 2, py = y ?? mapa.height / 2;
                const la = latDe(py), lo = lonDe(px);
                alto = Math.max(1.5, Math.min(45, alto * f));
                lat = la + (py / mapa.height - 0.5) * alto;
                lon = lo - (px / mapa.width - 0.5) * anchoGrados;
                limitar();
                pedirLuego.restart();
            }
            function mover(dLat, dLon) {
                lat += dLat;
                lon += dLon;
                limitar();
                pedirLuego.restart();
            }
            function limitar() {
                lat = Math.max(-80, Math.min(80, lat));
                lon = ((lon + 540) % 360) - 180;
            }
            function centrar() {
                lat = inicio[0];
                lon = inicio[1];
                alto = altoInicial;
                pedirLuego.restart();
            }

            Timer {
                id: reproducir
                interval: 800
                repeat: true
                running: ventana.reproduciendo
                onTriggered: {
                    const max = ventana.info?.max ?? 0;
                    ventana.desfase = ventana.desfase < max ? ventana.desfase + 1 : 0;
                    ventana.pedir();
                }
            }

            // ------------------------------------------------------ rejilla del modelo
            // Valor de la rejilla (de norte a sur y de oeste a este) en un punto,
            // con interpolación bilineal; null fuera de ella
            function muestra(lista, la, lo) {
                const r = info?.rejilla;
                if (!r || !lista)
                    return null;
                const b = r.bbox;
                const fx = (lo - b[1]) / (b[3] - b[1]) * r.nx - 0.5;
                const fy = (b[2] - la) / (b[2] - b[0]) * r.ny - 0.5;
                if (fx < -0.5 || fy < -0.5 || fx > r.nx - 0.5 || fy > r.ny - 0.5)
                    return null;
                const x0 = Math.max(0, Math.min(r.nx - 1, Math.floor(fx)));
                const y0 = Math.max(0, Math.min(r.ny - 1, Math.floor(fy)));
                const x1 = Math.min(r.nx - 1, x0 + 1), y1 = Math.min(r.ny - 1, y0 + 1);
                const tx = Math.max(0, Math.min(1, fx - x0)), ty = Math.max(0, Math.min(1, fy - y0));
                const a = lista[y0 * r.nx + x0], b2 = lista[y0 * r.nx + x1];
                const c = lista[y1 * r.nx + x0], d = lista[y1 * r.nx + x1];
                return (a * (1 - tx) + b2 * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty;
            }
            function formato(v) {
                if (v === null || v === undefined)
                    return "";
                if (modo === "l")
                    return v < 0.1 ? "0" : v.toFixed(1);
                return Math.round(v) + (modo === "t" ? "°" : "");
            }

            // ------------------------------------------------------ colores (leyenda)
            function hex(c) { return Qt.color(c); }
            function colorDe(v) {
                const p = arranque?.paletas?.[modo];
                if (!p || p.length === 0)
                    return "transparent";
                if (v <= p[0][0])
                    return hex(p[0][1]);
                for (let i = 1; i < p.length; i++) {
                    if (v <= p[i][0]) {
                        const t = (v - p[i - 1][0]) / (p[i][0] - p[i - 1][0]);
                        const a = hex(p[i - 1][1]), b = hex(p[i][1]);
                        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
                    }
                }
                return hex(p[p.length - 1][1]);
            }

            // ------------------------------------------------------ teclas
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: e => {
                    const t = e.text.toLowerCase();
                    const paso = ventana.alto * 0.25;
                    if (e.key === Qt.Key_Escape)
                        Paneles.meteosatAbierto = false;
                    else if (["v", "r", "l", "n", "t"].includes(t))
                        ventana.elegirModo(t);
                    else if (e.key === Qt.Key_Right)
                        ventana.irHora(ventana.desfase + 1);
                    else if (e.key === Qt.Key_Left)
                        ventana.irHora(ventana.desfase - 1);
                    else if (e.key === Qt.Key_Down)
                        ventana.irHora(ventana.desfase + 24);
                    else if (e.key === Qt.Key_Up)
                        ventana.irHora(ventana.desfase - 24);
                    else if (t === "0")
                        ventana.irHora(0);
                    else if (t === "p" || e.key === Qt.Key_Space)
                        ventana.reproduciendo = !ventana.reproduciendo;
                    else if (t === "+" || t === "=")
                        ventana.zoom(1 / 1.4);
                    else if (t === "-")
                        ventana.zoom(1.4);
                    else if (t === "w")
                        ventana.mover(paso, 0);
                    else if (t === "s")
                        ventana.mover(-paso, 0);
                    else if (t === "a")
                        ventana.mover(0, -paso * 1.5);
                    else if (t === "d")
                        ventana.mover(0, paso * 1.5);
                    else if (t === "c")
                        ventana.centrar();
                    else
                        return;
                    e.accepted = true;
                }
            }

            // ------------------------------------------------------ el mapa
            Item {
                id: mapa
                anchors.fill: parent
                clip: true
                onWidthChanged: pedirLuego.restart()
                onHeightChanged: pedirLuego.restart()

                // Dos imágenes: la nueva se carga detrás y, ya lista, se pone
                // delante (sin parpadeo). Cada una se coloca según la zona que
                // muestra, así que al arrastrar o acercar se mueve al momento
                Item {
                    id: capa
                    anchors.fill: parent
                    property int frente: 0
                    property var vistas: [null, null]
                    function mostrar(d) {
                        const atras = 1 - frente;
                        const nuevas = vistas.slice();
                        nuevas[atras] = d;
                        vistas = nuevas;
                        const img = atras === 0 ? imagenA : imagenB;
                        img.source = "file://" + d.imagen + "?" + d.n;
                    }
                    function lista(cual) {
                        if (cual !== frente) {
                            frente = cual;
                            ventana.info = vistas[cual];
                        }
                    }
                    component Vista: Image {
                        required property int cual
                        readonly property var b: capa.vistas[cual]?.bbox ?? null
                        visible: b !== null && status === Image.Ready
                        x: b ? ventana.xDe(b[1]) : 0
                        y: b ? ventana.yDe(b[2]) : 0
                        width: b ? ventana.xDe(b[3]) - x : 0
                        height: b ? ventana.yDe(b[0]) - y : 0
                        z: capa.frente === cual ? 1 : 0
                        cache: false
                        asynchronous: true
                        smooth: true
                        onStatusChanged: if (status === Image.Ready) capa.lista(cual)
                    }
                    Vista { id: imagenA; cual: 0 }
                    Vista { id: imagenB; cual: 1 }
                }

                // Partículas del viento (como windy): siguen la rejilla del modelo
                // y dejan una estela que se apaga. Paradas mientras se arrastra
                Canvas {
                    id: viento
                    anchors.fill: parent
                    visible: ventana.conViento && !ventana.sat
                    renderStrategy: Canvas.Cooperative
                    property var px: []
                    property var py: []
                    property var edad: []
                    property bool limpiar: true
                    function nacer(i) {
                        px[i] = Math.random() * width;
                        py[i] = Math.random() * height;
                        edad[i] = Math.floor(Math.random() * 60);
                    }
                    function reiniciar() {
                        const n = Math.round(width * height / 1300);
                        px = new Array(n);
                        py = new Array(n);
                        edad = new Array(n);
                        for (let i = 0; i < n; i++)
                            nacer(i);
                        limpiar = true;
                    }
                    onWidthChanged: reiniciar()
                    onHeightChanged: reiniciar()
                    Component.onCompleted: reiniciar()
                    Connections {
                        target: ventana
                        function onLatChanged() { viento.limpiar = true; }
                        function onLonChanged() { viento.limpiar = true; }
                        function onAltoChanged() { viento.limpiar = true; }
                    }
                    Timer {
                        interval: 33
                        repeat: true
                        running: viento.visible && ventana.visible && !arrastre.active
                        onTriggered: viento.requestPaint()
                    }
                    onPaint: {
                        const ctx = getContext("2d");
                        if (limpiar) {
                            ctx.clearRect(0, 0, width, height);
                            limpiar = false;
                        }
                        // La estela: lo de antes se va borrando un poco
                        ctx.globalCompositeOperation = "destination-out";
                        ctx.fillStyle = "rgba(0, 0, 0, 0.1)";
                        ctx.fillRect(0, 0, width, height);
                        ctx.globalCompositeOperation = "source-over";
                        const r = ventana.info?.rejilla;
                        if (!r)
                            return;
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.8)";
                        ctx.lineWidth = 1.4;
                        ctx.beginPath();
                        const k = 0.022;
                        for (let i = 0; i < px.length; i++) {
                            const la = ventana.latDe(py[i]), lo = ventana.lonDe(px[i]);
                            const u = ventana.muestra(r.u, la, lo);
                            const v = ventana.muestra(r.v, la, lo);
                            if (u === null || edad[i] > 90) {
                                nacer(i);
                                continue;
                            }
                            const nx = px[i] + u * k * 3, ny = py[i] - v * k * 3;
                            ctx.moveTo(px[i], py[i]);
                            ctx.lineTo(nx, ny);
                            px[i] = nx;
                            py[i] = ny;
                            edad[i]++;
                            if (nx < 0 || ny < 0 || nx > width || ny > height || Math.abs(u) + Math.abs(v) < 0.3)
                                nacer(i);
                        }
                        ctx.stroke();
                    }
                }

                // Las ciudades: un punto, su nombre y el valor del modo (las
                // primeras de la lista mandan si se pisan)
                readonly property var etiquetas: {
                    const lista = ventana.info?.ciudades ?? [];
                    const puestas = [];
                    const fuera = 30;
                    for (const c of lista) {
                        const x = ventana.xDe(c.lon), y = ventana.yDe(c.lat);
                        if (x < fuera || y < fuera + 40 || x > width - fuera || y > height - 120)
                            continue;
                        const caja = [x - 36, y - 30, x + 36, y + 19];
                        if (puestas.some(p => !(caja[2] < p.caja[0] || caja[0] > p.caja[2] || caja[3] < p.caja[1] || caja[1] > p.caja[3])))
                            continue;
                        puestas.push({c: c, x: x, y: y, caja: caja});
                    }
                    return puestas;
                }
                Repeater {
                    model: mapa.etiquetas
                    Item {
                        id: ciudad
                        required property var modelData
                        x: modelData.x
                        y: modelData.y
                        readonly property string valor: ventana.modo === "l" && modelData.c.valor < 0.1 ? ""
                            : ventana.formato(modelData.c.valor)
                        // El valor, en una pastilla encima del punto
                        Rectangle {
                            visible: ciudad.valor !== ""
                            anchors.horizontalCenter: parent.left
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 6
                            width: filaValor.implicitWidth + 12
                            height: 20
                            radius: 10
                            color: Qt.rgba(0.05, 0.08, 0.11, 0.78)
                            Row {
                                id: filaValor
                                anchors.centerIn: parent
                                spacing: 2
                                Texto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ciudad.valor
                                    color: "white"
                                    font.pixelSize: 13
                                }
                                Texto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: ventana.modo !== "t"
                                    text: ventana.unidad
                                    color: "#c8d2da"
                                    font.pixelSize: 9
                                }
                            }
                        }
                        Rectangle {
                            x: -3; y: -3
                            width: 6; height: 6
                            radius: 3
                            color: "white"
                            border.color: "black"
                            border.width: 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.left
                            y: 5
                            text: ciudad.modelData.c.nombre
                            color: "white"
                            font.family: Tema.fuente
                            font.pixelSize: 12
                            font.bold: true
                            style: Text.Outline
                            styleColor: "#c0000000"
                        }
                    }
                }

                // Arrastrar mueve el mapa; la rueda acerca o aleja; el ratón
                // encima enseña el valor de ese punto
                DragHandler {
                    id: arrastre
                    target: null
                    property real lat0
                    property real lon0
                    cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onActiveChanged: {
                        if (active) {
                            lat0 = ventana.lat;
                            lon0 = ventana.lon;
                        } else {
                            ventana.pedir();
                        }
                    }
                    onTranslationChanged: {
                        if (!active)
                            return;
                        ventana.lat = lat0 + translation.y / mapa.height * ventana.alto;
                        ventana.lon = lon0 - translation.x / mapa.width * ventana.anchoGrados;
                        ventana.limitar();
                    }
                }
                WheelHandler {
                    onWheel: e => ventana.zoom(e.angleDelta.y > 0 ? 1 / 1.15 : 1.15, e.x, e.y)
                }
                HoverHandler {
                    id: encima
                }
            }

            // El valor bajo el ratón
            Rectangle {
                readonly property var v: encima.hovered && !arrastre.active
                    ? ventana.muestra(ventana.info?.rejilla?.valor, ventana.latDe(encima.point.position.y), ventana.lonDe(encima.point.position.x))
                    : null
                visible: v !== null
                x: Math.min(parent.width - width - 8, encima.point.position.x + 16)
                y: Math.max(8, encima.point.position.y - height - 10)
                width: filaCursor.implicitWidth + 16
                height: 26
                radius: 13
                color: Tema.panel
                border.width: Tema.borde(1)
                border.color: Tema.claro(0.2)
                Row {
                    id: filaCursor
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: ventana.colorDe(parent.parent.v ?? 0)
                        visible: ventana.modo !== "n"
                    }
                    Texto {
                        text: ventana.formato(parent.parent.v) + (ventana.modo === "t" ? "" : " " + ventana.unidad)
                        color: Tema.blanco
                        font.pixelSize: 12
                    }
                    Texto {
                        text: ventana.latDe(encima.point.position.y).toFixed(2) + "°, " + ventana.lonDe(encima.point.position.x).toFixed(2) + "°"
                        color: Tema.gris
                        font.pixelSize: 11
                        font.bold: false
                    }
                }
            }

            // ------------------------------------------------------ la interfaz
            component Tarjeta: Rectangle {
                color: Tema.panel
                radius: Tema.radioPanel
                border.width: Tema.borde(1)
                border.color: Tema.claro(0.12)
            }

            // Arriba a la izquierda: el título y los modos
            Tarjeta {
                id: cabecera
                x: 16
                y: 16
                width: filaCabecera.implicitWidth + 16
                height: 48
                Row {
                    id: filaCabecera
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    spacing: 4
                    Item {
                        width: tituloFila.implicitWidth + 16
                        height: 36
                        Row {
                            id: tituloFila
                            anchors.centerIn: parent
                            spacing: 8
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰼯"
                                font.family: Tema.mono
                                font.pixelSize: 18
                                color: Tema.blanco
                            }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Meteosat"
                                font.pixelSize: 14
                                color: Tema.texto
                            }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: 20
                        color: Tema.claro(0.15)
                    }
                    Repeater {
                        model: ventana.modos
                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool elegido: ventana.modo === modelData.id
                            anchors.verticalCenter: parent.verticalCenter
                            width: filaChip.implicitWidth + 22
                            height: 34
                            radius: 17
                            color: elegido ? Tema.blanco : chipRaton.containsMouse ? Tema.cajaHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            Row {
                                id: filaChip
                                anchors.centerIn: parent
                                spacing: 7
                                Texto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.icono
                                    font.family: Tema.mono
                                    font.pixelSize: 16
                                    color: chip.elegido ? Tema.oscuro : Tema.texto
                                }
                                Texto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.texto
                                    font.pixelSize: 12
                                    color: chip.elegido ? Tema.oscuro : Tema.texto
                                }
                            }
                            MouseArea {
                                id: chipRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ventana.elegirModo(chip.modelData.id)
                            }
                        }
                    }
                }
            }

            // Arriba a la derecha: acercar, alejar y volver a Canarias
            Tarjeta {
                anchors { top: parent.top; right: parent.right; margins: 16 }
                width: 44
                height: columnaZoom.implicitHeight + 8
                Column {
                    id: columnaZoom
                    anchors.centerIn: parent
                    spacing: 2
                    BotonIcono { icono: "󰐕"; onClic: ventana.zoom(1 / 1.4) }
                    BotonIcono { icono: "󰍴"; onClic: ventana.zoom(1.4) }
                    BotonIcono { icono: "󰋜"; onClic: ventana.centrar() }
                }
            }

            // Cargando, o un aviso del motor (arriba en el centro)
            Tarjeta {
                readonly property string mensaje: ventana.error !== "" ? ventana.error
                    : ventana.info?.aviso ? ventana.info.aviso
                    : ventana.info === null ? "Cargando el mapa…"
                    // (reproduciendo, no: cambia de hora cada momento y el aviso
                    // no paraba de salir; y solo si tarda, para que no parpadee)
                    : ventana.cargando && cargaLenta.lenta && !ventana.reproduciendo ? "Actualizando…" : ""
                id: avisoTarjeta
                readonly property bool malo: ventana.error !== "" || (ventana.info?.aviso ?? "") !== ""
                opacity: mensaje !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal } }
                anchors.horizontalCenter: parent.horizontalCenter
                y: cabecera.y + cabecera.height + 12
                width: Math.min(parent.width - 32, filaAviso.implicitWidth + 28)
                height: 32
                radius: 16
                Row {
                    id: filaAviso
                    anchors.centerIn: parent
                    spacing: 8
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: avisoTarjeta.malo ? "󰀦" : "󰑓"
                        font.family: Tema.mono
                        color: avisoTarjeta.malo ? Tema.amarillo : Tema.gris
                        RotationAnimation on rotation {
                            running: !avisoTarjeta.malo && avisoTarjeta.visible
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 1100
                        }
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: avisoTarjeta.mensaje
                        font.pixelSize: 12
                        font.bold: false
                        color: Tema.texto
                        elide: Text.ElideRight
                    }
                }
            }

            // Abajo: la línea de tiempo y la leyenda
            Tarjeta {
                id: pie
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                height: 76

                readonly property var horas: ventana.info?.horas ?? []
                readonly property int i0: (ventana.info?.idx ?? 0) - (ventana.info?.desfase ?? 0)
                readonly property int total: horas.length
                function fecha(i) {
                    const h = horas[i];
                    if (!h)
                        return null;
                    return new Date(Number(h.slice(0, 4)), Number(h.slice(5, 7)) - 1, Number(h.slice(8, 10)), Number(h.slice(11, 13)));
                }
                readonly property string etiqueta: {
                    const t = fecha(i0 + ventana.desfase);
                    if (!t)
                        return "Sin datos";
                    const hoy = new Date();
                    hoy.setHours(0, 0, 0, 0);
                    const dias = Math.round((new Date(t).setHours(0, 0, 0, 0) - hoy) / 86400000);
                    const nombres = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
                    const dia = dias === 0 ? "Hoy" : dias === 1 ? "Mañana" : dias === -1 ? "Ayer" : nombres[t.getDay()] + " " + t.getDate();
                    return dia + " · " + String(t.getHours()).padStart(2, "0") + ":00";
                }

                Row {
                    id: botonesPie
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    spacing: 8
                    // Reproducir / parar
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 44; radius: 22
                        color: playRaton.containsMouse ? Qt.lighter(Tema.blanco, 1.1) : Tema.blanco
                        Texto {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: ventana.reproduciendo ? 0 : 1
                            text: ventana.reproduciendo ? "󰏤" : "󰐊"
                            font.family: Tema.mono
                            font.pixelSize: 22
                            color: Tema.oscuro
                        }
                        MouseArea {
                            id: playRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ventana.reproduciendo = !ventana.reproduciendo
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        spacing: 2
                        Texto {
                            text: pie.etiqueta
                            font.pixelSize: 15
                            color: Tema.blanco
                        }
                        Texto {
                            text: ventana.sat ? "Satélite Meteosat · en vivo"
                                : ventana.desfase === 0 ? "Ahora"
                                : (ventana.desfase > 0 ? "Dentro de " : "Hace ") + Math.abs(ventana.desfase) + " h"
                            font.pixelSize: 11
                            font.bold: false
                            color: Tema.gris
                        }
                    }
                    // Volver a ahora
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ventana.desfase !== 0
                        width: textoAhora.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: ahoraRaton.containsMouse ? Tema.cajaHover : Tema.caja
                        Texto {
                            id: textoAhora
                            anchors.centerIn: parent
                            text: "Ahora"
                            font.pixelSize: 11
                            color: Tema.texto
                        }
                        MouseArea {
                            id: ahoraRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ventana.irHora(0)
                        }
                    }
                }

                // La leyenda (a la derecha)
                Item {
                    id: leyenda
                    visible: !ventana.sat && (ventana.arranque?.marcas?.[ventana.modo] ?? null) !== null
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? 230 : 0
                    height: 40
                    readonly property var marcas: ventana.arranque?.marcas?.[ventana.modo] ?? []
                    // Como el motor: las marcas repartidas por igual y,
                    // entre ellas, el color de cada valor
                    function valorEn(t) {
                        const n = marcas.length - 1;
                        if (n < 1)
                            return marcas[0] ?? 0;
                        const f = Math.max(0, Math.min(n, t * n));
                        const i = Math.min(n - 1, Math.floor(f));
                        return marcas[i] + (marcas[i + 1] - marcas[i]) * (f - i);
                    }
                    Canvas {
                        id: degradado
                        width: parent.width - 34
                        height: 10
                        y: 6
                        readonly property string clave: ventana.modo + (ventana.arranque ? "1" : "0")
                        onClaveChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const g = ctx.createLinearGradient(0, 0, width, 0);
                            for (let i = 0; i <= 24; i++)
                                g.addColorStop(i / 24, ventana.colorDe(leyenda.valorEn(i / 24)));
                            ctx.fillStyle = g;
                            const r = height / 2;
                            ctx.beginPath();
                            ctx.moveTo(r, 0);
                            ctx.lineTo(width - r, 0);
                            ctx.arc(width - r, r, r, -Math.PI / 2, Math.PI / 2);
                            ctx.lineTo(r, height);
                            ctx.arc(r, r, r, Math.PI / 2, 3 * Math.PI / 2);
                            ctx.fill();
                        }
                    }
                    Texto {
                        anchors.left: degradado.right
                        anchors.leftMargin: 6
                        anchors.verticalCenter: degradado.verticalCenter
                        text: ventana.unidad
                        font.pixelSize: 10
                        color: Tema.gris
                    }
                    Repeater {
                        model: leyenda.marcas
                        Texto {
                            required property var modelData
                            required property int index
                            x: degradado.width * index / Math.max(1, leyenda.marcas.length - 1) - implicitWidth / 2
                            y: degradado.y + degradado.height + 4
                            text: String(modelData)
                            font.pixelSize: 10
                            font.bold: false
                            color: Tema.texto
                        }
                    }
                }

                // La línea de tiempo: una raya por hora, los días marcados, y
                // se arrastra o se pulsa para ir a esa hora
                Item {
                    id: linea
                    anchors.left: botonesPie.right
                    anchors.leftMargin: 18
                    anchors.right: leyenda.left
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    height: 48
                    readonly property real paso: pie.total > 1 ? width / (pie.total - 1) : 0
                    function xDe(i) { return i * paso; }

                    // Los días: su nombre encima de su medianoche
                    Repeater {
                        model: pie.total
                        Item {
                            required property int index
                            readonly property var t: pie.fecha(index)
                            readonly property bool medianoche: t !== null && t.getHours() === 0
                            x: linea.xDe(index)
                            Rectangle {
                                x: -width / 2
                                y: medianoche ? 14 : (parent.t?.getHours() % 6 === 0 ? 20 : 23)
                                width: 1
                                height: medianoche ? 20 : (parent.t?.getHours() % 6 === 0 ? 10 : 5)
                                color: Tema.claro(medianoche ? 0.4 : 0.2)
                            }
                            Texto {
                                visible: parent.medianoche
                                x: 4
                                y: 0
                                text: {
                                    const t = parent.t;
                                    if (!t)
                                        return "";
                                    const nombres = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
                                    return nombres[t.getDay()] + " " + t.getDate();
                                }
                                font.pixelSize: 10
                                color: Tema.gris
                            }
                        }
                    }
                    // Lo que ya pasó, más apagado; ahora, una raya del tema
                    Rectangle {
                        y: 36
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Tema.claro(0.1)
                    }
                    Rectangle {
                        y: 36
                        x: linea.xDe(pie.i0)
                        width: Math.max(0, linea.xDe(pie.i0 + ventana.desfase) - x)
                        height: 4
                        radius: 2
                        color: Tema.claro(0.45)
                    }
                    Rectangle {
                        x: linea.xDe(pie.i0) - 1
                        y: 12
                        width: 2
                        height: 30
                        color: Tema.blanco
                        opacity: 0.6
                    }
                    // El tirador
                    Rectangle {
                        x: linea.xDe(pie.i0 + ventana.desfase) - width / 2
                        y: 38 - height / 2
                        width: 16; height: 16; radius: 8
                        color: Tema.blanco
                        border.width: 3
                        border.color: Tema.oscuro
                        Behavior on x { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function ir(mx) {
                            if (linea.paso <= 0)
                                return;
                            ventana.reproduciendo = false;
                            ventana.irHora(Math.round(mx / linea.paso) - pie.i0);
                        }
                        onPressed: e => ir(e.x)
                        onPositionChanged: e => { if (pressed) ir(e.x); }
                    }
                }
            }
        }
    }
}
