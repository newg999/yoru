// ============================================================================
//  Monitor del sistema — se abre al pulsar la CPU/RAM de la barra
//
//    Procesos:     buscar · Todo / Usuario / Sistema · agrupar por app
//                  clic en una columna = ordenar por ella
//                  clic en un proceso = ver su comando y cerrarlo
//    Rendimiento:  gráficas de CPU y memoria (últimos 5 min), red y disco
//
//  Los datos salen de scripts/monitor.py, que solo corre con el panel abierto.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "monitor"
    lado: "derecha"
    ancho: 780

    readonly property string pestana: Paneles.seccion === "rendimiento" ? "rendimiento" : "procesos"

    // ------------------------------------------------------------ Datos
    property var datos: null
    // La red solo se mide con el panel abierto; CPU y memoria vienen de Sistema
    property var historial: ({bajada: [], subida: []})
    property real maxRed: 1           // para escalar la gráfica de red

    Process {
        running: panel.abierto
        command: ["python3", Quickshell.shellPath("scripts/monitor.py")]
        stdout: SplitParser {
            onRead: linea => {
                let d;
                try {
                    d = JSON.parse(linea);
                } catch (e) {
                    return;
                }
                // Al cambiar la lista, el scroll vuelve arriba: se guarda y se repone
                const y = lista.contentY;
                panel.datos = d;
                Qt.callLater(() => lista.contentY = Math.min(y, Math.max(0, lista.contentHeight - lista.height)));

                // Listas nuevas cada vez (si no, las gráficas no se enteran del cambio)
                const h = panel.historial;
                const meter = (lista, v) => [...lista, v].slice(-60);
                panel.historial = {
                    bajada: meter(h.bajada, d.bajada),
                    subida: meter(h.subida, d.subida)
                };
                panel.maxRed = Math.max(64 * 1024, ...panel.historial.bajada, ...panel.historial.subida);
            }
        }
    }

    // ----------------------------------------------------- Filtro y orden
    property string filtro: "todo"     // todo · usuario · sistema
    property string orden: "cpu"       // nombre · cpu · mem · pid
    property bool descendente: true
    property bool agrupar: true
    property string desplegado: ""       // clave del proceso desplegado

    function ordenarPor(campo) {
        if (orden === campo) {
            descendente = !descendente;
        } else {
            orden = campo;
            descendente = campo !== "nombre";
        }
    }

    readonly property var filas: {
        if (!datos)
            return [];
        const q = busqueda.text.trim().toLowerCase();
        let ps = datos.procesos.filter(p =>
            (filtro === "todo" || (filtro === "usuario") === p.mio)
            && (q === "" || p.nombre.toLowerCase().includes(q) || p.comando.toLowerCase().includes(q)
                || String(p.pid) === q));

        // Agrupar: todos los procesos de una app (mismo nombre y usuario) en una fila
        if (agrupar) {
            const grupos = new Map();
            for (const p of ps) {
                const clave = p.nombre + "·" + p.usuario;
                const g = grupos.get(clave);
                if (g) {
                    g.cpu += p.cpu;
                    g.mem += p.mem;
                    g.pids.push(p.pid);
                    g.pid = Math.min(g.pid, p.pid);
                } else {
                    grupos.set(clave, Object.assign({}, p, {pids: [p.pid], clave}));
                }
            }
            ps = [...grupos.values()];
        } else {
            ps = ps.map(p => Object.assign({}, p, {pids: [p.pid], clave: String(p.pid)}));
        }

        const signo = descendente ? -1 : 1;
        return ps.sort((a, b) => {
            const x = a[orden], y = b[orden];
            const c = typeof x === "string" ? x.localeCompare(y) : x - y;
            return signo * (c || a.pid - b.pid);
        });
    }

    function tamano(bytes) {
        if (bytes >= 1024 ** 3) return (bytes / 1024 ** 3).toFixed(1) + " GB";
        if (bytes >= 1024 ** 2) return (bytes / 1024 ** 2).toFixed(1) + " MB";
        if (bytes >= 1024) return Math.round(bytes / 1024) + " KB";
        return bytes > 0 ? bytes + " B" : "0 KB";
    }
    function velocidad(b) {
        return tamano(b) + "/s";
    }
    function cerrar(fila, forzar) {
        Quickshell.execDetached(["kill", forzar ? "-KILL" : "-TERM", ...fila.pids.map(String)]);
        desplegado = "";
    }

    onAbiertoChanged: {
        if (abierto) {
            busqueda.text = "";
            desplegado = "";
            if (pestana === "procesos")
                busqueda.forceActiveFocus();
        } else {
            datos = null;
            historial = {bajada: [], subida: []};
        }
    }

    Column {
        width: parent.width
        spacing: 12

        // ------------------------------------------------------ Cabecera
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: [
                        {id: "procesos", icono: "󰒋", texto: "Procesos"},
                        {id: "rendimiento", icono: "󰓅", texto: "Rendimiento"}
                    ]
                    Rectangle {
                        id: pestana
                        required property var modelData
                        readonly property bool elegida: panel.pestana === modelData.id
                        width: 150; height: 36; radius: 10
                        color: elegida ? Tema.claro(0.90) : pestanaRaton.containsMouse ? Tema.cajaHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Texto {
                                text: pestana.modelData.icono
                                font.pixelSize: 16
                                color: pestana.elegida ? Tema.oscuro : Tema.texto
                            }
                            Texto {
                                text: pestana.modelData.texto
                                font.pixelSize: 13
                                color: pestana.elegida ? Tema.oscuro : Tema.texto
                            }
                        }
                        MouseArea {
                            id: pestanaRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Paneles.seccion = pestana.modelData.id
                        }
                    }
                }
            }

            // Filtro Todo / Usuario / Sistema (solo en Procesos)
            Row {
                visible: panel.pestana === "procesos"
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: [["todo", "Todo"], ["usuario", "Usuario"], ["sistema", "Sistema"]]
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool elegido: panel.filtro === modelData[0]
                        width: chipTexto.implicitWidth + 22; height: 28; radius: 14
                        color: elegido ? Tema.claro(0.90) : chipRaton.containsMouse ? Tema.cajaHover : Tema.caja
                        Texto {
                            id: chipTexto
                            anchors.centerIn: parent
                            text: chip.modelData[1]
                            font.pixelSize: 11
                            color: chip.elegido ? Tema.oscuro : Tema.texto
                        }
                        MouseArea {
                            id: chipRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.filtro = chip.modelData[0]
                        }
                    }
                }
            }
        }

        // ====================================================== Procesos
        Column {
            visible: panel.pestana === "procesos"
            width: parent.width
            spacing: 8

            // Búsqueda + agrupar
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width - agruparBoton.width - 8
                    height: 40
                    radius: 10
                    color: Tema.caja
                    border.width: 1
                    border.color: busqueda.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

                    Texto {
                        id: lupa
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "󰍉"
                        font.pixelSize: 16
                        color: Tema.gris
                    }
                    TextInput {
                        id: busqueda
                        anchors { left: lupa.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        color: Tema.texto
                        selectionColor: Tema.claro(0.3)
                        font.family: Tema.fuente
                        font.pixelSize: 13
                        clip: true
                        Keys.onEscapePressed: Paneles.cerrar()

                        Texto {
                            visible: busqueda.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Buscar por nombre, comando o PID…"
                            font.bold: false
                            font.pixelSize: 13
                            color: Tema.gris
                        }
                    }
                }

                Rectangle {
                    id: agruparBoton
                    width: agruparFila.implicitWidth + 24
                    height: 40
                    radius: 10
                    color: panel.agrupar ? Tema.claro(0.90) : agruparRaton.containsMouse ? Tema.cajaHover : Tema.caja
                    Row {
                        id: agruparFila
                        anchors.centerIn: parent
                        spacing: 8
                        Texto {
                            text: "󰕰"
                            font.pixelSize: 15
                            color: panel.agrupar ? Tema.oscuro : Tema.texto
                        }
                        Texto {
                            text: "Agrupar apps"
                            font.pixelSize: 12
                            color: panel.agrupar ? Tema.oscuro : Tema.texto
                        }
                    }
                    MouseArea {
                        id: agruparRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.agrupar = !panel.agrupar
                    }
                }
            }

            // Cabecera de columnas (clic = ordenar)
            Item {
                width: parent.width
                height: 30

                component Columna: Texto {
                    required property string campo
                    property string titulo: ""
                    readonly property bool elegida: panel.orden === campo
                    text: titulo + (elegida ? (panel.descendente ? " 󰁅" : " 󰁝") : "")
                    font.pixelSize: 11
                    color: elegida ? Tema.blanco : Tema.gris
                    height: parent.height
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.ordenarPor(parent.campo)
                    }
                }

                Columna { x: 48; campo: "nombre"; titulo: "Nombre" }
                Columna { x: parent.width - 330; width: 80; horizontalAlignment: Text.AlignRight; campo: "cpu"; titulo: "CPU" }
                Columna { x: parent.width - 230; width: 100; horizontalAlignment: Text.AlignRight; campo: "mem"; titulo: "Memoria" }
                Columna { x: parent.width - 110; width: 70; horizontalAlignment: Text.AlignRight; campo: "pid"; titulo: "PID" }
            }

            ListView {
                id: lista
                width: parent.width
                // 620, o menos si la pantalla es pequeña (193 = resto del panel)
                height: Math.min(620, panel.altoMax - 193)
                clip: true
                spacing: 2
                model: panel.filas
                boundsBehavior: Flickable.StopAtBounds

                Texto {
                    visible: !panel.datos
                    anchors.centerIn: parent
                    text: "Leyendo procesos…"
                    font.bold: false
                    color: Tema.gris
                }

                delegate: Rectangle {
                    id: fila
                    required property var modelData
                    readonly property var p: modelData
                    readonly property bool desplegada: panel.desplegado === p.clave
                    width: lista.width
                    height: desplegada ? 44 + detalles.implicitHeight + 10 : 44
                    radius: 10
                    color: desplegada ? Tema.cajaHover : filaRaton.containsMouse ? Tema.caja : "transparent"
                    clip: true

                    MouseArea {
                        id: filaRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.desplegado = fila.desplegada ? "" : fila.p.clave
                    }

                    Item {
                        width: parent.width
                        height: 44

                        Texto {
                            x: 14
                            width: 22
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            text: Iconos.app(fila.p.nombre, fila.p.mio ? "󰣆" : "󰒓")
                            font.pixelSize: 16
                            color: fila.p.mio ? Tema.blanco : Tema.gris
                        }
                        Texto {
                            x: 48
                            width: parent.width - 48 - 340
                            height: parent.height
                            text: fila.p.nombre + (fila.p.pids.length > 1
                                ? `  <font color="${Tema.gris}">×${fila.p.pids.length}</font>` : "")
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            font.pixelSize: 13
                        }

                        // CPU y memoria en "pastillas" que se aclaran con el uso
                        Rectangle {
                            x: parent.width - 310; width: 60; height: 24; radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: fila.p.cpu > 50 ? Tema.rojo : Tema.claro(0.05 + Math.min(0.3, fila.p.cpu / 100))
                            Texto {
                                anchors.centerIn: parent
                                text: fila.p.cpu.toFixed(1) + "%"
                                font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            x: parent.width - 220; width: 90; height: 24; radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property real parte: panel.datos ? fila.p.mem / panel.datos.memTotal : 0
                            color: parte > 0.05 ? Tema.conAlfa(Tema.rojo, 0.7)
                                : Tema.claro(0.05 + Math.min(0.3, parte * 10))
                            Texto {
                                anchors.centerIn: parent
                                text: panel.tamano(fila.p.mem)
                                font.pixelSize: 11
                            }
                        }
                        Texto {
                            x: parent.width - 110; width: 70
                            height: parent.height
                            horizontalAlignment: Text.AlignRight
                            text: fila.p.pid
                            font.bold: false
                            font.pixelSize: 12
                            color: Tema.gris
                        }
                        Texto {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: "󰅀"
                            font.pixelSize: 13
                            color: Tema.gris
                            rotation: fila.desplegada ? 180 : 0
                        }
                    }

                    // Detalles: comando completo y botones para cerrar
                    Column {
                        id: detalles
                        visible: fila.desplegada
                        x: 48; y: 44
                        width: parent.width - 60
                        spacing: 10

                        Texto {
                            width: parent.width
                            text: fila.p.comando
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.bold: false
                            font.pixelSize: 11
                            color: Tema.gris
                        }
                        Row {
                            spacing: 8
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰀄 " + fila.p.usuario + (fila.p.pids.length > 1 ? `   ·   ${fila.p.pids.length} procesos` : "")
                                font.bold: false
                                font.pixelSize: 11
                                color: Tema.gris
                                rightPadding: 12
                            }
                            Repeater {
                                // Solo se pueden cerrar los procesos propios
                                model: fila.p.mio ? [[false, "󰅖  Cerrar"], [true, "󰚌  Forzar cierre"]] : []
                                Rectangle {
                                    id: boton
                                    required property var modelData
                                    width: botonTexto.implicitWidth + 24; height: 30; radius: 8
                                    color: botonRaton.containsMouse
                                        ? (modelData[0] ? Tema.rojo : Tema.blanco)
                                        : Tema.claro(0.08)
                                    Texto {
                                        id: botonTexto
                                        anchors.centerIn: parent
                                        text: boton.modelData[1]
                                        font.pixelSize: 11
                                        color: botonRaton.containsMouse && !boton.modelData[0] ? Tema.oscuro : Tema.texto
                                    }
                                    MouseArea {
                                        id: botonRaton
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.cerrar(fila.p, boton.modelData[0])
                                    }
                                }
                            }
                            Texto {
                                visible: !fila.p.mio
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Proceso del sistema: no se puede cerrar desde aquí"
                                font.bold: false
                                font.pixelSize: 11
                                color: Tema.gris
                            }
                        }
                    }
                }
            }
        }

        // =================================================== Rendimiento
        Grid {
            visible: panel.pestana === "rendimiento"
            width: parent.width
            columns: 2
            spacing: 10
            readonly property real celda: (width - 10) / 2

            component TarjetaGrafica: Tarjeta {
                id: tg
                property string icono: ""
                property string titulo: ""
                property string valor: ""
                property string detalle: ""
                property alias valores: g.valores
                property alias valores2: g.valores2
                width: parent.celda
                height: 250

                Row {
                    x: 16; y: 14
                    spacing: 10
                    Texto { text: tg.icono; font.pixelSize: 18; color: Tema.blanco }
                    Texto { text: tg.titulo; font.pixelSize: 13 }
                }
                Texto {
                    anchors { right: parent.right; rightMargin: 16 }
                    y: 12
                    text: tg.valor
                    font.pixelSize: 18
                    color: Tema.blanco
                }
                Texto {
                    x: 16; y: 40
                    text: tg.detalle
                    font.bold: false
                    font.pixelSize: 11
                    color: Tema.gris
                }
                Grafica {
                    id: g
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14; topMargin: 0 }
                    height: 170
                }
            }

            TarjetaGrafica {
                icono: "󰘚"
                titulo: "CPU"
                valor: panel.datos ? panel.datos.cpu.toFixed(0) + "%" : "—"
                detalle: (panel.datos ? panel.datos.nucleos + " hilos" : "")
                    + (Sistema.temperatura > 0 ? `  ·  ${Sistema.temperatura} °C` : "")
                valores: Sistema.historialCpu
            }
            TarjetaGrafica {
                icono: "󰍛"
                titulo: "Memoria"
                valor: panel.datos ? Math.round(100 * panel.datos.memUsada / panel.datos.memTotal) + "%" : "—"
                detalle: panel.datos ? panel.tamano(panel.datos.memUsada) + " de " + panel.tamano(panel.datos.memTotal) : ""
                valores: Sistema.historialMem
            }
            TarjetaGrafica {
                icono: "󰛳"
                titulo: "Red"
                valor: panel.datos ? "↓ " + panel.velocidad(panel.datos.bajada) : "—"
                detalle: panel.datos ? "↑ " + panel.velocidad(panel.datos.subida) + "   (línea tenue = subida)" : ""
                valores: panel.historial.bajada.map(v => v / panel.maxRed)
                valores2: panel.historial.subida.map(v => v / panel.maxRed)
            }
            Tarjeta {
                width: parent.celda
                height: 250
                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 16
                    Row {
                        spacing: 10
                        Texto { text: "󰋊"; font.pixelSize: 18; color: Tema.blanco }
                        Texto { text: "Disco"; font.pixelSize: 13 }
                    }
                    Repeater {
                        model: [
                            ["󰁅  Leyendo", panel.datos?.leido ?? 0],
                            ["󰁝  Escribiendo", panel.datos?.escrito ?? 0]
                        ]
                        Item {
                            required property var modelData
                            width: parent.width
                            height: 22
                            Texto {
                                text: parent.modelData[0]
                                font.bold: false
                                color: Tema.gris
                            }
                            Texto {
                                anchors.right: parent.right
                                text: panel.velocidad(parent.modelData[1])
                                color: Tema.blanco
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Tema.claro(0.08) }
                    Item {
                        width: parent.width
                        height: 22
                        Texto { text: "󰔟  Encendido"; font.bold: false; color: Tema.gris }
                        Texto {
                            anchors.right: parent.right
                            text: panel.duracion(Sistema.encendido)
                            color: Tema.blanco
                        }
                    }
                    Item {
                        width: parent.width
                        height: 22
                        Texto { text: "󰒋  Procesos"; font.bold: false; color: Tema.gris }
                        Texto {
                            anchors.right: parent.right
                            text: panel.datos ? panel.datos.procesos.length : "—"
                            color: Tema.blanco
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------ Pie
        Row {
            width: parent.width
            spacing: 22
            Repeater {
                model: [
                    "󰒋  " + (panel.datos ? panel.datos.procesos.length + " procesos" : "—"),
                    "󰔟  " + panel.duracion(Sistema.encendido),
                    "󰛳  ↓ " + (panel.datos ? panel.velocidad(panel.datos.bajada) : "—")
                        + "  ↑ " + (panel.datos ? panel.velocidad(panel.datos.subida) : "—"),
                    "󰘚  " + (panel.datos ? panel.datos.cpu.toFixed(1) + "%" : "—"),
                    "󰍛  " + (panel.datos ? panel.tamano(panel.datos.memUsada) + " / " + panel.tamano(panel.datos.memTotal) : "—")
                ]
                Texto {
                    required property string modelData
                    text: modelData
                    font.bold: false
                    font.pixelSize: 11
                    color: Tema.gris
                }
            }
        }
    }

    function duracion(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
}
