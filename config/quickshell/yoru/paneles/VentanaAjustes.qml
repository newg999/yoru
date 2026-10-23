// ============================================================================
//  VentanaAjustes — los Ajustes de Yoru, como una app aparte
//  Una ventana normal de niri (se mueve, se cierra con Mod+Q o Esc...) con
//  las secciones a la izquierda, como en la mayoría de escritorios, y la
//  elegida a la derecha (PestanaAjustes.qml).
//  Se abre con Mod+Alt+T, desde el lanzador, el centro de control o el botón
//  Ajustes del panel central: todos llaman a Paneles.alternar("ajustes", ...)
//  Solo existe mientras está abierta (Paneles.ajustesAbiertos).
//  Su fondo translúcido se desenfoca por una regla de niri (rules.kdl, por
//  su título: Paneles.tituloAjustes)
//  Arriba de la barra lateral va quién eres (la foto de ~/.face, si la hay)
//  y un buscador: filtra las secciones por su nombre, lo que tienen dentro
//  (claves) y su descripción; Enter abre la primera.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Scope {
    LazyLoader {
        active: Paneles.ajustesAbiertos

        FloatingWindow {
            id: ventana

            title: Paneles.tituloAjustes
            implicitWidth: 1080
            implicitHeight: 760
            minimumSize: Qt.size(780, 480)
            color: Tema.panel
            visible: true
            // Cerrada desde niri (Mod+Q, el botón de cerrar...): se olvida
            onVisibleChanged: if (!visible) Paneles.ajustesAbiertos = false

            // La barra lateral, por grupos (como en GNOME o KDE)
            readonly property var grupos: [
                {titulo: "Personalización", secciones: [
                    {id: "tema", icono: "󰏘", texto: "Tema", detalle: "Colores de todo el escritorio"},
                    {id: "fondo", icono: "󰸉", texto: "Fondo", detalle: "El fondo de pantalla"},
                    {id: "aspecto", icono: "󰙵", texto: "Aspecto", detalle: "Esquinas, transparencias, letra, animaciones y luz nocturna"},
                    {id: "barra", icono: "󰕮", texto: "Barra y dock", detalle: "Dónde va la barra, qué se ve en ella y el dock"}
                ]},
                {titulo: "Dispositivos", secciones: [
                    {id: "pantallas", icono: "󰍹", texto: "Pantallas", detalle: "Colocar los monitores, resolución y escala"},
                    {id: "sonido", icono: "󰕾", texto: "Sonido", detalle: "Altavoces, auriculares, micrófono, el volumen de cada app y el sonido al grabar"},
                    {id: "raton", icono: "󰍽", texto: "Ratón", detalle: "Velocidad, rueda, touchpad y cursor"},
                    {id: "teclado", icono: "󰌌", texto: "Teclado", detalle: "Distribución, repetición de teclas y Bloq Mayús"},
                    {id: "atajos", icono: "󰘳", texto: "Atajos", detalle: "Todos los atajos de teclado de Yoru"}
                ]},
                {titulo: "Sistema", secciones: [
                    {id: "notificaciones", icono: "󰂚", texto: "Notificaciones", detalle: "No molestar, cuánto duran los avisos y qué apps pueden avisar"},
                    {id: "energia", icono: "󰂄", texto: "Energía", detalle: "Perfil de energía, bloqueo, pantalla y suspensión"},
                    {id: "fecha", icono: "󰥔", texto: "Fecha y hora", detalle: "Zona horaria, hora automática y el reloj de la barra"},
                    {id: "apps", icono: "󰀻", texto: "Apps", detalle: "Con qué app se abre cada cosa"},
                    {id: "acerca", icono: "󰋼", texto: "Acerca de", detalle: "Tu equipo y la versión de Yoru"}
                ]}
            ]
            readonly property var secciones: [].concat(...grupos.map(g => g.secciones))

            // Lo que se busca más allá del nombre y la descripción
            readonly property var claves: ({
                tema: "colores paleta oscuro claro nord catppuccin",
                fondo: "wallpaper imagen descubrir wallhaven",
                aspecto: "transparencia opacidad letra fuente desenfoque blur luz nocturna animaciones bordes",
                barra: "dock islas reloj bandeja",
                pantallas: "monitor resolución resolucion hz escala",
                sonido: "audio volumen altavoces auriculares micrófono microfono",
                raton: "touchpad cursor puntero zurdo",
                teclado: "idioma layout inglés ingles repetición repeticion mayúsculas",
                atajos: "teclas shortcuts combinaciones",
                notificaciones: "avisos no molestar silenciar",
                energia: "bloqueo suspender batería bateria inactividad",
                fecha: "hora zona horaria reloj ntp",
                apps: "predeterminadas navegador abrir con",
                acerca: "sistema versión version actualizar equipo"
            })
            function casa(s, q) {
                const sinTildes = t => t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                return sinTildes(`${s.texto} ${s.detalle} ${claves[s.id] ?? ""}`).includes(sinTildes(q));
            }
            readonly property string buscado: buscador.text.trim()
            readonly property var halladas: buscado === "" ? secciones : secciones.filter(s => casa(s, buscado))
            readonly property string usuario: Quickshell.env("USER") ?? ""
            // ~/.face, solo si existe (si no, Image se queja en el registro)
            property bool hayFoto: false
            Process {
                running: true
                command: ["test", "-f", Quickshell.env("HOME") + "/.face"]
                onExited: codigo => ventana.hayFoto = codigo === 0
            }
            readonly property var actual: secciones.find(s => s.id === Paneles.seccionAjustes) ?? secciones[0]

            // Las secciones leen sus datos al pasar «abierto» a true: si ya
            // naciera en true no se enterarían (QML no avisa del valor inicial)
            property bool lista: false
            Component.onCompleted: lista = true

            Shortcut {
                sequence: "Escape"
                onActivated: Paneles.ajustesAbiertos = false
            }

            // ---------------------------------------------- Barra lateral
            Rectangle {
                id: lateral
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 250
                color: Tema.claro(0.03)

                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Tema.claro(0.08)
                }

                // Con la ventana baja, la lista se desplaza
                Flickable {
                    anchors { fill: parent; margins: 14; topMargin: 22; rightMargin: 15 }
                    contentHeight: listaLateral.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listaLateral
                    width: parent.width
                    spacing: 4

                    // Quién eres: foto (o la inicial) y nombre
                    Row {
                        leftPadding: 6
                        bottomPadding: 16
                        spacing: 12

                        ClippingRectangle {
                            width: 44
                            height: 44
                            radius: 22
                            color: Tema.claro(0.10)
                            border.width: 1
                            border.color: Tema.claro(0.15)
                            Texto {
                                anchors.centerIn: parent
                                visible: foto.status !== Image.Ready
                                text: ventana.usuario.charAt(0).toUpperCase()
                                font.pixelSize: 19
                                color: Tema.blanco
                            }
                            Image {
                                id: foto
                                anchors.fill: parent
                                source: ventana.hayFoto ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                                sourceSize: Qt.size(88, 88)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Texto {
                                text: ventana.usuario
                                font.pixelSize: 15
                                color: Tema.blanco
                            }
                            Texto {
                                text: "Ajustes de Yoru"
                                font.pixelSize: 11
                                font.bold: false
                                color: Tema.gris
                            }
                        }
                    }

                    // Buscador de secciones
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 10
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
                            Texto {
                                visible: buscador.text === ""
                                text: "Buscar ajuste"
                                font.pixelSize: 13
                                font.bold: false
                                color: Tema.tenue
                            }
                            Keys.onReturnPressed: if (ventana.halladas.length > 0)
                                Paneles.seccionAjustes = ventana.halladas[0].id
                        }
                    }
                    Item { width: 1; height: 10 }
                    Texto {
                        visible: ventana.halladas.length === 0
                        leftPadding: 14
                        text: "Nada con «" + ventana.buscado + "»"
                        font.pixelSize: 12
                        font.bold: false
                        color: Tema.gris
                    }

                    Repeater {
                        model: ventana.grupos

                        Column {
                            id: grupo
                            required property var modelData
                            required property int index
                            readonly property var visibles: modelData.secciones.filter(s => ventana.halladas.some(h => h.id === s.id))
                            visible: visibles.length > 0
                            width: parent.width
                            spacing: 2
                            topPadding: index > 0 ? 14 : 0

                            Texto {
                                leftPadding: 14
                                bottomPadding: 4
                                text: grupo.modelData.titulo.toUpperCase()
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                color: Tema.gris
                            }

                            Repeater {
                                model: grupo.visibles

                                Rectangle {
                                    id: fila
                                    required property var modelData
                                    readonly property bool elegida: Paneles.seccionAjustes === modelData.id
                                    width: parent.width
                                    height: 38
                                    radius: 10
                                    color: elegida ? Tema.claro(0.90) : filaRaton.containsMouse ? Tema.cajaHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Tema.rapida } }

                                    Row {
                                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                        spacing: 14
                                        Texto {
                                            width: 20
                                            horizontalAlignment: Text.AlignHCenter
                                            text: fila.modelData.icono
                                            font.pixelSize: 17
                                            color: fila.elegida ? Tema.oscuro : Tema.texto
                                        }
                                        Texto {
                                            text: fila.modelData.texto
                                            font.pixelSize: 14
                                            color: fila.elegida ? Tema.oscuro : Tema.texto
                                        }
                                    }
                                    MouseArea {
                                        id: filaRaton
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Paneles.seccionAjustes = fila.modelData.id
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }

            // ------------------------------------------- La sección elegida
            Flickable {
                id: desplazable
                anchors { left: lateral.right; right: parent.right; top: parent.top; bottom: parent.bottom }
                contentHeight: columna.height + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Cada sección empieza arriba
                Connections {
                    target: Paneles
                    function onSeccionAjustesChanged() { desplazable.contentY = 0; }
                }

                Column {
                    id: columna
                    x: Math.max(36, (desplazable.width - width) / 2)
                    y: 30
                    width: Math.min(desplazable.width - 72, 860)
                    spacing: 22

                    Column {
                        width: parent.width
                        spacing: 4
                        Texto {
                            text: ventana.actual.texto
                            font.pixelSize: 26
                            color: Tema.blanco
                        }
                        Texto {
                            width: parent.width
                            text: ventana.actual.detalle
                            font.pixelSize: 13
                            font.bold: false
                            color: Tema.gris
                            wrapMode: Text.Wrap
                        }
                    }

                    PestanaAjustes {
                        width: parent.width
                        pestana: Paneles.seccionAjustes
                        abierto: ventana.lista
                        pantalla: ventana.screen
                    }
                }
            }

            // Barra de desplazamiento: fina, y solo si hay algo que desplazar
            Rectangle {
                visible: desplazable.contentHeight > desplazable.height
                anchors.right: parent.right
                anchors.rightMargin: 4
                width: 4
                radius: 2
                color: Tema.claro(0.25)
                y: desplazable.visibleArea.yPosition * desplazable.height + 4
                height: Math.max(30, desplazable.visibleArea.heightRatio * desplazable.height - 8)
            }
        }
    }
}
