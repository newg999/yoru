// ============================================================================
//  Tienda — apps de Flathub y de Fedora (dnf), en mitad de la pantalla
//  Atajo: Mod+Alt+S
//
//    Buscar:     escribe y pulsa Enter (nombre o lo que hace: «editor de fotos»)
//    Instaladas: escribe para filtrar
//    ↑ ↓ para moverte · Enter instala o abre la elegida · Tab cambia de vista
//    Esc para cerrar
//
//  Lo que se hace de verdad (buscar, instalar...) está en scripts/tienda.py.
//  Instalar y desinstalar siguen aunque cierres el panel; el resultado llega
//  como notificación y la contraseña la pide la ventana de administrador.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Panel {
    id: panel
    nombre: "tienda"
    lado: "medio"
    ancho: 760

    readonly property string script: Quickshell.shellPath("scripts/tienda.py")

    property string vista: "buscar"          // "buscar" · "instaladas"
    property var instaladas: []
    property var deFlathub: []
    property var deFedora: []
    property string buscado: ""              // lo último que se buscó
    property int pendientes: 0               // orígenes que aún no han contestado
    property var trabajando: ({})            // tipo:id → "Instalando…" / "Desinstalando…"
    property string confirmar: ""            // tipo:id a punto de desinstalar

    readonly property var lista: {
        if (vista === "buscar")
            return [...deFlathub, ...deFedora];
        const q = campo.text.trim().toLowerCase();
        return q === "" ? instaladas
            : instaladas.filter(a => (a.nombre + " " + a.id + " " + a.desc).toLowerCase().includes(q));
    }

    function clave(app) { return app.tipo + ":" + app.id; }

    onAbiertoChanged: {
        if (abierto) {
            vista = Paneles.seccion === "instaladas" ? "instaladas" : "buscar";
            confirmar = "";
            leerInstaladas.running = true;
            campo.selectAll();
            campo.forceActiveFocus();
        }
    }
    onVistaChanged: {
        lista_.currentIndex = 0;
        confirmar = "";
        campo.text = vista === "buscar" ? buscado : "";
    }

    function buscar() {
        const texto = campo.text.trim();
        if (texto === "")
            return;
        buscado = texto;
        deFlathub = [];
        deFedora = [];
        pendientes = 2;
        lista_.currentIndex = 0;
        buscador.exec(["python3", script, "buscar", texto]);
    }

    // Enter: buscar si el texto es nuevo; si no, lo normal con la elegida
    function aceptar() {
        if (vista === "buscar" && campo.text.trim() !== buscado)
            buscar();
        else
            principal(lista[lista_.currentIndex]);
    }

    function principal(app) {
        if (!app || trabajando[clave(app)])
            return;
        if (app.instalada)
            abrir(app);
        else
            hacer(app, "instalar");
    }

    function abrir(app) {
        Quickshell.execDetached(["python3", script, "abrir", app.tipo, app.id, app.nombre]);
        Paneles.cerrar();
    }

    function hacer(app, accion) {
        const t = Object.assign({}, trabajando);
        t[clave(app)] = accion === "instalar" ? "Instalando…" : "Desinstalando…";
        trabajando = t;
        confirmar = "";
        const args = accion === "instalar" ? [app.tipo, app.id, app.remoto ?? "", app.nombre]
            : [app.tipo, app.id, app.nombre];
        const p = trabajo.createObject(panel, {app: app, accion: accion,
            command: ["python3", script, accion, ...args]});
        p.running = true;
    }

    // Al terminar, la app cambia de estado en las dos listas
    function terminado(app, accion, codigo) {
        const t = Object.assign({}, trabajando);
        delete t[clave(app)];
        trabajando = t;
        if (codigo !== 0)
            return;
        const instalada = accion === "instalar";
        const cambiar = l => l.map(a => clave(a) === clave(app) ? Object.assign({}, a, {instalada}) : a);
        deFlathub = cambiar(deFlathub);
        deFedora = cambiar(deFedora);
        leerInstaladas.running = true;
    }

    Component {
        id: trabajo
        Process {
            property var app
            property string accion
            onExited: codigo => {
                panel.terminado(app, accion, codigo);
                destroy();
            }
        }
    }

    Process {
        id: leerInstaladas
        command: ["python3", panel.script, "instaladas"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    panel.instaladas = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: buscador
        stdout: SplitParser {
            onRead: linea => {
                let d;
                try {
                    d = JSON.parse(linea);
                } catch (e) {
                    return;
                }
                if (d.origen === "flatpak")
                    panel.deFlathub = d.apps;
                else
                    panel.deFedora = d.apps;
                panel.pendientes--;
            }
        }
        onExited: panel.pendientes = 0
    }

    // Botón con texto: Instalar, Desinstalar, Actualizar todo...
    component Pastilla: Rectangle {
        id: pastilla
        property string icono: ""
        property string texto: ""
        property bool fuerte: false          // blanco (la acción principal)
        property bool peligro: false         // rojo (desinstalar)
        signal clic()

        implicitWidth: texto === "" ? 30 : interior.implicitWidth + 24
        implicitHeight: 30
        radius: 8
        color: peligro ? Tema.conAlfa(Tema.rojo, raton.containsMouse ? 0.35 : 0.2)
            : fuerte ? (raton.containsMouse ? Tema.blanco : Tema.claro(0.85))
            : raton.containsMouse ? Tema.cajaHover : Tema.caja
        Behavior on color { ColorAnimation { duration: Tema.rapida } }

        Row {
            id: interior
            anchors.centerIn: parent
            spacing: 8
            Texto {
                visible: pastilla.icono !== ""
                text: pastilla.icono
                font.pixelSize: 14
                color: pastilla.fuerte ? Tema.oscuro : pastilla.peligro ? Tema.rojo : Tema.texto
            }
            Texto {
                visible: pastilla.texto !== ""
                text: pastilla.texto
                font.pixelSize: 12
                color: pastilla.fuerte ? Tema.oscuro : pastilla.peligro ? Tema.rojo : Tema.texto
            }
        }
        MouseArea {
            id: raton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pastilla.clic()
        }
    }

    Column {
        width: parent.width
        spacing: 12

        // ------------------------------------------- Vistas y actualizar
        Item {
            width: parent.width
            height: 34

            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [
                        {id: "buscar", icono: "󰍉", texto: "Buscar"},
                        {id: "instaladas", icono: "󰀻", texto: "Instaladas"}
                    ]
                    Rectangle {
                        id: pestana
                        required property var modelData
                        readonly property bool elegida: panel.vista === modelData.id
                        width: contenido.implicitWidth + 28
                        height: 34
                        radius: 10
                        color: elegida ? Tema.claro(0.90) : pestanaRaton.containsMouse ? Tema.cajaHover : "transparent"

                        Row {
                            id: contenido
                            anchors.centerIn: parent
                            spacing: 8
                            Texto {
                                text: pestana.modelData.icono
                                font.pixelSize: 15
                                color: pestana.elegida ? Tema.oscuro : Tema.texto
                            }
                            Texto {
                                text: pestana.modelData.texto
                                    + (pestana.modelData.id === "instaladas" ? "  " + panel.instaladas.length : "")
                                font.pixelSize: 13
                                color: pestana.elegida ? Tema.oscuro : Tema.texto
                            }
                        }
                        MouseArea {
                            id: pestanaRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.vista = pestana.modelData.id;
                                campo.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Pastilla {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                icono: "󰚰"
                texto: "Actualizar todo"
                onClic: {
                    Quickshell.execDetached(["python3", panel.script, "actualizar"]);
                    Paneles.cerrar();
                }
            }
        }

        // ----------------------------------------------------- Búsqueda
        Rectangle {
            width: parent.width
            height: 46
            radius: 12
            color: Tema.caja
            border.width: 1
            border.color: campo.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

            Texto {
                id: lupa
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: panel.vista === "buscar" ? "󰏗" : "󰈲"
                font.pixelSize: 18
                color: Tema.gris
            }
            TextInput {
                id: campo
                anchors { left: lupa.right; leftMargin: 12; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                color: Tema.texto
                selectionColor: Tema.claro(0.3)
                font.family: Tema.fuente
                font.pixelSize: 14
                focus: true
                clip: true
                onTextChanged: {
                    if (panel.vista === "instaladas")
                        lista_.currentIndex = 0;
                    panel.confirmar = "";
                }

                Keys.onDownPressed: lista_.incrementCurrentIndex()
                Keys.onUpPressed: lista_.decrementCurrentIndex()
                Keys.onTabPressed: panel.vista = panel.vista === "buscar" ? "instaladas" : "buscar"
                Keys.onReturnPressed: panel.aceptar()
                Keys.onEnterPressed: panel.aceptar()
                Keys.onEscapePressed: Paneles.cerrar()

                Texto {
                    visible: campo.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.vista === "buscar" ? "Buscar en Flathub y Fedora… (Enter)" : "Filtrar tus apps…"
                    font.bold: false
                    font.pixelSize: 14
                    color: Tema.gris
                }
            }
        }

        Titular {
            width: parent.width
            texto: panel.vista === "instaladas" ? panel.lista.length + " apps · Flatpak y Fedora"
                : panel.buscado === "" ? "Flathub y Fedora"
                : panel.lista.length + " resultados para «" + panel.buscado + "»"
                    + (panel.pendientes > 0 ? " · buscando…" : "")

            BotonIcono {
                visible: panel.pendientes > 0
                icono: "󰑓"
                girando: true
                colorIcono: Tema.gris
            }
        }

        // --------------------------------------------------------- Lista
        ListView {
            id: lista_
            width: parent.width
            height: 480
            clip: true
            spacing: 2
            model: panel.lista
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            keyNavigationWraps: true
            onCurrentIndexChanged: panel.confirmar = ""

            Texto {
                visible: panel.lista.length === 0
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: panel.vista === "instaladas" ? "Ninguna app instalada se llama así"
                    : panel.pendientes > 0 ? "Buscando «" + panel.buscado + "» en Flathub y Fedora…"
                    : panel.buscado !== "" ? "Nada para «" + panel.buscado + "»"
                    : "Escribe qué buscas y pulsa Enter:\nel nombre de la app o lo que hace («editor de fotos»)"
                font.bold: false
                color: Tema.gris
            }

            delegate: Rectangle {
                id: fila
                required property var modelData
                required property int index
                readonly property bool elegida: ListView.isCurrentItem
                readonly property string estado: panel.trabajando[panel.clave(modelData)] ?? ""
                readonly property bool confirmando: panel.confirmar === panel.clave(modelData)
                width: lista_.width
                height: 60
                radius: 10
                color: elegida ? Tema.cajaHover : "transparent"
                border.width: elegida ? 1 : 0
                border.color: Tema.claro(0.25)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: lista_.currentIndex = fila.index
                    onDoubleClicked: panel.principal(fila.modelData)
                }

                IconImage {
                    id: icono
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    implicitSize: 36
                    readonly property string i: fila.modelData.icono ?? ""
                    source: i.startsWith("/") ? "file://" + i
                        : Quickshell.iconPath(i, true) || Quickshell.iconPath("application-x-executable")
                    asynchronous: true
                }

                Column {
                    anchors {
                        left: icono.right; leftMargin: 14
                        right: botones.left; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Texto {
                        width: parent.width
                        text: fila.modelData.nombre
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.pixelSize: 14
                    }
                    Texto {
                        width: parent.width
                        text: (fila.modelData.tipo === "flatpak" ? "󰏖 Flatpak" : " Fedora")
                            + (fila.modelData.instalada ? "  ·  󰄬 instalada" : "")
                            + (fila.modelData.desc ? "  ·  " + fila.modelData.desc : "")
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.bold: false
                        font.pixelSize: 11
                        color: Tema.gris
                    }
                }

                Row {
                    id: botones
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6

                    // Trabajando: un aviso que gira
                    Row {
                        visible: fila.estado !== ""
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        BotonIcono {
                            icono: "󰑓"
                            girando: true
                            colorIcono: Tema.gris
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: fila.estado
                            font.bold: false
                            font.pixelSize: 12
                            color: Tema.gris
                        }
                    }

                    Pastilla {
                        visible: fila.estado === "" && !fila.modelData.instalada
                        icono: "󰇚"
                        texto: "Instalar"
                        fuerte: true
                        onClic: panel.hacer(fila.modelData, "instalar")
                    }
                    Pastilla {
                        visible: fila.estado === "" && fila.modelData.instalada && !fila.confirmando
                        icono: "󰏌"
                        texto: "Abrir"
                        fuerte: true
                        onClic: panel.abrir(fila.modelData)
                    }
                    // Desinstalar pide un segundo clic
                    Pastilla {
                        visible: fila.estado === "" && fila.modelData.instalada
                        icono: "󰆴"
                        texto: fila.confirmando ? "¿Seguro? Desinstalar" : ""
                        peligro: fila.confirmando
                        onClic: {
                            if (fila.confirmando)
                                panel.hacer(fila.modelData, "desinstalar");
                            else
                                panel.confirmar = panel.clave(fila.modelData);
                        }
                    }
                }
            }
        }

        Texto {
            leftPadding: 4
            text: panel.vista === "buscar" ? "Enter busca, luego instala o abre la elegida  ·  Tab: instaladas  ·  Esc cierra"
                : "Enter abre la elegida  ·  Tab: buscar  ·  Esc cierra"
            font.bold: false
            font.pixelSize: 11
            color: Tema.gris
        }
    }
}
