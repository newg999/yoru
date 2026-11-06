// ============================================================================
//  Escritorio — widgets sobre el fondo de pantalla, con cualquier estilo de
//  barra. Van por debajo de las ventanas: se ven en los escritorios vacíos.
//
//  Cuáles salen, su tamaño y su aspecto: Ajustes › Escritorio (comun/Widgets.qml).
//  Sin colocar, van en una columna a la derecha, a media pantalla.
//
//  Modo edición (clic derecho en un widget, o desde Ajustes): se ponen por
//  encima de las ventanas y
//    arrastrar = moverlo · rueda = más grande o más pequeño · × = quitarlo
//    arriba: + añadir otro · restablecer · Listo (o Esc)
//
//  Cada widget es una capa del tamaño de la pantalla, transparente, que solo
//  recibe clics donde está él (mask), como las notas (NotasEscritorio.qml):
//  así se arrastra pegado al ratón.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.comun

Scope {
    id: escritorio
    required property ShellScreen modelData

    readonly property int margen: 18
    // Un poco más grande en pantallas grandes, y lo que diga Ajustes
    readonly property real escala: (modelData.height >= 1000 ? 1.25 : 1) * Widgets.escala

    // Sin ventanas en esta pantalla: los widgets se ven (y el agua se mueve)
    readonly property bool aLaVista: Niri.ventanaEn(modelData.name) === null || Widgets.editando

    // ------------------------------------------------------------ Datos
    // Disco: el de la raíz (/), cada minuto
    property real discoTotal: 0     // bytes
    property real discoUsado: 0
    Process {
        id: df
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (n.length === 2 && n[0] > 0) {
                    escritorio.discoTotal = n[0];
                    escritorio.discoUsado = n[1];
                }
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: Widgets.activo("disco")
        triggeredOnStart: true
        onTriggered: df.running = true
    }
    function gigas(b) { return (b / 1073741824).toFixed(1) + "G"; }

    // Red: lo que baja y sube (de /proc/net/dev, cada 2 s)
    property real bajada: 0         // bytes/s
    property real subida: 0
    property var _red: null
    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const l of text().split("\n").slice(2)) {
                const [nombre, resto] = l.split(":");
                if (!resto || nombre.trim() === "lo")
                    continue;
                const c = resto.trim().split(/\s+/).map(Number);
                rx += c[0];
                tx += c[8];
            }
            const ahora = Date.now();
            if (escritorio._red) {
                const s = Math.max(0.5, (ahora - escritorio._red.t) / 1000);
                escritorio.bajada = Math.max(0, (rx - escritorio._red.rx) / s);
                escritorio.subida = Math.max(0, (tx - escritorio._red.tx) / s);
            }
            escritorio._red = {rx, tx, t: ahora};
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: Widgets.activo("red") && escritorio.aLaVista
        triggeredOnStart: true
        onTriggered: netdev.reload()
    }
    function velocidad(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + "M" : b >= 1024 ? Math.round(b / 1024) + "K" : Math.round(b) + "B";
    }
    readonly property var redWifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi)?.networks.values.find(r => r.connected) ?? null
    readonly property bool conCable: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)

    SystemClock {
        id: reloj
        precision: Widgets.segundos || Widgets.activo("agujas") ? SystemClock.Seconds : SystemClock.Minutes
    }
    readonly property var dias: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    // ------------------------------------------------ Tamaños y sitios
    // Tamaño de cada uno a escala 1 (para colocarlos en la columna)
    function base(id) {
        if (Widgets.info(id)?.par)
            return {w: 118, h: 76};
        return ({hora: {w: 244, h: Widgets.fecha ? 52 : 34}, agujas: {w: 120, h: 120},
                 tiempo: {w: 244, h: 118}, calendario: {w: 244, h: 214}, musica: {w: 244, h: 80}})[id]
            ?? {w: 244, h: 80};
    }
    // La columna de la derecha (para los que no se han movido): las tarjetas
    // pequeñas, de dos en dos; el resto, una por fila. Centrada en alto. Si
    // no caben, sigue en otra columna a su izquierda
    readonly property var columna: {
        void Widgets.activos;
        void Widgets.escala;
        void Widgets.tamanos;
        void Widgets.fecha;
        const e = escala, hueco = 8 * e, separa = 14 * e, ancho = 244 * e;
        const alto = modelData.height - 2 * margen - 40;
        // Primero, en filas: [{ids, w, h}]
        const filas = [];
        let pendiente = null;
        for (const id of Widgets.activos) {
            if (!Widgets.info(id) || Widgets.sitio(id))
                continue;
            if (id === "musica" && Reproductor.actual === null && !Widgets.editando)
                continue;
            const t = Widgets.tam(id), b = base(id);
            const w = b.w * e * t, h = b.h * e * t;
            if (Widgets.info(id).par && t === 1) {
                if (pendiente) {
                    pendiente.ids.push({id, w, h});
                    pendiente = null;
                    continue;
                }
                pendiente = {ids: [{id, w, h}], h: h, par: true};
                filas.push(pendiente);
                continue;
            }
            pendiente = null;
            filas.push({ids: [{id, w, h}], h: h});
        }
        // Luego, las filas en columnas que quepan en alto
        const columnas = [[]];
        let usado = 0;
        for (const f of filas) {
            const mas = (columnas[columnas.length - 1].length ? (f.par ? hueco : separa) : 0) + f.h;
            if (usado + mas > alto && columnas[columnas.length - 1].length) {
                columnas.push([]);
                usado = 0;
            }
            columnas[columnas.length - 1].push(f);
            usado += (columnas[columnas.length - 1].length > 1 ? (f.par ? hueco : separa) : 0) + f.h;
        }
        const sitios = {};
        columnas.forEach((col, n) => {
            const x0 = modelData.width - margen - ancho - n * (ancho + 2 * separa);
            let y = 0;
            col.forEach((f, k) => {
                if (k > 0)
                    y += f.par ? hueco : separa;
                if (f.par) {
                    sitios[f.ids[0].id] = {x: x0, y: y};
                    if (f.ids[1])
                        sitios[f.ids[1].id] = {x: x0 + ancho - f.ids[1].w, y: y};
                } else {
                    sitios[f.ids[0].id] = {x: x0 + ancho - f.ids[0].w, y: y};
                }
                y += f.h;
            });
            const arriba = Math.max(margen + 30, (modelData.height - y) / 2);
            for (const f of col)
                for (const it of f.ids)
                    sitios[it.id].y += arriba;
        });
        return sitios;
    }

    // ------------------------------------------------- Piezas comunes
    component Mono: Text {
        property real e: escritorio.escala
        color: Tema.texto
        font.family: Tema.mono
        font.pixelSize: Math.round(11 * e)
        font.bold: true
    }
    // Fondo de las tarjetas
    readonly property color fondo: Tema.sombra(Widgets.opacidad)

    // Tarjeta: icono arriba a la izquierda, nombre arriba a la derecha, y el
    // color subiendo desde abajo hasta «uso» (de 0 a 1)
    component Tarjeta: Rectangle {
        id: tarjeta
        property real e: escritorio.escala
        property string icono: ""
        property string nombre: ""
        property string valor: ""
        property string detalle: ""
        property real uso: 0
        property color colorUso: Tema.blanco   // el del agua (la batería, por colores)
        // El texto de abajo sobre el color: oscuro
        readonly property bool tapado: uso > 0.32

        width: Math.round(118 * e)
        height: Math.round(76 * e)
        radius: Math.round(14 * e)
        color: escritorio.fondo

        // El uso, como agua que sube desde abajo (y ondea con el
        // escritorio a la vista)
        ClippingRectangle {
            anchors.fill: parent
            radius: tarjeta.radius
            color: "transparent"
            Agua {
                anchors.fill: parent
                nivel: tarjeta.uso
                color: tarjeta.colorUso
                inclinacion: 2.5 * tarjeta.e
                moviendo: escritorio.aLaVista
            }
        }
        Text {
            x: Math.round(10 * tarjeta.e); y: Math.round(8 * tarjeta.e)
            text: tarjeta.icono
            font.family: Tema.mono
            font.pixelSize: Math.round(12 * tarjeta.e)
            color: tarjeta.uso > 0.82 ? Tema.oscuro : Tema.gris
        }
        Mono {
            e: tarjeta.e
            anchors { right: parent.right; rightMargin: Math.round(10 * tarjeta.e) }
            y: Math.round(8 * tarjeta.e)
            width: Math.min(implicitWidth, tarjeta.width - Math.round(36 * tarjeta.e))
            elide: Text.ElideRight
            text: tarjeta.nombre
            font.pixelSize: Math.round(9 * tarjeta.e)
            color: tarjeta.uso > 0.82 ? Tema.oscuro : Tema.gris
        }
        Mono {
            e: tarjeta.e
            anchors { left: parent.left; leftMargin: Math.round(10 * tarjeta.e); bottom: parent.bottom; bottomMargin: Math.round(10 * tarjeta.e) }
            text: tarjeta.detalle
            font.pixelSize: Math.round(9 * tarjeta.e)
            color: tarjeta.tapado ? Tema.sombra(0.75) : Tema.gris
        }
        Mono {
            e: tarjeta.e
            anchors { right: parent.right; rightMargin: Math.round(10 * tarjeta.e); bottom: parent.bottom; bottomMargin: Math.round(7 * tarjeta.e) }
            text: tarjeta.valor
            font.pixelSize: Math.round(17 * tarjeta.e)
            color: tarjeta.tapado ? Tema.oscuro : Tema.texto
        }
    }

    // ------------------------------------------------------- Los widgets
    // Cada uno recibe «e»: su escala (la general por la suya)
    Component {
        id: wHora
        Column {
            property real e: 1
            spacing: Math.round(2 * e)
            Mono {
                e: parent.e
                anchors.right: parent.right
                text: Qt.formatDateTime(reloj.date, (Ajustes.reloj24 ? "HH:mm" : "h:mm") + (Widgets.segundos ? ":ss" : ""))
                font.pixelSize: Math.round(26 * parent.e)
                font.bold: false
                style: Text.Raised
                styleColor: Tema.sombra(0.4)
            }
            Mono {
                e: parent.e
                visible: Widgets.fecha
                anchors.right: parent.right
                text: escritorio.dias[reloj.date.getDay()] + ", " + reloj.date.getDate() + " de " + escritorio.meses[reloj.date.getMonth()]
                font.pixelSize: Math.round(12 * parent.e)
                font.bold: false
                color: Tema.texto
                style: Text.Raised
                styleColor: Tema.sombra(0.4)
            }
        }
    }

    Component {
        id: wAgujas
        Item {
            id: agujas
            property real e: 1
            width: Math.round(120 * e)
            height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: escritorio.fondo
                border.width: Math.max(1, Math.round(2 * agujas.e))
                border.color: Tema.claro(0.12)
            }
            Canvas {
                id: esfera
                anchors.fill: parent
                property var hora: reloj.date
                onHoraChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const r = width / 2;
                    c.translate(r, r);
                    // Las marcas de las horas
                    for (let i = 0; i < 12; i++) {
                        const a = i * Math.PI / 6;
                        const largo = i % 3 === 0 ? r * 0.16 : r * 0.08;
                        c.beginPath();
                        c.moveTo(Math.sin(a) * (r * 0.86), -Math.cos(a) * (r * 0.86));
                        c.lineTo(Math.sin(a) * (r * 0.86 - largo), -Math.cos(a) * (r * 0.86 - largo));
                        c.strokeStyle = i % 3 === 0 ? Tema.texto : Tema.gris;
                        c.lineWidth = i % 3 === 0 ? r * 0.045 : r * 0.025;
                        c.lineCap = "round";
                        c.stroke();
                    }
                    const d = hora;
                    const aguja = (angulo, largo, grosor, color) => {
                        c.beginPath();
                        c.moveTo(-Math.sin(angulo) * r * 0.1, Math.cos(angulo) * r * 0.1);
                        c.lineTo(Math.sin(angulo) * largo, -Math.cos(angulo) * largo);
                        c.strokeStyle = color;
                        c.lineWidth = grosor;
                        c.lineCap = "round";
                        c.stroke();
                    };
                    const s = d.getSeconds(), m = d.getMinutes() + s / 60, h = d.getHours() % 12 + m / 60;
                    aguja(h * Math.PI / 6, r * 0.48, r * 0.07, Tema.texto);
                    aguja(m * Math.PI / 30, r * 0.7, r * 0.05, Tema.texto);
                    aguja(s * Math.PI / 30, r * 0.76, r * 0.02, Tema.blanco);
                    c.beginPath();
                    c.arc(0, 0, r * 0.05, 0, Math.PI * 2);
                    c.fillStyle = Tema.blanco;
                    c.fill();
                }
            }
        }
    }

    Component {
        id: wDisco
        Tarjeta {
            icono: "󰋊"
            nombre: escritorio.discoTotal > 0 ? escritorio.gigas(escritorio.discoTotal) : "Disco"
            detalle: escritorio.discoTotal > 0 ? escritorio.gigas(escritorio.discoUsado) : ""
            valor: escritorio.discoTotal > 0 ? Math.round(100 * escritorio.discoUsado / escritorio.discoTotal) + "%" : "–"
            uso: escritorio.discoTotal > 0 ? escritorio.discoUsado / escritorio.discoTotal : 0
        }
    }
    Component {
        id: wTemp
        Tarjeta {
            icono: "󰔏"
            nombre: "Temp"
            valor: Sistema.temperatura > 0 ? Sistema.temperatura + "°" : "–"
            uso: Sistema.temperatura / 100
        }
    }
    Component {
        id: wRam
        Tarjeta {
            icono: "󰍛"
            nombre: "RAM"
            detalle: Sistema.memoria + "%"
            valor: Sistema.memUsada.toFixed(1) + "G"
            uso: Sistema.memoria / 100
        }
    }
    Component {
        id: wCpu
        Tarjeta {
            icono: "󰘚"
            nombre: "CPU"
            valor: Sistema.cpu + "%"
            uso: Sistema.cpu / 100
        }
    }
    Component {
        id: wBateria
        Tarjeta {
            readonly property var b: UPower.displayDevice
            readonly property bool cargando: b?.state === UPowerDeviceState.Charging
            icono: cargando ? "󰂄" : "󰁹"
            nombre: "Batería"
            detalle: cargando ? "Cargando" : !UPower.onBattery ? "Enchufada" : ""
            valor: Math.round((b?.percentage ?? 0) * 100) + "%"
            uso: b?.percentage ?? 0
            colorUso: Tema.bateria(uso, cargando || b?.state === UPowerDeviceState.FullyCharged)
        }
    }
    Component {
        id: wRed
        Tarjeta {
            icono: escritorio.conCable ? "󰈀" : escritorio.redWifi ? "󰖩" : "󰖪"
            nombre: escritorio.conCable ? "Cable" : escritorio.redWifi?.name ?? "Sin red"
            detalle: "↑ " + escritorio.velocidad(escritorio.subida)
            valor: "↓ " + escritorio.velocidad(escritorio.bajada)
            uso: escritorio.redWifi ? escritorio.redWifi.signalStrength * 0.35 : 0
        }
    }

    Component {
        id: wTiempo
        Rectangle {
            id: tiempo
            property real e: 1
            width: Math.round(244 * e)
            height: Math.round(118 * e)
            radius: Math.round(16 * e)
            color: escritorio.fondo
            Mono {
                e: tiempo.e
                anchors.centerIn: parent
                visible: !Tiempo.listo
                text: "Mirando el tiempo…"
                font.bold: false
                color: Tema.gris
            }
            Row {
                visible: Tiempo.listo
                x: Math.round(14 * tiempo.e)
                y: Math.round(12 * tiempo.e)
                spacing: Math.round(10 * tiempo.e)
                Mono {
                    e: tiempo.e
                    anchors.verticalCenter: parent.verticalCenter
                    text: Tiempo.icono
                    font.pixelSize: Math.round(30 * tiempo.e)
                    color: Tema.blanco
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Mono {
                        e: tiempo.e
                        text: Tiempo.temperatura + "°  " + (Tiempo.dias.length ? Tiempo.dias[0].max + "°/" + Tiempo.dias[0].min + "°" : "")
                        font.pixelSize: Math.round(17 * tiempo.e)
                    }
                    Mono {
                        e: tiempo.e
                        width: Math.round(160 * tiempo.e)
                        elide: Text.ElideRight
                        text: Tiempo.descripcion + " · " + Tiempo.lugar
                        font.bold: false
                        font.pixelSize: Math.round(10 * tiempo.e)
                        color: Tema.gris
                    }
                }
            }
            // Los próximos cuatro días
            Row {
                visible: Tiempo.listo
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Math.round(10 * tiempo.e) }
                Repeater {
                    model: Tiempo.dias.slice(1, 5)
                    Column {
                        id: dia
                        required property var modelData
                        width: parent.width / 4
                        spacing: Math.round(1 * tiempo.e)
                        Mono {
                            e: tiempo.e
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: escritorio.dias[new Date(dia.modelData.fecha + "T12:00:00").getDay()].slice(0, 3)
                            font.bold: false
                            font.pixelSize: Math.round(9 * tiempo.e)
                            color: Tema.gris
                        }
                        Mono {
                            e: tiempo.e
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Tiempo.iconoDe(dia.modelData.codigo, true)
                            font.pixelSize: Math.round(14 * tiempo.e)
                        }
                        Mono {
                            e: tiempo.e
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dia.modelData.max + "°"
                            font.pixelSize: Math.round(10 * tiempo.e)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wCalendario
        Rectangle {
            id: cal
            property real e: 1
            width: Math.round(244 * e)
            height: Math.round(214 * e)
            radius: Math.round(16 * e)
            color: escritorio.fondo
            readonly property date hoy: reloj.date
            readonly property var casillas: {
                const primero = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
                const desde = new Date(hoy.getFullYear(), hoy.getMonth(), 1 - (primero.getDay() + 6) % 7);
                const r = [];
                for (let i = 0; i < 42; i++) {
                    const d = new Date(desde.getFullYear(), desde.getMonth(), desde.getDate() + i);
                    r.push({dia: d.getDate(), delMes: d.getMonth() === hoy.getMonth(),
                            hoy: d.toDateString() === hoy.toDateString(), finde: i % 7 >= 5});
                }
                return r;
            }
            Mono {
                e: cal.e
                x: Math.round(14 * cal.e)
                y: Math.round(10 * cal.e)
                text: escritorio.meses[cal.hoy.getMonth()].charAt(0).toUpperCase() + escritorio.meses[cal.hoy.getMonth()].slice(1) + " " + cal.hoy.getFullYear()
                font.pixelSize: Math.round(12 * cal.e)
            }
            Grid {
                x: Math.round(8 * cal.e)
                y: Math.round(32 * cal.e)
                columns: 7
                readonly property real celda: (cal.width - 16 * cal.e) / 7
                Repeater {
                    model: ["L", "M", "X", "J", "V", "S", "D"]
                    Mono {
                        required property var modelData
                        e: cal.e
                        width: parent.celda
                        height: Math.round(20 * cal.e)
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pixelSize: Math.round(9 * cal.e)
                        color: Tema.gris
                    }
                }
                Repeater {
                    model: cal.casillas
                    Item {
                        id: casilla
                        required property var modelData
                        width: parent.celda
                        height: Math.round(25 * cal.e)
                        Rectangle {
                            anchors.centerIn: parent
                            visible: casilla.modelData.hoy
                            width: Math.round(22 * cal.e)
                            height: width
                            radius: width / 2
                            color: Tema.blanco
                        }
                        Mono {
                            e: cal.e
                            anchors.centerIn: parent
                            text: casilla.modelData.dia
                            font.bold: casilla.modelData.hoy
                            font.pixelSize: Math.round(10 * cal.e)
                            color: casilla.modelData.hoy ? Tema.oscuro
                                : !casilla.modelData.delMes ? Tema.claro(0.2)
                                : casilla.modelData.finde ? Tema.gris : Tema.texto
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wMusica
        Rectangle {
            id: tarjetaMusica
            property real e: 1
            readonly property var reproductor: Reproductor.actual
            readonly property string caratula: Reproductor.caratula(reproductor)
            readonly property int lado: Math.round(56 * e)
            width: Math.round(244 * e)
            height: lado + 2 * Math.round(12 * e)
            radius: Math.round(16 * e)
            color: escritorio.fondo

            // Carátula, o una nota
            ClippingRectangle {
                id: caja
                x: Math.round(12 * tarjetaMusica.e)
                anchors.verticalCenter: parent.verticalCenter
                width: tarjetaMusica.lado
                height: tarjetaMusica.lado
                radius: Math.round(10 * tarjetaMusica.e)
                color: Tema.claro(0.07)
                Text {
                    anchors.centerIn: parent
                    visible: tarjetaMusica.caratula === ""
                    text: "󰝚"
                    font.family: Tema.mono
                    font.pixelSize: Math.round(22 * tarjetaMusica.e)
                    color: Tema.texto
                }
                Image {
                    anchors.fill: parent
                    visible: tarjetaMusica.caratula !== ""
                    source: tarjetaMusica.caratula
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                    asynchronous: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !Widgets.editando
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Paneles.abrirPagina(escritorio.modelData, "multimedia", "centro")
                }
            }

            Column {
                anchors { left: caja.right; leftMargin: Math.round(12 * tarjetaMusica.e); right: parent.right; rightMargin: Math.round(12 * tarjetaMusica.e) }
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(8 * tarjetaMusica.e)

                Column {
                    width: parent.width
                    Mono {
                        e: tarjetaMusica.e
                        width: parent.width
                        elide: Text.ElideRight
                        text: tarjetaMusica.reproductor ? (Reproductor.titulo(tarjetaMusica.reproductor) || Reproductor.nombre(tarjetaMusica.reproductor)) : "Nada sonando"
                    }
                    Mono {
                        e: tarjetaMusica.e
                        width: parent.width
                        visible: text !== ""
                        elide: Text.ElideRight
                        text: tarjetaMusica.reproductor?.trackArtist ?? ""
                        font.bold: false
                        font.pixelSize: Math.round(9 * tarjetaMusica.e)
                        color: Tema.gris
                    }
                }
                Row {
                    spacing: Math.round(6 * tarjetaMusica.e)
                    Repeater {
                        model: [
                            {icono: "󰒮", accion: "previous"},
                            {icono: "", accion: "togglePlaying"},
                            {icono: "󰒭", accion: "next"}
                        ]
                        Rectangle {
                            id: boton
                            required property var modelData
                            width: Math.round(22 * tarjetaMusica.e)
                            height: width
                            radius: Math.round(6 * tarjetaMusica.e)
                            color: botonRaton.containsMouse && tarjetaMusica.reproductor ? Tema.claro(0.14) : Tema.claro(0.07)
                            Text {
                                anchors.centerIn: parent
                                text: boton.modelData.icono || (tarjetaMusica.reproductor?.isPlaying ? "󰏤" : "󰐊")
                                font.family: Tema.mono
                                font.pixelSize: Math.round(11 * tarjetaMusica.e)
                                color: tarjetaMusica.reproductor ? Tema.texto : Tema.tenue
                            }
                            MouseArea {
                                id: botonRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: tarjetaMusica.reproductor !== null && !Widgets.editando
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tarjetaMusica.reproductor[boton.modelData.accion]()
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var componentes: ({
        hora: wHora, agujas: wAgujas, disco: wDisco, temp: wTemp, ram: wRam, cpu: wCpu,
        bateria: wBateria, red: wRed, tiempo: wTiempo, calendario: wCalendario, musica: wMusica
    })

    // ------------------------------------------------ Una capa por widget
    Variants {
        model: Widgets.activos.filter(id => Widgets.info(id) !== null)

        PanelWindow {
            id: ventana
            required property string modelData
            readonly property string cual: modelData
            readonly property real e: escritorio.escala * Widgets.tam(cual)
            // La música, solo con algo sonando (editando, siempre)
            readonly property bool seVe: cual !== "musica" || Reproductor.actual !== null || Widgets.editando

            screen: escritorio.modelData
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "yoru-escritorio"
            // Editando, por encima de las ventanas (para colocarlos aunque
            // haya alguna abierta)
            WlrLayershell.layer: Widgets.editando ? WlrLayer.Top : WlrLayer.Bottom
            mask: Region { item: caja }

            // Dónde está: lo guardado, o su sitio en la columna
            readonly property var guardado: Widgets.sitio(cual)
            readonly property var enColumna: escritorio.columna[cual] ?? {x: 0, y: 0}
            function colocar() {
                if (raton.drag.active)
                    return;
                caja.x = guardado ? Math.round(guardado.x * width) : Math.round(enColumna.x);
                caja.y = guardado ? Math.round(guardado.y * height) : Math.round(enColumna.y);
            }
            onGuardadoChanged: colocar()
            onEnColumnaChanged: colocar()
            onWidthChanged: colocar()
            onHeightChanged: colocar()
            Component.onCompleted: colocar()

            Item {
                id: caja
                visible: ventana.seVe
                width: contenido.width
                height: contenido.height
                // Al aparecer (o al añadirlo), con un «pop»
                scale: 0.85
                opacity: 0
                Component.onCompleted: aparece.start()
                ParallelAnimation {
                    id: aparece
                    NumberAnimation { target: caja; property: "scale"; to: 1; duration: Tema.rebote; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: caja; property: "opacity"; to: 1; duration: Tema.normal }
                }

                Loader {
                    id: contenido
                    sourceComponent: escritorio.componentes[ventana.cual]
                    onLoaded: item.e = Qt.binding(() => ventana.e)
                }

                // Clic derecho = editar · editando: arrastrar y rueda
                MouseArea {
                    id: raton
                    anchors.fill: parent
                    // Sin editar solo el clic derecho: los botones de dentro
                    // (la música) siguen funcionando
                    acceptedButtons: Widgets.editando ? Qt.LeftButton | Qt.RightButton : Qt.RightButton
                    hoverEnabled: Widgets.editando
                    cursorShape: Widgets.editando ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                    drag.target: Widgets.editando ? caja : null
                    drag.threshold: 0
                    drag.minimumX: 0
                    drag.minimumY: 0
                    drag.maximumX: ventana.width - caja.width
                    drag.maximumY: ventana.height - caja.height
                    onClicked: e => {
                        if (e.button === Qt.RightButton)
                            Widgets.editando = !Widgets.editando;
                    }
                    onReleased: {
                        if (Widgets.editando)
                            Widgets.mover(ventana.cual, caja.x / ventana.width, caja.y / ventana.height);
                    }
                    onWheel: w => {
                        if (Widgets.editando)
                            Widgets.redimensionar(ventana.cual, Widgets.tam(ventana.cual) + (w.angleDelta.y > 0 ? 0.1 : -0.1));
                        else
                            w.accepted = false;
                    }
                }

                // Editando: un marco, su nombre y la × para quitarlo
                Rectangle {
                    visible: Widgets.editando
                    anchors { fill: parent; margins: -6 }
                    radius: Tema.esquina(18)
                    color: raton.containsMouse || raton.drag.active ? Tema.claro(0.08) : "transparent"
                    border.width: 2
                    border.color: raton.drag.active ? Tema.blanco : Tema.claro(0.45)
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                }
                // (el nombre, solo en el que tiene el ratón: si no, se pisaban)
                Rectangle {
                    visible: Widgets.editando && (raton.containsMouse || raton.drag.active)
                    z: 2
                    anchors { left: parent.left; bottom: parent.top; bottomMargin: 10; leftMargin: -6 }
                    width: etiqueta.implicitWidth + 16
                    height: 22
                    radius: 11
                    color: Tema.sombra(0.85)
                    Texto {
                        id: etiqueta
                        anchors.centerIn: parent
                        text: (Widgets.info(ventana.cual)?.nombre ?? "") + "  " + Math.round(Widgets.tam(ventana.cual) * 100) + "%"
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    visible: Widgets.editando
                    anchors { right: parent.right; top: parent.top; margins: -14 }
                    width: 24
                    height: 24
                    radius: 12
                    color: quitarRaton.containsMouse ? Tema.rojo : Tema.sombra(0.9)
                    border.width: 1
                    border.color: Tema.claro(0.3)
                    Texto {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.pixelSize: 13
                        color: quitarRaton.containsMouse ? Tema.oscuro : Tema.texto
                    }
                    MouseArea {
                        id: quitarRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Widgets.alternar(ventana.cual, false)
                    }
                }
            }
        }
    }

    // --------------------------------------- Editando: la barra de arriba
    LazyLoader {
        active: Widgets.editando && escritorio.modelData === (Quickshell.screens.find(s =>
            s.name === Niri.escritorios.find(e => e.is_focused)?.output) ?? Quickshell.screens[0])

        PanelWindow {
            id: barraEdicion
            screen: escritorio.modelData
            anchors { top: true }
            margins { top: 60 }
            implicitWidth: herramientas.width
            implicitHeight: herramientas.height + (anadir.abierto ? lista.height + 8 : 0)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "yoru-escritorio"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Widgets.editando = false
                Keys.onReturnPressed: Widgets.editando = false
            }

            Rectangle {
                id: herramientas
                width: fila.implicitWidth + 16
                height: 44
                radius: 22
                color: Tema.panel
                border.width: 1
                border.color: Tema.claro(0.2)
                Row {
                    id: fila
                    anchors.centerIn: parent
                    spacing: 6
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 8
                        rightPadding: 6
                        text: "󰏫  Arrastra para mover · rueda = tamaño"
                        font.bold: false
                        font.pixelSize: 12
                        color: Tema.gris
                    }
                    component Boton: Rectangle {
                        id: boton
                        property string texto: ""
                        property bool fuerte: false
                        signal clic()
                        anchors.verticalCenter: parent.verticalCenter
                        width: t.implicitWidth + 22
                        height: 30
                        radius: 15
                        color: fuerte ? (r.containsMouse ? Qt.lighter(Tema.blanco, 1.1) : Tema.blanco)
                            : r.containsMouse ? Tema.cajaHover : Tema.caja
                        Texto {
                            id: t
                            anchors.centerIn: parent
                            text: boton.texto
                            font.pixelSize: 12
                            color: boton.fuerte ? Tema.oscuro : Tema.texto
                        }
                        MouseArea { id: r; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: boton.clic() }
                    }
                    Boton {
                        id: anadir
                        property bool abierto: false
                        texto: "󰐕  Añadir"
                        visible: Widgets.catalogo.some(w => !Widgets.activo(w.id))
                        onClic: abierto = !abierto
                    }
                    Boton {
                        texto: "󰑓  Restablecer"
                        onClic: Widgets.restablecer()
                    }
                    Boton {
                        texto: "Listo"
                        fuerte: true
                        onClic: Widgets.editando = false
                    }
                }
            }

            // Los que no están, para añadirlos
            Rectangle {
                id: lista
                visible: anadir.abierto
                y: herramientas.height + 8
                width: herramientas.width
                height: columnaLista.implicitHeight + 12
                radius: 16
                color: Tema.panel
                border.width: 1
                border.color: Tema.claro(0.2)
                Column {
                    id: columnaLista
                    x: 6; y: 6
                    width: parent.width - 12
                    Repeater {
                        model: Widgets.catalogo.filter(w => !Widgets.activo(w.id))
                        Fila {
                            required property var modelData
                            width: columnaLista.width
                            icono: modelData.icono
                            titulo: modelData.nombre
                            detalle: modelData.detalle
                            onClic: {
                                Widgets.alternar(modelData.id, true);
                                if (!Widgets.catalogo.some(w => !Widgets.activo(w.id)))
                                    anadir.abierto = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
