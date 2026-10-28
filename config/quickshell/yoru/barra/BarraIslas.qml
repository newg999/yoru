// ============================================================================
//  BarraIslas — las islas de arriba, en píldoras (Ajustes.pildoras)
//
//    [⚙ 󰍉] [escritorios] [música]   [hora · grabando · tiempo]   [… avisos] [bandeja · wifi · teclado · bluetooth · volumen · batería]
//
//  Píldoras casi negras y redondas del todo, con fichas dentro (Ficha.qml):
//  grises, o del color del tema cuando algo está encendido. Letra
//  monoespaciada. CPU, memoria, temperatura y disco no van aquí: están en
//  los widgets del escritorio (Escritorio.qml).
//  La música y la grabación solo salen cuando hay algo.
//  La barra a la izquierda sigue siendo Barra.qml.
//
//  Con la minimalista es esta misma barra, pero sobre una franja entera de
//  lado a lado, pegada arriba (las islas, sin fondo: Isla.qml). Los paneles
//  se abren pegados a ella (Panel.qml).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

PanelWindow {
    id: barra
    required property ShellScreen modelData
    screen: modelData

    readonly property bool pequena: modelData.width < 1800
    // Minimalista: una franja entera, pegada arriba
    readonly property bool entera: Ajustes.minimalista
    readonly property int altoFranja: Tema.altoBarra + 2

    anchors { top: true; left: true; right: true }
    implicitHeight: entera ? altoFranja : Tema.margenBarra + Tema.altoBarra
    // (con la minimalista, niri no deja huecos: las ventanas, justo debajo)
    exclusiveZone: entera ? altoFranja : Tema.zonaBarra
    color: "transparent"
    visible: Ajustes.conPildoras
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    IdleInhibitor {
        window: barra
        enabled: Despierto.activo
    }

    MouseArea {
        anchors.fill: parent
        enabled: Paneles.abierto !== ""
        onClicked: Paneles.cerrar()
    }

    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : barra.entera ? todo : islas
    Region { id: todo; item: franja }
    Region {
        id: islas
        Region { item: botones; radius: Tema.radioIsla }
        Region { item: escritorios; radius: Tema.radioIsla }
        Region { item: musica; radius: Tema.radioIsla }
        Region { item: centro; radius: Tema.radioIsla }
        Region { item: jugando; radius: Tema.radioIsla }
        Region { item: cafe; radius: Tema.radioIsla }
        Region { item: novedades; radius: Tema.radioIsla }
        Region { item: discos; radius: Tema.radioIsla }
        Region { item: notificaciones; radius: Tema.radioIsla }
        Region { item: estado; radius: Tema.radioIsla }
    }

    // Texto monoespaciado de las píldoras
    component Mono: Text {
        color: Tema.texto
        font.family: Tema.mono
        font.pixelSize: 11
        font.bold: true
        verticalAlignment: Text.AlignVCenter
    }

    // La franja de la minimalista: el mismo fondo que los paneles, que se
    // abren pegados a ella
    Rectangle {
        id: franja
        visible: barra.entera
        width: parent.width
        height: barra.altoFranja
        color: Tema.panel
        opacity: Niri.overview ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
        transform: Translate {
            y: Niri.overview ? -barra.altoFranja : 0
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        // Clic en un hueco libre: cierra el panel que haya abierto
        MouseArea {
            anchors.fill: parent
            onClicked: Paneles.cerrar()
        }
    }

    Item {
        id: contenido
        opacity: Niri.overview ? 0 : 1
        transform: Translate {
            y: Niri.overview ? -(Tema.altoBarra + Tema.margenBarra) : 0
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
        anchors {
            fill: parent
            topMargin: barra.entera ? 1 : Tema.margenBarra
            leftMargin: Tema.margenLados
            rightMargin: Tema.margenLados
        }

        // ------------------------------------------------------- Izquierda
        Row {
            id: izquierda
            spacing: Tema.separacion

            // Ajustes y buscar
            Isla {
                id: botones
                relleno: 4
                espacio: 4
                Ficha {
                    icono: "󰒓"
                    activa: Paneles.esta("ajustes", barra.modelData)
                    onClic: Paneles.alternar("ajustes", barra.modelData, "")
                }
                Ficha {
                    icono: "󰍉"
                    activa: Paneles.esta("lanzador", barra.modelData)
                    onClic: Paneles.alternar("lanzador", barra.modelData, "")
                }
            }

            // Escritorios: los de siempre (la píldora del activo y puntitos)
            Escritorios {
                id: escritorios
                salida: barra.modelData.name
            }

            // Música: solo con algo sonando (o en pausa)
            Isla {
                id: musica
                oculta: !Ajustes.islaMusica || !reproductor
                relleno: 4
                espacio: 4
                readonly property var reproductor: Reproductor.actual
                // Su panel, justo debajo y de su mismo ancho
                function abrir() {
                    const p = musica.mapToItem(null, 0, 0);
                    Paneles.abrirPagina(barra.modelData, "musica", "centro", {x: p.x, ancho: musica.width});
                }
                readonly property string cancion: {
                    const r = reproductor;
                    if (!r)
                        return "Nada sonando";
                    const titulo = Reproductor.titulo(r);
                    return r.trackArtist && titulo ? `${titulo} · ${r.trackArtist}` : (titulo || r.trackArtist || Reproductor.nombre(r));
                }
                Ficha {
                    icono: "󰝚"
                    activa: musica.reproductor?.isPlaying ?? false
                    onClic: musica.abrir()
                }
                Item {
                    implicitWidth: textoMusica.width + 16
                    implicitHeight: 22
                    Mono {
                        id: textoMusica
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: musica.cancion
                        color: musica.reproductor ? Tema.texto : Tema.gris
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, barra.pequena ? 150 : 240)
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: musica.reproductor !== null
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: e => e.button === Qt.MiddleButton ? musica.reproductor.togglePlaying()
                            : musica.abrir()
                    }
                }
                Ficha {
                    icono: "󰒮"; tamIcono: 11
                    apagada: !musica.reproductor
                    onClic: musica.reproductor?.previous()
                }
                Ficha {
                    icono: musica.reproductor?.isPlaying ? "󰏤" : "󰐊"; tamIcono: 12
                    apagada: !musica.reproductor
                    onClic: musica.reproductor?.togglePlaying()
                }
                Ficha {
                    icono: "󰒭"; tamIcono: 11
                    apagada: !musica.reproductor
                    onClic: musica.reproductor?.next()
                }
            }
        }

        // ---------------------------------------------------------- Centro
        // Hora (con la fecha debajo) · cronómetro · tiempo
        Isla {
            id: centro
            x: Math.round((contenido.width - width) / 2)
            relleno: 14
            espacio: 14

            SystemClock {
                id: reloj
                precision: SystemClock.Seconds
            }
            readonly property var dias: ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
            readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

            // Clic = calendario
            Item {
                implicitWidth: hora.implicitWidth
                implicitHeight: Tema.altoBarra
                Column {
                    id: hora
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -3
                    Mono {
                        text: Qt.formatDateTime(reloj.date, Ajustes.reloj24 ? "HH:mm:ss" : "h:mm:ss AP")
                        color: horaRaton.containsMouse || Paneles.esta("pildora", barra.modelData, "calendario") ? Tema.texto : Tema.blanco
                        font.pixelSize: 12
                    }
                    Mono {
                        text: `${centro.dias[reloj.date.getDay()]}, ${reloj.date.getDate()} de ${centro.meses[reloj.date.getMonth()]}`
                        color: Tema.gris
                        font.pixelSize: 8
                    }
                }
                MouseArea {
                    id: horaRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Paneles.abrirPagina(barra.modelData, "calendario", "centro")
                }
            }

            // Grabando la pantalla (comun/Grabacion.qml): solo mientras graba.
            // Clic = parar y guardar (o Mod+Alt+R)
            Item {
                visible: Grabacion.grabando
                implicitWidth: filaGrabando.implicitWidth
                implicitHeight: 22
                Row {
                    id: filaGrabando
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        color: Tema.rojo
                        SequentialAnimation on opacity {
                            running: Grabacion.grabando && Ajustes.animaciones
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    Mono {
                        text: Grabacion.tiempo
                        color: grabandoRaton.containsMouse ? Tema.blanco : Tema.rojo
                    }
                }
                MouseArea {
                    id: grabandoRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Grabacion.alternar()
                }
            }

            Item {
                visible: Ajustes.islaClima && Tiempo.listo
                implicitWidth: filaClima.implicitWidth
                implicitHeight: 22
                Row {
                    id: filaClima
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.icono
                        font.family: Tema.mono
                        font.pixelSize: 15
                        color: Tema.blanco
                    }
                    Mono {
                        text: Tiempo.temperatura + "°C"
                        color: climaRaton.containsMouse ? Tema.blanco : Tema.amarillo
                    }
                }
                MouseArea {
                    id: climaRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Paneles.abrirPagina(barra.modelData, "clima", "centro")
                }
            }
        }

        // --------------------------------------------------------- Derecha
        Row {
            id: derecha
            x: Math.round(contenido.width - width)
            spacing: Tema.separacion
            layoutDirection: Qt.LeftToRight

            // Las que solo salen cuando pasa algo (grabando, jugando...)
            Jugando { id: jugando }
            Cafe { id: cafe }
            Novedades { id: novedades; pantalla: barra.modelData }
            Usb { id: discos; pantalla: barra.modelData }
            Campana {
                id: notificaciones
                cual: "notificaciones"
                pantalla: barra.modelData
                oculta: !Notificaciones.hayNuevas && !Notificaciones.noMolestar
            }

            Isla {
                id: estado
                relleno: 4
                espacio: 4

                Bandeja {
                    ventana: barra
                    oculta: !Ajustes.islaBandeja
                    color: "transparent"
                    border.width: 0
                    relleno: 2
                }

                // Wi-Fi o cable: del color del tema con conexión. Con el
                // wifi apagado (y sin cable) no sale
                readonly property var dispositivos: Networking.devices.values
                readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
                readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
                readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
                Ficha {
                    readonly property var senales: ["󰤟", "󰤢", "󰤥", "󰤨"]
                    icono: estado.cable ? "󰈀"
                        : estado.redWifi ? senales[Math.min(3, Math.floor(estado.redWifi.signalStrength * 4))]
                        : !Networking.wifiEnabled ? "󰤭" : "󰤮"
                    texto: estado.cable ? "Cable" : estado.redWifi ? estado.redWifi.name : "Sin red"
                    visible: estado.cable !== null || Networking.wifiEnabled
                    anchoTexto: barra.pequena ? 90 : 140
                    activa: estado.cable !== null || estado.redWifi !== null
                    onClic: Paneles.abrirPagina(barra.modelData, "red", "derecha")
                }
                // VPN conectada: un escudo
                Ficha {
                    visible: Vpn.conectadas.length > 0
                    icono: "󰦝"
                    activa: true
                    onClic: Paneles.abrirPagina(barra.modelData, "red", "derecha")
                }

                // Distribución del teclado: clic = la siguiente. Con una
                // sola no sale (no hay nada que cambiar)
                Ficha {
                    id: teclado
                    property string corto: ""
                    property int cuantas: 0
                    icono: "󰌌"
                    texto: corto
                    visible: corto !== "" && cuantas > 1
                    onClic: {
                        Niri.accion("switch-layout", "next");
                        leerTeclado.restart();
                    }
                    Process {
                        id: distribuciones
                        running: true
                        command: ["niri", "msg", "-j", "keyboard-layouts"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                try {
                                    const k = JSON.parse(text);
                                    teclado.cuantas = k.names.length;
                                    const nombre = k.names[k.current_idx] ?? "";
                                    const codigos = {Spanish: "ES", English: "EN", French: "FR", German: "DE", Portuguese: "PT", Italian: "IT", Catalan: "CA"};
                                    const clave = Object.keys(codigos).find(c => nombre.startsWith(c));
                                    teclado.corto = clave ? codigos[clave] : nombre.slice(0, 2).toUpperCase();
                                } catch (e) {
                                    teclado.corto = "";
                                }
                            }
                        }
                    }
                    Timer {
                        id: leerTeclado
                        interval: 200
                        onTriggered: distribuciones.running = true
                    }
                }

                // Bluetooth: solo encendido («On», o cuántos hay conectados).
                // Apagado no sale: se enciende en el Centro de control (󰍜)
                readonly property var adaptador: Bluetooth.defaultAdapter
                readonly property int conectados: Bluetooth.devices.values.filter(d => d.connected).length
                Ficha {
                    visible: estado.adaptador?.enabled ?? false
                    icono: estado.conectados > 0 ? "󰂱" : "󰂯"
                    texto: estado.conectados > 0 ? String(estado.conectados) : "On"
                    activa: true
                    onClic: Paneles.abrirPagina(barra.modelData, "bt", "derecha")
                }

                // Volumen · rueda = subir/bajar · clic central = silenciar.
                // Silenciado (o sin salida) no sale: se quita en el Centro de control
                readonly property var salida: Pipewire.defaultAudioSink
                PwObjectTracker { objects: [estado.salida] }
                readonly property real volumen: salida?.audio?.volume ?? 0
                readonly property bool mudo: salida?.audio?.muted ?? true
                Ficha {
                    icono: estado.mudo ? "󰖁" : estado.volumen < 0.34 ? "󰕿" : estado.volumen < 0.67 ? "󰖀" : "󰕾"
                    texto: Math.round(estado.volumen * 100) + "%"
                    visible: !estado.mudo
                    onClic: boton => {
                        if (boton === Qt.MiddleButton)
                            estado.salida.audio.muted = !estado.mudo;
                        else if (boton === Qt.RightButton)
                            Niri.lanzar(["pavucontrol"]);
                        else
                            Paneles.abrirPagina(barra.modelData, "sonido", "derecha");
                    }
                    onRueda: pasos => {
                        if (!estado.salida?.audio)
                            return;
                        estado.salida.audio.muted = false;
                        estado.salida.audio.volume = Math.max(0, Math.min(1, Math.round(estado.volumen * 20 + pasos) / 20));
                    }
                }

                // Batería: la ficha se llena según la carga
                readonly property var bateria: UPower.displayDevice
                readonly property bool hayBateria: bateria && bateria.isLaptopBattery
                readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
                readonly property bool cargando: hayBateria
                    && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)
                Ficha {
                    visible: estado.hayBateria
                    icono: estado.cargando ? "󰂄" : "󰁹"
                    texto: estado.carga + "%"
                    carga: estado.carga / 100
                    // Cargando: el relleno ondea, como agua entrando
                    ola: estado.cargando && estado.carga < 100
                    colorIcono: !estado.cargando && estado.carga <= 15 ? Tema.rojo : tinta
                    onClic: Paneles.alternar("bateria", barra.modelData, "")
                }

                // Centro de control
                Ficha {
                    icono: "󰍜"
                    activa: Paneles.esta("pildora", barra.modelData, "control")
                    onClic: Paneles.abrirPagina(barra.modelData, "control", "derecha")
                }
            }
        }
    }
}
