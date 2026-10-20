// ============================================================================
//  Fondos — elegir fondo de pantalla con miniaturas, en mitad de la pantalla
//  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin panel
//
//    ↑ ↓ ← → para moverte · Enter para ponerlo · Esc para cerrar
//    Supr (o la papelera del fondo) dos veces = mandarlo a la papelera
//
//  Los fondos salen de ~/.local/share/wallpapers (scripts/fondos.sh hace
//  las miniaturas la primera vez) y se ponen con niri/scripts/wallpaper.sh,
//  que también los lleva al bloqueo, al inicio de sesión y a «yoru tema fondo».
//
//  Pestaña Descubrir: busca fondos nuevos en wallhaven.cc (populares, por
//  tema o por palabra) con scripts/wallhaven.py. Clic = vista previa en
//  grande (← → para pasar, Enter = se baja y se pone, Esc = volver).
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

    // Filas de miniaturas que caben (máximo 3) dejando «resto» px para
    // pestañas, buscador y pie
    function filasQueCaben(alto, resto) {
        return Math.max(1, Math.min(3, Math.floor((altoMax - 32 - resto) / alto)));
    }
    readonly property string casa: Quickshell.env("HOME")

    property var fondos: []          // [{ruta, miniatura, nombre}]
    property string actual: ""
    property bool cargando: false
    property string vista: "mios"    // "mios" · "descubrir"

    // Borrar: el primer clic (o Supr) lo marca en rojo; el segundo, a la papelera
    property string aBorrar: ""
    function borrar(fondo) {
        if (!fondo || borrador.running)
            return;
        if (aBorrar !== fondo.ruta) {
            aBorrar = fondo.ruta;
            olvidarBorrar.restart();
            return;
        }
        aBorrar = "";
        borrador.command = [Quickshell.shellPath("scripts/wallhaven.py"), "borrar", fondo.ruta];
        borrador.running = true;
    }
    Timer {
        id: olvidarBorrar
        interval: 3000
        onTriggered: panel.aBorrar = ""
    }
    Process {
        id: borrador
        onExited: {
            const i = rejilla.currentIndex;
            leer.running = true;
            actualFile.reload();
            rejilla.currentIndex = Math.max(0, Math.min(i, panel.fondos.length - 2));
        }
    }

    // ------------------------------------------------------ Descubrir
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
        panel.consulta = consulta;
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
                    panel.error = "Wallhaven no responde";
                    return;
                }
                if (r.error) {
                    panel.error = r.error;
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
                for (let i = 0; i < nuevos.count; i++)
                    if (nuevos.get(i).ident === id)
                        nuevos.setProperty(i, "bajado", true);
                panel.marcaPrevia++;
                panel.poner({ruta});
                leer.running = true;
            }
        }
    }

    onAbiertoChanged: {
        if (!abierto)
            previa = -1;
        if (abierto) {
            // Se puede abrir directamente en Descubrir:
            // qs -c yoru ipc call panel alternar fondos descubrir
            if (Paneles.seccion === "descubrir") {
                vista = "descubrir";
                if (nuevos.count === 0)
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
                    if (nuevos.count === 0)
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
            // Hasta 3 filas; menos si no caben bajo la barra (portátiles de 768)
            height: Math.min(Math.ceil(Math.max(panel.fondos.length, 1) / panel.columnas),
                             panel.filasQueCaben(cellHeight, 130)) * cellHeight
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
            Keys.onDeletePressed: panel.borrar(panel.fondos[currentIndex])

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

                // Encima del MouseArea de la celda, para que la papelera reciba su clic
                Rectangle {
                    z: 1
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

                    // Papelera (con el ratón encima). Primer clic: en rojo; segundo: se borra
                    Rectangle {
                        readonly property bool marcado: panel.aBorrar === celda.modelData.ruta
                        visible: celda.elegida || marcado
                        anchors { right: parent.right; top: parent.top; margins: 10 }
                        width: marcado ? confirmar.width + 34 : 26
                        height: 26
                        radius: 13
                        color: marcado ? Tema.rojo : papelera.containsMouse ? Qt.alpha(Tema.rojo, 0.85) : Qt.alpha(Tema.oscuro, 0.75)
                        Behavior on width { NumberAnimation { duration: Tema.rapida } }
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Texto {
                                text: "󰩹"
                                font.pixelSize: 14
                                color: Tema.blanco
                            }
                            Texto {
                                id: confirmar
                                visible: parent.parent.marcado
                                text: "¿Borrar?"
                                font.pixelSize: 11
                                color: Tema.blanco
                            }
                        }

                        MouseArea {
                            id: papelera
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.borrar(celda.modelData)
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
            text: (panel.fondos[rejilla.currentIndex]?.nombre ?? "") + "  <font color='" + Tema.gris + "'>·  Enter lo pone  ·  Supr lo borra  ·  Esc cierra</font>"
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

        Item {
            visible: panel.vista === "descubrir"
            width: parent.width
            height: descubiertos.height

            GridView {
                id: descubiertos
                width: parent.width
                height: panel.filasQueCaben(cellHeight, 125) * cellHeight
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: Math.round(cellWidth * 10 / 16)
                model: nuevos
                boundsBehavior: Flickable.StopAtBounds
                // Cerca del final, la página siguiente
                onContentYChanged: if (contentHeight > 0 && contentY + height > contentHeight - cellHeight) panel.mas()

                Texto {
                    visible: nuevos.count === 0
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
                    required property var model
                    required property int index
                    readonly property var modelData: model
                    readonly property bool bajandolo: panel.bajando === modelData.ident
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
                        onClicked: panel.verPrevia(nuevo.index)
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
                visible: panel.previa >= 0
                radius: 12
                color: Tema.sombra(0.97)
                focus: visible
                onVisibleChanged: if (visible) forceActiveFocus(); else busqueda.forceActiveFocus()

                readonly property var fondo: panel.previa >= 0 && panel.previa < nuevos.count ? nuevos.get(panel.previa) : null
                // nuevos.get() no avisa de cambios: se vuelve a mirar al bajarlo
                readonly property bool bajado: panel.marcaPrevia >= 0 && (fondo?.bajado ?? false)
                readonly property bool bajandolo: fondo !== null && panel.bajando === fondo.ident

                Keys.onEscapePressed: panel.previa = -1
                Keys.onLeftPressed: panel.verPrevia(panel.previa - 1)
                Keys.onRightPressed: panel.verPrevia(panel.previa + 1)
                Keys.onReturnPressed: panel.usarPrevia()
                Keys.onEnterPressed: panel.usarPrevia()

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
                              + "  <font color='" + Tema.gris + "'>·  " + (panel.previa + 1) + " de " + nuevos.count + "</font>"
                        textFormat: Text.StyledText
                        font.pixelSize: 12
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6

                        BotonIcono {
                            icono: "󰅁"
                            ayuda: "Anterior (←)"
                            visible: panel.previa > 0
                            onClic: panel.verPrevia(panel.previa - 1)
                        }
                        BotonIcono {
                            icono: "󰅂"
                            ayuda: "Siguiente (→)"
                            visible: panel.previa < nuevos.count - 1
                            onClic: panel.verPrevia(panel.previa + 1)
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
                                onClicked: panel.previa = -1
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
                                onClicked: panel.usarPrevia()
                            }
                        }
                    }
                }
            }
        }

        Texto {
            visible: panel.vista === "descubrir"
            leftPadding: 4
            width: parent.width
            elide: Text.ElideRight
            text: (panel.error !== "" && nuevos.count > 0 ? panel.error + "  ·  " : "")
                + "<font color='" + Tema.gris + "'>De wallhaven.cc · clic: verlo en grande · Enter lo baja y lo pone (queda en Mis fondos)"
                + (buscador.running && nuevos.count > 0 ? "  ·  cargando más…" : "") + "</font>"
            textFormat: Text.StyledText
            font.pixelSize: 11
        }
    }
}
