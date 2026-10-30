// ============================================================================
//  BarraWindows — barra de tareas abajo, como la de Windows 11, con la
//  estética de las píldoras (Ajustes › Barra y dock › Windows)
//
//    [☁ 19°C Nublado] [• ━ •] [♪ canción]   [夜] apps…   [avisos] [bandeja] [󰖩 󰕾 󰁹] [13:00 30/10/2026] [󰂚]
//
//    夜           el lanzador, centrado y fundido con la barra (su Inicio)
//    apps         las fijadas y las abiertas (comun/Tareas.qml); la raya de
//                 debajo marca las abiertas, larga y del color del tema la del
//                 foco. Clic = ir (con varias ventanas, elegir) · central =
//                 ventana nueva · derecho = menú (fijar, cerrar...)
//    󰖩 󰕾 󰁹       el centro de control (rueda = volumen)
//    hora         el calendario · 󰂚 las notificaciones (derecho: no molestar)
//  Los paneles suben encima de ella (Panel.qml, con Ajustes.abajo).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import qs.comun

PanelWindow {
    id: barra
    required property ShellScreen modelData
    screen: modelData

    readonly property bool pequena: modelData.width < 1800

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Tema.altoTareas
    exclusiveZone: Tema.zonaBarra
    color: "transparent"
    visible: Ajustes.windows
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : todo
    Region { id: todo; item: fondo }

    IdleInhibitor {
        window: barra
        enabled: Despierto.activo
    }

    // Texto monoespaciado, como el de las píldoras
    component Mono: Text {
        color: Tema.texto
        font.family: Tema.mono
        font.pixelSize: Tema.letra
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }

    // Un botón de la barra: fondo suave al pasar el ratón (y algo más claro
    // si está «encendido»: su panel abierto, la app con el foco). Los de solo
    // icono (crece) se mueven como los del dock: crecen hacia arriba al pasar
    // el ratón y bajan un poco al pulsar
    component Boton: Rectangle {
        id: boton
        property bool encendido: false
        property bool crece: false
        readonly property alias hover: botonRaton.containsMouse
        readonly property bool pulsado: botonRaton.pressed
        default property alias contenido: dentro.data
        signal clic(int boton)
        signal rueda(int pasos)
        implicitWidth: Math.max(40, dentro.childrenRect.width + 20)
        implicitHeight: 40
        anchors.verticalCenter: parent?.verticalCenter
        radius: Tema.esquina(8)
        color: encendido ? Tema.claro(hover ? 0.16 : 0.11) : hover ? Tema.claro(0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: Tema.rapida } }
        Item {
            id: dentro
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
            transformOrigin: boton.crece ? Item.Bottom : Item.Center
            scale: boton.crece ? (botonRaton.pressed ? 1.05 : boton.hover ? 1.16 : 1)
                : botonRaton.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: botonRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => boton.clic(e.button)
            onWheel: e => {
                if (e.angleDelta.y !== 0)
                    boton.rueda(e.angleDelta.y > 0 ? 1 : -1);
            }
        }
    }

    // La franja, de lado a lado
    Rectangle {
        id: fondo
        anchors.fill: parent
        color: Tema.panel
        opacity: Niri.overview ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
        transform: Translate {
            y: Niri.overview ? Tema.altoTareas : 0
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        // Una línea fina arriba
        Rectangle {
            width: parent.width
            height: 1
            color: Tema.claro(0.08)
        }
        // Clic en un hueco libre: cierra el panel que haya abierto
        MouseArea {
            anchors.fill: parent
            onClicked: Paneles.cerrar()
        }

        // ------------------------------------------------------- Izquierda
        // El tiempo (como el de Windows) · escritorios · lo que suena
        Row {
            id: izquierda
            x: 8
            height: parent.height
            spacing: 6

            Boton {
                visible: Ajustes.islaClima && Tiempo.listo
                encendido: Paneles.esta("pildora", barra.modelData, "clima")
                onClic: Paneles.abrirPagina(barra.modelData, "clima", "izquierda")
                Row {
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.icono
                        font.family: Tema.mono
                        font.pixelSize: Tema.letra + 9
                        color: Tema.blanco
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -2
                        Mono {
                            text: Tiempo.temperatura + "°C"
                            color: Tema.amarillo
                        }
                        Mono {
                            text: Tiempo.descripcion
                            color: Tema.gris
                            font.pixelSize: Math.min(11, Tema.letra - 2)
                        }
                    }
                }
            }

            Escritorios {
                anchors.verticalCenter: parent.verticalCenter
                salida: barra.modelData.name
            }

            // Lo que suena (clic = Multimedia · central = pausa)
            Boton {
                id: musica
                readonly property var reproductor: Reproductor.actual
                visible: Ajustes.islaMusica && reproductor !== null && !barra.pequena
                encendido: Paneles.esta("pildora", barra.modelData, "musica")
                onClic: boton => boton === Qt.MiddleButton ? reproductor.togglePlaying()
                    : Paneles.abrirPagina(barra.modelData, "musica", "izquierda")
                Row {
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: musica.reproductor?.isPlaying ? "󰝚" : "󰏤"
                        font.family: Tema.mono
                        font.pixelSize: Tema.letra + 2
                        color: Tema.blanco
                    }
                    Mono {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Reproductor.titulo(musica.reproductor) || Reproductor.nombre(musica.reproductor)
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 220)
                    }
                }
            }
        }

        // ---------------------------------------------------------- Centro
        // 夜 (Inicio) · las apps
        Row {
            id: centro
            // En el centro; si choca con lo de la izquierda, justo después
            x: Math.max(izquierda.x + izquierda.width + 12, Math.round((parent.width - width) / 2))
            height: parent.height
            spacing: 4

            Boton {
                crece: true
                encendido: Paneles.esta("lanzador", barra.modelData)
                onClic: Paneles.alternar("lanzador", barra.modelData, "")
                Text {
                    text: "夜"
                    font.family: Tema.fuente
                    font.pixelSize: 20
                    font.bold: true
                    color: Tema.blanco
                }
            }
            // Las apps
            Repeater {
                model: Tareas.apps

                Boton {
                    id: tarea
                    required property var modelData
                    readonly property var app: modelData
                    readonly property bool enfocada: Tareas.enfocada(app)
                    width: 44
                    crece: true
                    encendido: enfocada
                    onClic: boton => {
                        if (boton === Qt.RightButton) {
                            menu.abrir(app, tarea, false);
                        } else if (boton === Qt.MiddleButton) {
                            menu.cerrar();
                            Tareas.lanzar(app);
                        } else {
                            menu.pulsar(app, tarea);
                        }
                    }

                    IconImage {
                        implicitSize: 26
                        source: Tareas.icono(tarea.app)
                        asynchronous: true
                    }

                    // Abierta: una raya debajo; la del foco, larga y del tema
                    Rectangle {
                        parent: tarea
                        opacity: tarea.app.ventanas.length > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                        width: tarea.enfocada ? 16 : 6
                        height: 3
                        radius: 1.5
                        color: tarea.enfocada ? Tema.blanco : Tema.claro(0.5)
                        Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    }

                    // El nombre, encima, tras un momento con el ratón
                    Timer {
                        id: retraso
                        interval: 450
                        running: tarea.hover && !menu.abierto
                    }
                    Ayuda {
                        objetivo: tarea
                        texto: Tareas.nombre(tarea.app)
                            + (tarea.app.ventanas.length > 1 ? Tema.suave("  ×" + tarea.app.ventanas.length) : "")
                        mostrar: tarea.hover && !retraso.running && !menu.abierto
                    }
                }
            }
        }

        // --------------------------------------------------------- Derecha
        // Avisos · bandeja · conexión, volumen y batería · hora · campana
        Row {
            id: derecha
            x: parent.width - width - 8
            height: parent.height
            spacing: 4

            // Las que solo salen cuando pasa algo (jugando, no suspender...)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tema.separacion
                Jugando {}
                Cafe {}
                Novedades { pantalla: barra.modelData }
                Usb { pantalla: barra.modelData }
            }

            Bandeja {
                anchors.verticalCenter: parent.verticalCenter
                ventana: barra
                oculta: !Ajustes.islaBandeja
                color: "transparent"
                border.width: 0
                relleno: 2
            }

            // Conexión, volumen y batería en un solo botón: el centro de
            // control (como los ajustes rápidos de Windows). Rueda = volumen
            Boton {
                id: estado
                readonly property var dispositivos: Networking.devices.values
                readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
                readonly property var redWifi: dispositivos.find(d => d.type === DeviceType.Wifi)?.networks.values.find(r => r.connected) ?? null
                readonly property var senales: ["󰤟", "󰤢", "󰤥", "󰤨"]

                readonly property var salida: Pipewire.defaultAudioSink
                PwObjectTracker { objects: [estado.salida] }
                readonly property real volumen: salida?.audio?.volume ?? 0
                readonly property bool mudo: salida?.audio?.muted ?? true

                readonly property var bateria: UPower.displayDevice
                readonly property bool hayBateria: bateria && bateria.isLaptopBattery
                readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
                readonly property bool cargando: hayBateria
                    && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)

                encendido: Paneles.esta("pildora", barra.modelData, "control")
                onClic: boton => {
                    if (boton === Qt.MiddleButton && salida?.audio)
                        salida.audio.muted = !mudo;
                    else
                        Paneles.abrirPagina(barra.modelData, "control", "derecha");
                }
                onRueda: pasos => {
                    if (!salida?.audio)
                        return;
                    salida.audio.muted = false;
                    salida.audio.volume = Math.max(0, Math.min(1, Math.round(volumen * 20 + pasos) / 20));
                }

                Row {
                    spacing: 10
                    Text {
                        text: Vpn.conectadas.length > 0 ? "󰦝"
                            : estado.cable ? "󰈀"
                            : estado.redWifi ? estado.senales[Math.min(3, Math.floor(estado.redWifi.signalStrength * 4))]
                            : !Networking.wifiEnabled ? "󰤭" : "󰤮"
                        font.family: Tema.mono
                        font.pixelSize: Tema.letra + 3
                        color: estado.cable || estado.redWifi ? Tema.texto : Tema.tenue
                    }
                    Text {
                        text: estado.mudo ? "󰖁" : estado.volumen < 0.34 ? "󰕿" : estado.volumen < 0.67 ? "󰖀" : "󰕾"
                        font.family: Tema.mono
                        font.pixelSize: Tema.letra + 3
                        color: estado.mudo ? Tema.tenue : Tema.texto
                    }
                    Text {
                        visible: estado.hayBateria
                        text: estado.cargando ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(estado.carga / 20))]
                        font.family: Tema.mono
                        font.pixelSize: Tema.letra + 3
                        color: !estado.cargando && estado.carga <= 15 ? Tema.rojo : Tema.texto
                    }
                }
            }

            // La hora y la fecha, una sobre otra (clic = calendario)
            Boton {
                encendido: Paneles.esta("pildora", barra.modelData, "calendario")
                onClic: Paneles.abrirPagina(barra.modelData, "calendario", "derecha")
                SystemClock {
                    id: reloj
                    precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes
                }
                Column {
                    spacing: -2
                    Mono {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(reloj.date, (Ajustes.reloj24 ? "HH:mm" : "h:mm AP") + (Ajustes.relojSegundos ? ":ss" : ""))
                    }
                    Mono {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(reloj.date, "dd/MM/yyyy")
                        color: Tema.gris
                        font.pixelSize: Math.min(11, Tema.letra - 2)
                    }
                }
            }

            // Notificaciones: el número de las nuevas (clic derecho = no molestar)
            Boton {
                crece: true
                encendido: Paneles.esta("notificaciones", barra.modelData)
                onClic: boton => boton === Qt.RightButton ? Notificaciones.noMolestar = !Notificaciones.noMolestar
                    : Paneles.alternar("notificaciones", barra.modelData, "")
                Text {
                    text: Notificaciones.noMolestar ? "󰂛" : "󰂚"
                    font.family: Tema.mono
                    font.pixelSize: Tema.letra + 3
                    color: Tema.texto
                    Rectangle {
                        visible: Notificaciones.hayNuevas && !Notificaciones.noMolestar
                        x: parent.width - 4
                        y: -4
                        width: Math.max(14, cuantas.implicitWidth + 6)
                        height: 14
                        radius: 7
                        color: Tema.blanco
                        Text {
                            id: cuantas
                            anchors.centerIn: parent
                            text: Notificaciones.sinLeer > 9 ? "9+" : Notificaciones.sinLeer
                            font.family: Tema.mono
                            font.pixelSize: 9
                            font.bold: true
                            color: Tema.oscuro
                        }
                    }
                }
            }
        }
    }

    // Menú de las apps (clic con varias ventanas y clic derecho)
    MenuApp {
        id: menu
        fijar: "Fijar en la barra"
        quitar: "Quitar de la barra"
    }
    Connections {
        target: Niri
        function onOverviewChanged() {
            if (Niri.overview)
                menu.cerrar();
        }
    }
}
