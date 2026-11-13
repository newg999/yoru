// ============================================================================
//  IconosEscritorio — los archivos, carpetas y accesos directos de tu carpeta
//  Escritorio, sobre el fondo, como en Windows. Las ventanas siguen siendo
//  las de niri: esto vive debajo de ellas y se ve en los escritorios vacíos.
//
//    ┌──────┐┌──────┐
//    │  📁  ││  🖼  │      en columnas desde arriba a la izquierda; cada uno
//    │ fotos││ playa│      se queda donde lo dejes (en una rejilla)
//    └──────┘└──────┘
//
//    clic = elegir (Ctrl+clic: varios; arrastrar en el vacío: recuadro)
//    doble clic / Enter = abrir · arrastrar = moverlos
//    clic derecho = su menú (o el del escritorio, en el vacío)
//    Supr = a la papelera · F2 = cambiar el nombre · Ctrl+A / C / V
//    soltar aquí archivos desde Archivos = traerlos (o copiarlos)
//
//  Lo que hay lo vigila scripts/escritorio.py; el sitio de cada uno, su
//  tamaño y si salen: Ajustes › Escritorio (comun/Widgets.qml).
//  Solo en la primera pantalla, como en Windows.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: capa
    required property ShellScreen modelData

    screen: modelData
    anchors { left: true; right: true; top: true; bottom: true }
    color: "transparent"
    // Respeta la barra (su zona exclusiva): los iconos no quedan debajo
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.namespace: "yoru-iconos"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ------------------------------------------------------------ Datos
    property string carpeta: ""
    property var cosas: []
    Process {
        id: vigia
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/escritorio.py"]
        stdout: SplitParser {
            onRead: linea => {
                try {
                    const d = JSON.parse(linea);
                    capa.carpeta = d.carpeta;
                    capa.cosas = d.cosas;
                } catch (e) {}
            }
        }
        // Si se cae, otra vez al rato
        onRunningChanged: if (!running) revivir.start()
    }
    Timer { id: revivir; interval: 3000; onTriggered: vigia.running = true }

    function hacer(cmd) { Quickshell.execDetached(cmd); }
    function uri(ruta) { return "file://" + encodeURI(ruta); }

    // ---------------------------------------------------------- Rejilla
    readonly property real t: Widgets.tamIconos
    readonly property int celdaAncho: Math.round(92 * t)
    readonly property int celdaAlto: Math.round(100 * t)
    readonly property int margen: 14
    readonly property int filas: Math.max(1, Math.floor((height - 2 * margen) / celdaAlto))
    readonly property int columnas: Math.max(1, Math.floor((width - 2 * margen) / celdaAncho))

    // Dónde va cada uno: el sitio guardado si cabe y está libre; los demás,
    // en el primer hueco, por columnas
    readonly property var sitios: {
        const guardados = Widgets.sitiosIconos;
        const ocupado = {};
        const r = {};
        const libre = (c, f) => c >= 0 && f >= 0 && c < columnas && f < filas && !ocupado[c + "," + f];
        for (const x of cosas) {
            const g = guardados[x.nombre];
            if (g && libre(g[0], g[1])) {
                r[x.nombre] = g;
                ocupado[g[0] + "," + g[1]] = true;
            }
        }
        let c = 0, f = 0;
        for (const x of cosas) {
            if (r[x.nombre])
                continue;
            while (c < columnas && !libre(c, f)) {
                f++;
                if (f >= filas) { f = 0; c++; }
            }
            // No caben: se apilan en la última celda
            r[x.nombre] = c < columnas ? [c, f] : [columnas - 1, filas - 1];
            ocupado[r[x.nombre][0] + "," + r[x.nombre][1]] = true;
        }
        return r;
    }
    // Lo de ahora, para guardarlo (solo lo que existe)
    function guardar(cambios) {
        const s = {};
        for (const x of cosas)
            s[x.nombre] = cambios[x.nombre] ?? sitios[x.nombre];
        Widgets.colocarIconos(s);
    }
    function celdaEn(px, py) {
        return [Math.max(0, Math.min(columnas - 1, Math.floor((px - margen) / celdaAncho))),
                Math.max(0, Math.min(filas - 1, Math.floor((py - margen) / celdaAlto)))];
    }

    // ------------------------------------------------------- Selección
    property var elegidos: ({})            // nombre → true
    function elegido(n) { return elegidos[n] === true; }
    function elegir(n, sumar) {
        const e = sumar ? Object.assign({}, elegidos) : {};
        if (sumar && e[n]) delete e[n]; else e[n] = true;
        elegidos = e;
    }
    function nada() { elegidos = {}; }
    function todos() {
        const e = {};
        for (const x of cosas) e[x.nombre] = true;
        elegidos = e;
    }
    readonly property var lista: cosas.filter(x => elegidos[x.nombre])
    // Si un archivo desaparece, fuera de la selección
    onCosasChanged: {
        const e = {};
        for (const x of cosas)
            if (elegidos[x.nombre]) e[x.nombre] = true;
        elegidos = e;
        // Lo recién creado («Carpeta nueva»): a cambiarle el nombre
        if (nombrar !== "" && cosas.some(x => x.nombre === nombrar)) {
            elegidos = ({ [nombrar]: true });
            renombrando = nombrar;
            nombrar = "";
        }
    }

    // ------------------------------------------------------- Acciones
    function abrir(x) {
        if (x.tipo === "acceso" && x.nombre.endsWith(".desktop"))
            hacer(["gio", "launch", x.ruta]);
        else
            hacer(["xdg-open", x.ruta]);
    }
    function abrirElegidos() { lista.forEach(abrir); }
    function papelera() {
        if (lista.length > 0)
            hacer(["gio", "trash"].concat(lista.map(x => x.ruta)));
    }
    function copiar() {
        if (lista.length > 0)
            hacer(["wl-copy", "--type", "text/uri-list", lista.map(x => uri(x.ruta)).join("\r\n")]);
    }
    function pegar() {
        hacer(["sh", "-c", 'cd "$1" && wl-paste --no-newline --type text/uri-list 2>/dev/null | tr -d "\\r" | '
            + 'while read -r u; do case "$u" in file://*) gio copy -r "$u" . 2>/dev/null || true;; esac; done',
            "sh", carpeta]);
    }
    // Un nombre que no esté cogido: «Carpeta nueva», «Carpeta nueva 2»...
    function libreNombre(base, ext) {
        let n = base + ext, i = 2;
        while (cosas.some(x => x.nombre === n))
            n = base + " " + (i++) + ext;
        return n;
    }
    property string nombrar: ""          // lo que se acaba de crear
    function nueva(carpetaNueva) {
        const n = carpetaNueva ? libreNombre("Carpeta nueva", "") : libreNombre("Documento nuevo", ".txt");
        nombrar = n;
        hacer(carpetaNueva ? ["mkdir", carpeta + "/" + n] : ["touch", carpeta + "/" + n]);
    }
    property string renombrando: ""
    function renombrar(viejo, nuevo) {
        renombrando = "";
        nuevo = nuevo.trim().replace(/\//g, "-");
        if (nuevo === "" || nuevo === viejo || cosas.some(x => x.nombre === nuevo))
            return;
        // Que conserve su sitio
        const s = Object.assign({}, sitios);
        s[nuevo] = s[viejo];
        delete s[viejo];
        Widgets.colocarIconos(s);
        hacer(["gio", "rename", carpeta + "/" + viejo, nuevo]);
        elegidos = ({ [nuevo]: true });
    }

    // ------------------------------------------------- Arrastrar iconos
    property bool moviendo: false
    property point desplazamiento: Qt.point(0, 0)
    function soltar() {
        if (!moviendo)
            return;
        const dc = Math.round(desplazamiento.x / celdaAncho);
        const df = Math.round(desplazamiento.y / celdaAlto);
        moviendo = false;
        desplazamiento = Qt.point(0, 0);
        if (dc === 0 && df === 0)
            return;
        // Los que no se mueven siguen donde están; los movidos, a su celda
        // o, si está cogida, a la libre más cercana
        const ocupado = {};
        for (const x of cosas)
            if (!elegidos[x.nombre]) ocupado[sitios[x.nombre]] = true;
        const nuevos = {};
        for (const x of lista) {
            const s = sitios[x.nombre];
            let c = Math.max(0, Math.min(columnas - 1, s[0] + dc));
            let f = Math.max(0, Math.min(filas - 1, s[1] + df));
            const hueco = cercano(c, f, ocupado);
            ocupado[hueco] = true;
            nuevos[x.nombre] = hueco;
        }
        guardar(nuevos);
    }
    function cercano(c, f, ocupado) {
        for (let d = 0; d < columnas + filas; d++)
            for (let dx = -d; dx <= d; dx++)
                for (const dy of [d - Math.abs(dx), -(d - Math.abs(dx))]) {
                    const cc = c + dx, ff = f + dy;
                    if (cc >= 0 && ff >= 0 && cc < columnas && ff < filas && !ocupado[[cc, ff]])
                        return [cc, ff];
                }
        return [c, f];
    }

    // ---------------------------------------------------------- Menú
    property var menuDe: null            // la cosa (o «vacío»)
    property point menuEn: Qt.point(0, 0)
    readonly property bool menuAbierto: menuDe !== null
    function abrirMenu(de, px, py) {
        menuDe = de;
        menuEn = Qt.point(px, py);
    }
    readonly property var opcionesMenu: {
        if (!menuDe)
            return [];
        if (menuDe === "vacio")
            return [
                {icono: "󰉗", texto: "Carpeta nueva", hacer: () => nueva(true)},
                {icono: "󰈔", texto: "Documento de texto nuevo", hacer: () => nueva(false)},
                {icono: "󰆒", texto: "Pegar", atajo: "Ctrl+V", hacer: pegar},
                {raya: true},
                {icono: "󰉋", texto: "Abrir en Archivos", hacer: () => hacer(["xdg-open", carpeta])},
                {icono: "󰒺", texto: "Ordenar por nombre", hacer: Widgets.ordenarIconos},
                {icono: "󰒓", texto: "Ajustes del escritorio", hacer: () => Paneles.alternarAjustes("escritorio")}
            ];
        const varios = lista.length > 1;
        return [
            {icono: "󰏌", texto: varios ? "Abrir " + lista.length : "Abrir", atajo: "Enter", hacer: abrirElegidos},
            {icono: "󰉋", texto: "Mostrar en Archivos", hacer: () => hacer(["nautilus", "--select", menuDe.ruta])},
            {raya: true},
            {icono: "󰆏", texto: "Copiar", atajo: "Ctrl+C", hacer: copiar},
            {icono: "󰅍", texto: "Copiar la ruta", hacer: () => hacer(["wl-copy", lista.map(x => x.ruta).join("\n")])},
            {icono: "󰑕", texto: "Cambiar el nombre", atajo: "F2", oculta: varios, hacer: () => renombrando = menuDe.nombre},
            {raya: true},
            {icono: "󰩹", texto: "Mover a la papelera", atajo: "Supr", peligro: true, hacer: papelera}
        ].filter(o => !o.oculta);
    }

    // ------------------------------------------------------- Teclado
    Item {
        id: teclas
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (capa.renombrando !== "")
                return;
            if (e.key === Qt.Key_Escape) { capa.menuDe = null; capa.nada(); }
            else if (e.key === Qt.Key_Delete) capa.papelera();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) capa.abrirElegidos();
            else if (e.key === Qt.Key_F2 && capa.lista.length === 1) capa.renombrando = capa.lista[0].nombre;
            else if (ctrl && e.key === Qt.Key_A) capa.todos();
            else if (ctrl && e.key === Qt.Key_C) capa.copiar();
            else if (ctrl && e.key === Qt.Key_V) capa.pegar();
            else return;
            e.accepted = true;
        }
    }

    // --------------------------------------- El vacío: recuadro y menú
    MouseArea {
        id: vacio
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point desde: Qt.point(0, 0)
        property bool recuadro: false
        onPressed: e => {
            teclas.forceActiveFocus();
            capa.menuDe = null;
            if (e.button === Qt.RightButton) {
                capa.nada();
                capa.abrirMenu("vacio", e.x, e.y);
                return;
            }
            if (!(e.modifiers & Qt.ControlModifier))
                capa.nada();
            desde = Qt.point(e.x, e.y);
        }
        onPositionChanged: e => {
            if (!pressed || !(pressedButtons & Qt.LeftButton))
                return;
            recuadro = true;
            caja.x = Math.min(desde.x, e.x);
            caja.y = Math.min(desde.y, e.y);
            caja.width = Math.abs(e.x - desde.x);
            caja.height = Math.abs(e.y - desde.y);
            // Los que toca el recuadro
            const s = {};
            for (const x of capa.cosas) {
                const [c, f] = capa.sitios[x.nombre];
                const ix = capa.margen + c * capa.celdaAncho, iy = capa.margen + f * capa.celdaAlto;
                if (ix < caja.x + caja.width && ix + capa.celdaAncho > caja.x
                        && iy < caja.y + caja.height && iy + capa.celdaAlto > caja.y)
                    s[x.nombre] = true;
            }
            capa.elegidos = s;
        }
        onReleased: recuadro = false
    }
    Rectangle {
        id: caja
        visible: vacio.recuadro
        color: Tema.conAlfa(Tema.blanco, 0.12)
        border.width: 1
        border.color: Tema.conAlfa(Tema.blanco, 0.6)
        radius: Tema.esquina(4)
    }

    // Soltar archivos desde Archivos: se traen (o se copian, según diga él)
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            const urls = drop.urls.map(u => String(u)).filter(u => u.startsWith("file://"));
            const dentro = urls.filter(u => decodeURIComponent(u.slice(7)).startsWith(capa.carpeta + "/"));
            const fuera = urls.filter(u => !dentro.includes(u));
            if (fuera.length === 0)
                return;
            // Que salgan donde se soltaron
            const s = Object.assign({}, capa.sitios);
            const ocupado = {};
            for (const k in s) ocupado[s[k]] = true;
            const [c, f] = capa.celdaEn(drop.x, drop.y);
            for (const u of fuera) {
                const n = decodeURIComponent(u.split("/").pop());
                const h = capa.cercano(c, f, ocupado);
                ocupado[h] = true;
                s[n] = h;
            }
            Widgets.colocarIconos(s);
            const mover = drop.proposedAction === Qt.MoveAction;
            capa.hacer(["gio", mover ? "move" : "copy"].concat(fuera, [capa.carpeta + "/"]));
            drop.acceptProposedAction();
        }
    }

    // ----------------------------------------------------- Los iconos
    Repeater {
        model: capa.cosas

        Item {
            id: icono
            required property var modelData
            readonly property var x0: capa.sitios[modelData.nombre] ?? [0, 0]
            readonly property bool sel: capa.elegido(modelData.nombre)
            readonly property bool editando: capa.renombrando === modelData.nombre
            readonly property bool arrastrado: capa.moviendo && sel

            width: capa.celdaAncho - 4
            height: capa.celdaAlto - 4
            x: capa.margen + x0[0] * capa.celdaAncho + 2 + (arrastrado ? capa.desplazamiento.x : 0)
            y: capa.margen + x0[1] * capa.celdaAlto + 2 + (arrastrado ? capa.desplazamiento.y : 0)
            z: arrastrado ? 10 : sel ? 2 : 1
            opacity: arrastrado ? 0.75 : 1
            Behavior on x { enabled: !capa.moviendo; NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !capa.moviendo; NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

            // Fondo: al pasar el ratón y elegido
            Rectangle {
                anchors.fill: parent
                radius: Tema.esquina(10)
                color: icono.sel ? Tema.conAlfa(Tema.blanco, 0.2) : raton.containsMouse ? Tema.claro(0.1) : "transparent"
                border.width: icono.sel ? 1 : 0
                border.color: Tema.conAlfa(Tema.blanco, 0.45)
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
            }

            // La imagen: miniatura (con su marco) o el icono del tipo
            Item {
                id: dibujo
                width: Math.round(50 * capa.t)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(7 * capa.t)

                readonly property string miniatura: icono.modelData.imagen
                readonly property string tema: {
                    const i = icono.modelData.icono ?? "";
                    if (i.startsWith("/"))
                        return "file://" + i;
                    for (const n of i.split(",")) {
                        const p = Quickshell.iconPath(n, true);
                        if (p) return p;
                    }
                    return Quickshell.iconPath(icono.modelData.tipo === "carpeta" ? "folder" : "text-x-generic", true)
                        || Quickshell.iconPath("application-x-executable");
                }

                Image {
                    id: foto
                    visible: dibujo.miniatura !== "" && status === Image.Ready
                    anchors.centerIn: parent
                    width: Math.min(parent.width, implicitWidth)
                    height: Math.min(parent.height, implicitHeight)
                    source: dibujo.miniatura ? "file://" + dibujo.miniatura : ""
                    sourceSize: Qt.size(dibujo.width * 2, dibujo.height * 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                // El marco de la foto: fina y clara, como una polaroid
                Rectangle {
                    visible: foto.visible
                    anchors.centerIn: foto
                    width: foto.paintedWidth + 4
                    height: foto.paintedHeight + 4
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.9)
                    radius: 2
                }
                Image {
                    visible: !foto.visible
                    anchors.fill: parent
                    source: dibujo.tema
                    sourceSize: Qt.size(dibujo.width * 2, dibujo.height * 2)
                    asynchronous: true
                    smooth: true
                }
                // Acceso directo: la flechita de Windows, abajo a la izquierda
                Rectangle {
                    visible: icono.modelData.tipo === "acceso"
                    x: -2; y: parent.height - height + 2
                    width: Math.round(17 * capa.t); height: width
                    radius: Tema.esquina(5)
                    color: Tema.claro(0.95)
                    border.width: 1
                    border.color: Tema.sombra(0.3)
                    Texto {
                        anchors.centerIn: parent
                        text: "󰁜"
                        font.pixelSize: Math.round(12 * capa.t)
                        color: Tema.oscuro
                    }
                }
            }

            // El nombre, con sombra para leerse sobre cualquier fondo (al
            // elegirlo, entero)
            Item {
                id: rotulo
                visible: !icono.editando
                anchors { top: dibujo.bottom; topMargin: Math.round(5 * capa.t); horizontalCenter: parent.horizontalCenter }
                width: parent.width - 6
                height: nombre.height
                Texto {
                    x: 0.8; y: 1.2
                    width: parent.width
                    text: nombre.text
                    font: nombre.font
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: nombre.wrapMode
                    maximumLineCount: nombre.maximumLineCount
                    elide: nombre.elide
                    color: Qt.rgba(0, 0, 0, 0.75)
                    textFormat: Text.PlainText
                }
                Texto {
                    id: nombre
                    width: parent.width
                    text: icono.modelData.titulo
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: icono.sel ? 4 : 2
                    elide: Text.ElideRight
                    font.bold: false
                    font.pixelSize: Math.round(12 * capa.t)
                    color: "white"
                }
            }

            // Cambiar el nombre: en su sitio, con el nombre sin la extensión
            // elegido (como en Windows)
            Rectangle {
                visible: icono.editando
                anchors { top: dibujo.bottom; topMargin: Math.round(4 * capa.t); horizontalCenter: parent.horizontalCenter }
                width: parent.width + 16
                height: campo.contentHeight + 8
                radius: Tema.esquina(6)
                color: Tema.sombra(0.95)
                border.width: 1
                border.color: Tema.conAlfa(Tema.blanco, 0.6)
                TextInput {
                    id: campo
                    anchors { fill: parent; margins: 4 }
                    horizontalAlignment: TextInput.AlignHCenter
                    wrapMode: TextInput.WrapAnywhere
                    color: Tema.texto
                    selectionColor: Tema.conAlfa(Tema.blanco, 0.35)
                    selectedTextColor: Tema.blanco
                    font.family: Tema.fuente
                    font.pixelSize: Math.round(12 * capa.t)
                    onVisibleChanged: {
                        if (!visible)
                            return;
                        text = icono.modelData.nombre;
                        forceActiveFocus();
                        const punto = text.lastIndexOf(".");
                        select(0, punto > 0 && icono.modelData.tipo !== "carpeta" ? punto : text.length);
                    }
                    onAccepted: capa.renombrar(icono.modelData.nombre, text)
                    onActiveFocusChanged: if (!activeFocus && icono.editando) capa.renombrar(icono.modelData.nombre, text)
                    Keys.onEscapePressed: { capa.renombrando = ""; teclas.forceActiveFocus(); }
                }
            }

            MouseArea {
                id: raton
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: capa.moviendo ? Qt.ClosedHandCursor : Qt.ArrowCursor
                property point desde: Qt.point(0, 0)
                property bool soloEste: false
                onPressed: e => {
                    teclas.forceActiveFocus();
                    capa.menuDe = null;
                    const n = icono.modelData.nombre;
                    if (e.button === Qt.RightButton) {
                        if (!icono.sel)
                            capa.elegir(n, false);
                        const p = mapToItem(capa.contentItem, e.x, e.y);
                        capa.abrirMenu(icono.modelData, p.x, p.y);
                        return;
                    }
                    const ctrl = e.modifiers & Qt.ControlModifier;
                    // Clic en uno ya elegido (de varios): se decide al soltar,
                    // por si se van a arrastrar todos
                    soloEste = icono.sel && !ctrl;
                    if (ctrl || !icono.sel)
                        capa.elegir(n, ctrl);
                    desde = mapToItem(capa.contentItem, e.x, e.y);
                }
                onPositionChanged: e => {
                    if (!pressed || !(pressedButtons & Qt.LeftButton) || !icono.sel)
                        return;
                    const p = mapToItem(capa.contentItem, e.x, e.y);
                    const d = Qt.point(p.x - desde.x, p.y - desde.y);
                    if (!capa.moviendo && Math.abs(d.x) + Math.abs(d.y) < 8)
                        return;
                    capa.moviendo = true;
                    capa.desplazamiento = d;
                }
                onReleased: e => {
                    if (capa.moviendo)
                        capa.soltar();
                    else if (soloEste && e.button === Qt.LeftButton)
                        capa.elegir(icono.modelData.nombre, false);
                }
                onDoubleClicked: e => {
                    if (e.button === Qt.LeftButton)
                        capa.abrir(icono.modelData);
                }
            }
        }
    }

    // -------------------------------------------------------- El menú
    Rectangle {
        id: menu
        visible: capa.menuAbierto
        z: 100
        readonly property int ancho: 240
        width: ancho
        height: columnaMenu.implicitHeight + 12
        x: Math.min(capa.menuEn.x, capa.width - width - 8)
        y: Math.min(capa.menuEn.y, capa.height - height - 8)
        radius: Tema.esquina(12)
        color: Tema.panel
        border.width: Tema.borde(1)
        border.color: Tema.claro(0.12)
        // Al salir, crece desde el clic
        transformOrigin: Item.TopLeft
        scale: visible ? 1 : 0.92
        Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }

        Column {
            id: columnaMenu
            x: 6; y: 6
            width: parent.width - 12
            Repeater {
                model: capa.opcionesMenu
                Item {
                    id: opcion
                    required property var modelData
                    width: columnaMenu.width
                    height: modelData.raya ? 9 : 32
                    Rectangle {
                        visible: opcion.modelData.raya === true
                        anchors.centerIn: parent
                        width: parent.width - 16; height: 1
                        color: Tema.claro(0.08)
                    }
                    Rectangle {
                        visible: !opcion.modelData.raya
                        anchors.fill: parent
                        radius: Tema.esquina(8)
                        color: !opcionRaton.containsMouse ? "transparent"
                            : opcion.modelData.peligro ? Tema.conAlfa(Tema.rojo, 0.2) : Tema.cajaHover
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Texto {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: opcion.modelData.icono ?? ""
                            font.pixelSize: 15
                            color: opcion.modelData.peligro && opcionRaton.containsMouse ? Tema.rojo : Tema.gris
                        }
                        Texto {
                            x: 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: opcion.modelData.texto ?? ""
                            font.bold: false
                            font.pixelSize: 13
                            color: opcion.modelData.peligro && opcionRaton.containsMouse ? Tema.rojo : Tema.texto
                        }
                        Texto {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: opcion.modelData.atajo ?? ""
                            font.bold: false
                            font.pixelSize: 10
                            color: Tema.claro(0.35)
                        }
                        MouseArea {
                            id: opcionRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const hacer = opcion.modelData.hacer;
                                capa.menuDe = null;
                                hacer();
                            }
                        }
                    }
                }
            }
        }
    }
}
