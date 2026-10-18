// ============================================================================
//  Pestaña Pantallas de Ajustes — colocar los monitores arrastrándolos
//
//  Se arrastra cada pantalla hasta dejarla como está en la mesa: al soltarla
//  se pega al borde de la otra (y se alinea arriba, al centro o abajo si
//  queda cerca). Debajo, la resolución, la escala y demás de la elegida.
//
//  Todo se guarda al momento en niri/local.kdl con scripts/pantallas.py, y
//  niri lo aplica nada más guardarlo.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Column {
    id: pestana

    property bool activa: false      // la pestaña está a la vista: se lee de nuevo
    property var pantallas: []       // las de pantallas.py leer, con x/y siempre puestos
    property bool apagarPortatil: false
    property string elegida: ""      // nombre (conector) de la pantalla elegida
    property string error: ""
    property bool guardando: false

    readonly property var actual: pantallas.find(p => p.nombre === elegida) ?? null
    readonly property int encendidas: pantallas.filter(p => p.encendida).length
    readonly property bool hayPortatil: pantallas.some(p => p.interna)

    spacing: 10
    onActivaChanged: if (activa) leer()

    // -------------------------------------------------------------- Datos
    function leer() {
        error = "";
        lector.running = true;
    }

    // Tamaño en el escritorio (el que ocupa al colocarla): resolución / escala
    function tam(p) {
        const w = Math.round(p.modo.w / p.escala), h = Math.round(p.modo.h / p.escala);
        return ["90", "270", "Flipped90", "Flipped270"].includes(p.giro) ? {w: h, h: w} : {w: w, h: h};
    }

    function copia(lista) {
        return lista.map(p => Object.assign({}, p));
    }

    // Que la de más arriba a la izquierda empiece en 0,0 (niri no lo necesita,
    // pero así local.kdl se lee mejor)
    function normalizar(lista) {
        const mx = Math.min(...lista.map(p => p.x)), my = Math.min(...lista.map(p => p.y));
        lista.forEach(p => { p.x -= mx; p.y -= my; });
        return lista;
    }

    // Dónde se queda la pantalla i si se suelta con su esquina en (x, y):
    // pegada al lado más cercano de otra, sin pisar a ninguna
    function encajar(lista, i, x, y) {
        const a = tam(lista[i]);
        const iman = 14 / Math.max(vista.k, 0.01);   // 14 px en el dibujo
        const minimo = 80;                           // que se toquen al menos esto
        const pegar = (v, ...puntos) => {
            for (const q of puntos)
                if (Math.abs(v - q) < iman)
                    return q;
            return v;
        };
        let mejor = null;
        lista.forEach((b, j) => {
            if (j === i)
                return;
            const t = tam(b);
            const fy = Math.max(b.y - a.h + minimo, Math.min(y, b.y + t.h - minimo));
            const fx = Math.max(b.x - a.w + minimo, Math.min(x, b.x + t.w - minimo));
            const ay = pegar(fy, b.y, b.y + t.h - a.h, Math.round(b.y + (t.h - a.h) / 2));
            const ax = pegar(fx, b.x, b.x + t.w - a.w, Math.round(b.x + (t.w - a.w) / 2));
            const sitios = [
                {x: b.x + t.w, y: ay},     // a su derecha
                {x: b.x - a.w, y: ay},     // a su izquierda
                {x: ax, y: b.y + t.h},     // debajo
                {x: ax, y: b.y - a.h}      // encima
            ];
            for (const s of sitios) {
                const pisa = lista.some((c, k) => {
                    if (k === i)
                        return false;
                    const u = tam(c);
                    return s.x < c.x + u.w && s.x + a.w > c.x && s.y < c.y + u.h && s.y + a.h > c.y;
                });
                const d = Math.hypot(s.x - x, s.y - y);
                if (!pisa && (mejor === null || d < mejor.d))
                    mejor = {x: Math.round(s.x), y: Math.round(s.y), d: d};
            }
        });
        return mejor ?? {x: x, y: y};
    }

    // Tras cambiar la resolución o la escala de una, las demás se vuelven a
    // pegar a ella (si no, quedaría un hueco o se pisarían)
    function repegar(lista, cambiada) {
        lista.forEach((p, i) => {
            if (i !== cambiada) {
                const s = encajar(lista, i, p.x, p.y);
                p.x = s.x;
                p.y = s.y;
            }
        });
        return normalizar(lista);
    }

    function guardar(lista) {
        pantallas = lista;
        error = "";
        guardando = true;
        escritor.command = [Quickshell.shellPath("scripts/pantallas.py"), "guardar",
            JSON.stringify({pantallas: lista, apagarPortatil: apagarPortatil})];
        escritor.running = true;
    }

    function cambiar(campos, recolocar) {
        const lista = copia(pantallas);
        const i = lista.findIndex(p => p.nombre === elegida);
        if (i < 0)
            return;
        Object.assign(lista[i], campos);
        guardar(recolocar ? repegar(lista, i) : lista);
    }

    function soltar(i, dx, dy) {
        const lista = copia(pantallas);
        const s = encajar(lista, i, lista[i].x + dx, lista[i].y + dy);
        lista[i].x = s.x;
        lista[i].y = s.y;
        guardar(normalizar(lista));
    }

    // El portátil se enciende y apaga al momento con niri msg (en local.kdl
    // nunca se apaga: sin monitor te quedarías a oscuras); los externos, en
    // local.kdl
    function encender(v) {
        const p = actual;
        if (!p || (!v && encendidas <= 1))
            return;
        if (p.interna) {
            Quickshell.execDetached(["niri", "msg", "output", p.nombre, v ? "on" : "off"]);
            relectura.restart();
        } else {
            cambiar({encendida: v}, false);
        }
    }

    Process {
        id: lector
        command: [Quickshell.shellPath("scripts/pantallas.py"), "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    pestana.error = "No se pudieron leer las pantallas";
                    return;
                }
                const lista = d.pantallas;
                // Las apagadas sin sitio guardado, a la izquierda de las demás
                const puestas = lista.filter(p => p.x !== null);
                lista.forEach(p => {
                    if (p.x === null) {
                        const minX = puestas.length ? Math.min(...puestas.map(q => q.x)) : 0;
                        const minY = puestas.length ? Math.min(...puestas.map(q => q.y)) : 0;
                        p.x = minX - pestana.tam(p).w;
                        p.y = minY;
                        puestas.push(p);
                    }
                });
                pestana.apagarPortatil = d.apagarPortatil;
                pestana.pantallas = pestana.normalizar(lista);
                if (!pestana.actual)
                    pestana.elegida = (lista.find(p => p.encendida) ?? lista[0])?.nombre ?? "";
            }
        }
    }

    Process {
        id: escritor
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            pestana.guardando = false;
            if (codigo !== 0)
                pestana.error = errores.text.trim() || "No se pudo guardar";
            // Lo que de verdad ha aplicado niri
            relectura.restart();
        }
    }

    Timer {
        id: relectura
        interval: 600
        onTriggered: pestana.leer()
    }

    // ------------------------------------------------------------- Dibujo
    Rectangle {
        id: lienzo
        width: parent.width
        height: 210
        radius: 12
        color: Tema.caja
        border.width: 1
        border.color: Tema.claro(0.05)
        clip: true

        // Escala del dibujo y dónde cae el 0,0 del escritorio
        QtObject {
            id: vista
            readonly property var caja: {
                const ps = pestana.pantallas;
                if (!ps.length)
                    return {x: 0, y: 0, w: 1, h: 1};
                const x0 = Math.min(...ps.map(p => p.x)), y0 = Math.min(...ps.map(p => p.y));
                const x1 = Math.max(...ps.map(p => p.x + pestana.tam(p).w));
                const y1 = Math.max(...ps.map(p => p.y + pestana.tam(p).h));
                return {x: x0, y: y0, w: x1 - x0, h: y1 - y0};
            }
            readonly property real k: Math.min((lienzo.width - 80) / caja.w, (lienzo.height - 60) / caja.h)
            readonly property real ox: (lienzo.width - caja.w * k) / 2 - caja.x * k
            readonly property real oy: (lienzo.height - caja.h * k) / 2 - caja.y * k
        }

        // Dónde quedará la que se arrastra
        property var fantasma: null
        Rectangle {
            visible: lienzo.fantasma !== null
            x: lienzo.fantasma ? Math.round(vista.ox + lienzo.fantasma.x * vista.k) : 0
            y: lienzo.fantasma ? Math.round(vista.oy + lienzo.fantasma.y * vista.k) : 0
            width: lienzo.fantasma ? Math.round(lienzo.fantasma.w * vista.k) : 0
            height: lienzo.fantasma ? Math.round(lienzo.fantasma.h * vista.k) : 0
            radius: 8
            color: "transparent"
            border.width: 2
            border.color: Tema.claro(0.35)
        }

        Repeater {
            model: pestana.pantallas

            Rectangle {
                id: pantalla
                required property var modelData
                required property int index
                readonly property var t: pestana.tam(modelData)
                readonly property bool elegida: pestana.elegida === modelData.nombre
                property point tiron: Qt.point(0, 0)

                x: Math.round(vista.ox + modelData.x * vista.k + tiron.x)
                y: Math.round(vista.oy + modelData.y * vista.k + tiron.y)
                z: raton.pressed ? 2 : 1
                width: Math.round(t.w * vista.k)
                height: Math.round(t.h * vista.k)
                radius: 8
                color: elegida ? Tema.claro(0.16) : raton.containsMouse ? Tema.claro(0.12) : Tema.claro(0.08)
                border.width: elegida ? 2 : 1
                border.color: elegida ? Tema.blanco : Tema.claro(0.25)
                opacity: modelData.encendida ? 1 : 0.45

                Behavior on x { enabled: !raton.pressed; NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !raton.pressed; NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Tema.rapida } }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 2
                    Texto {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: pantalla.modelData.interna ? "󰌢" : "󰍹"
                        font.pixelSize: Math.max(16, Math.min(30, pantalla.height / 5))
                        color: pantalla.elegida ? Tema.blanco : Tema.texto
                    }
                    Texto {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: pantalla.modelData.interna ? "Portátil" : pantalla.modelData.etiqueta
                        font.pixelSize: 12
                    }
                    Texto {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: pantalla.modelData.encendida
                            ? pantalla.modelData.modo.w + "×" + pantalla.modelData.modo.h
                              + (pantalla.modelData.escala !== 1 ? " · " + Math.round(pantalla.modelData.escala * 100) + "%" : "")
                            : "Apagada"
                        font.pixelSize: 11
                        font.bold: false
                        color: Tema.gris
                    }
                }

                MouseArea {
                    id: raton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true
                    property point inicio

                    onPressed: m => {
                        inicio = mapToItem(lienzo, m.x, m.y);
                        pestana.elegida = pantalla.modelData.nombre;
                    }
                    onPositionChanged: m => {
                        if (!pressed)
                            return;
                        const p = mapToItem(lienzo, m.x, m.y);
                        pantalla.tiron = Qt.point(p.x - inicio.x, p.y - inicio.y);
                        const s = pestana.encajar(pestana.pantallas, pantalla.index,
                            pantalla.modelData.x + pantalla.tiron.x / vista.k,
                            pantalla.modelData.y + pantalla.tiron.y / vista.k);
                        lienzo.fantasma = {x: s.x, y: s.y, w: pantalla.t.w, h: pantalla.t.h};
                    }
                    onReleased: {
                        // Números sueltos: «tiron» es un point y leerlo da una
                        // referencia, que se pondría a 0 con la línea de abajo
                        const dx = pantalla.tiron.x, dy = pantalla.tiron.y;
                        pantalla.tiron = Qt.point(0, 0);
                        lienzo.fantasma = null;
                        if (Math.hypot(dx, dy) > 4)
                            pestana.soltar(pantalla.index, dx / vista.k, dy / vista.k);
                    }
                    onCanceled: {
                        pantalla.tiron = Qt.point(0, 0);
                        lienzo.fantasma = null;
                    }
                }
            }
        }

        Texto {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
            text: pestana.guardando ? "Guardando…" : "Arrastra las pantallas para colocarlas como en tu mesa"
            font.pixelSize: 11
            font.bold: false
            color: Tema.gris
        }
    }

    Texto {
        width: parent.width
        visible: pestana.error !== ""
        text: pestana.error
        color: Tema.rojo
        font.pixelSize: 12
        font.bold: false
        wrapMode: Text.Wrap
    }

    // ----------------------------------------------- La pantalla elegida
    Row {
        visible: pestana.actual !== null
        leftPadding: 4
        spacing: 8
        Texto {
            text: pestana.actual?.interna ? "󰌢" : "󰍹"
            font.pixelSize: 16
            color: Tema.blanco
        }
        Texto {
            text: pestana.actual
                ? pestana.actual.etiqueta + Tema.suave("  ·  " + pestana.actual.nombre
                    + (pestana.actual.pulgadas ? "  ·  " + String(pestana.actual.pulgadas).replace(".", ",") + "″" : ""))
                : ""
            textFormat: Text.StyledText
            font.pixelSize: 13
        }
    }

    Row {
        visible: pestana.actual !== null
        width: parent.width
        spacing: 16

        readonly property real mitad: (width - spacing) / 2

        // Izquierda: resolución, frecuencia y escala
        Column {
            width: parent.mitad
            spacing: 4

            // Resoluciones distintas, de mayor a menor (las 3 primeras)
            readonly property var resoluciones: {
                const p = pestana.actual;
                if (!p)
                    return [];
                const vistas = [];
                p.modos.forEach(m => {
                    if (!vistas.some(v => v.w === m.w && v.h === m.h))
                        vistas.push({w: m.w, h: m.h});
                });
                vistas.sort((a, b) => b.w * b.h - a.w * a.h);
                const lista = vistas.slice(0, 3);
                if (!lista.some(v => v.w === p.modo.w && v.h === p.modo.h))
                    lista[2] = {w: p.modo.w, h: p.modo.h};
                return lista;
            }
            // Frecuencias de la resolución actual, sin repetir (60 y 59,94...)
            readonly property var frecuencias: {
                const p = pestana.actual;
                if (!p)
                    return [];
                const hz = [];
                p.modos.forEach(m => {
                    if (m.w === p.modo.w && m.h === p.modo.h && !hz.includes(m.hz))
                        hz.push(m.hz);
                });
                return hz.sort((a, b) => b - a).slice(0, 3);
            }

            Titular { texto: "Resolución"; width: parent.width }
            Opciones {
                width: parent.width
                opciones: parent.resoluciones.map(r => ({id: r.w + "x" + r.h, texto: r.w + "×" + r.h}))
                valor: pestana.actual ? pestana.actual.modo.w + "x" + pestana.actual.modo.h : ""
                onElegir: id => {
                    const [w, h] = id.split("x").map(Number);
                    const p = pestana.actual;
                    const de = p.modos.filter(m => m.w === w && m.h === h);
                    const m = de.find(m => m.preferido) ?? de.sort((a, b) => b.hz - a.hz)[0];
                    pestana.cambiar({modo: {w: m.w, h: m.h, hz: m.hz}}, true);
                }
            }

            Titular {
                visible: parent.frecuencias.length > 1
                texto: "Frecuencia"
                width: parent.width
            }
            Opciones {
                visible: parent.frecuencias.length > 1
                width: parent.width
                opciones: parent.frecuencias.map(hz => ({id: String(hz), texto: String(Math.round(hz / 10) / 100).replace(".", ",") + " Hz"}))
                valor: pestana.actual ? String(pestana.actual.modo.hz) : ""
                onElegir: id => pestana.cambiar({modo: Object.assign({}, pestana.actual.modo, {hz: Number(id)})}, false)
            }

            Titular { texto: "Tamaño de todo (escala)"; width: parent.width }
            Opciones {
                width: parent.width
                opciones: [1, 1.25, 1.5, 1.75, 2].map(e => ({id: String(e), texto: Math.round(e * 100) + "%"}))
                valor: pestana.actual ? String(pestana.actual.escala) : ""
                onElegir: id => pestana.cambiar({escala: Number(id)}, true)
            }
        }

        // Derecha: encendida, principal y lo del portátil
        Column {
            width: parent.mitad
            spacing: 2

            Item { width: 1; height: 26 }
            Interruptor {
                width: parent.width
                titulo: "Encendida"
                detalle: pestana.encendidas <= 1 && pestana.actual?.encendida ? "Es la única encendida"
                    : pestana.actual?.interna ? "Mod+Alt+P la enciende si no ves nada" : ""
                activo: pestana.actual?.encendida ?? false
                opacity: pestana.encendidas <= 1 && activo ? 0.5 : 1
                onCambiar: v => pestana.encender(v)
            }
            Interruptor {
                width: parent.width
                titulo: "Empezar en esta"
                detalle: "Al entrar, el foco está aquí"
                activo: pestana.actual?.principal ?? false
                onCambiar: v => {
                    const lista = pestana.copia(pestana.pantallas);
                    lista.forEach(p => p.principal = v && p.nombre === pestana.elegida);
                    pestana.guardar(lista);
                }
            }
            Interruptor {
                visible: pestana.hayPortatil
                width: parent.width
                titulo: "Solo el monitor"
                detalle: "Al entrar, apaga el portátil si hay otro"
                activo: pestana.apagarPortatil
                onCambiar: v => {
                    pestana.apagarPortatil = v;
                    pestana.guardar(pestana.copia(pestana.pantallas));
                }
            }
            Item { width: 1; height: 6 }
            Opciones {
                width: parent.width
                opciones: [{id: "auto", icono: "󰑓", texto: "Colocación automática"}]
                onElegir: {
                    restablecedor.running = true;
                }
            }
            Process {
                id: restablecedor
                command: [Quickshell.shellPath("scripts/pantallas.py"), "restablecer"]
                onExited: relectura.restart()
            }
        }
    }
}
