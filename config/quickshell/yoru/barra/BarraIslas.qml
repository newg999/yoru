// ============================================================================
//  BarraIslas — las islas de arriba, en píldoras (Ajustes.pildoras)
//
//    [⚙ 󰍉] [escritorios] [bandeja] [música]   [tiempo · hora · grabando] [󰂚]   [… avisos] [wifi · teclado · bluetooth · volumen · batería]
//
//  Píldoras casi negras y redondas del todo, con fichas dentro (Ficha.qml):
//  grises, o del color del tema cuando algo está encendido. Letra
//  monoespaciada. CPU, memoria, temperatura y disco no van aquí: están en
//  los widgets del escritorio (Escritorio.qml).
//  La música y la grabación solo salen cuando hay algo.
//  La barra a la izquierda sigue siendo Barra.qml.
//
//  Cada panel sale de la isla que lo abre, fundido con ella (Panel.qml).
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
    visible: Ajustes.conPildoras && !Ajustes.isla
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    // Solo con la ventana ya a la vista: si se enciende antes (la cafeína
    // ya estaba puesta al arrancar o al cambiar de estilo), Wayland no se
    // entera y la pantalla se bloquea igual
    IdleInhibitor {
        window: barra
        enabled: Despierto.activo && barra.backingWindowVisible
    }

    // De qué isla sale cada panel (para fundirlo con ella: Panel.qml)
    // (se reasigna entera para que avise: Avisos.qml la sigue con un binding)
    Component.onCompleted: Paneles.islas = Object.assign({}, Paneles.islas, {[modelData.name]: {
        // (el tiempo va dentro de la isla de la hora)
        botones, musica, clima: centro, centro, notificaciones, novedades, discos, bandeja,
        red: islaEstado, bt: islaEstado, sonido: islaEstado, bateria: islaEstado, control: islaEstado,
        // (estado: la de la derecha; la usan otras páginas como reserva)
        estado: islaEstado
    }})

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
        Region { item: bandeja; radius: Tema.radioIsla }
        Region { item: jugando; radius: Tema.radioIsla }
        Region { item: cafe; radius: Tema.radioIsla }
        Region { item: novedades; radius: Tema.radioIsla }
        Region { item: discos; radius: Tema.radioIsla }
        Region { item: notificaciones; radius: Tema.radioIsla }
        Region { item: islaEstado; radius: Tema.radioIsla }
    }

    // Texto monoespaciado de las píldoras (del tamaño de Ajustes › Aspecto › Letra)
    component Mono: Text {
        color: Tema.texto
        font.family: Tema.mono
        font.pixelSize: Tema.letra
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

            // Las apps en segundo plano (Spotify, Telegram, Discord...): clic =
            // sale flotando, otro clic = se esconde (Bandeja.qml). Antes iba
            // dentro de la isla del estado, a la derecha
            // (aquí estaba el tiempo: ahora va con la hora, en el centro)
            Bandeja {
                id: bandeja
                ventana: barra
                oculta: !Ajustes.islaBandeja
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
                    onClic: Reproductor.anterior(musica.reproductor)
                }
                Ficha {
                    icono: musica.reproductor?.isPlaying ? "󰏤" : "󰐊"; tamIcono: 12
                    apagada: !musica.reproductor
                    onClic: musica.reproductor?.togglePlaying()
                }
                Ficha {
                    icono: "󰒭"; tamIcono: 11
                    apagada: !musica.reproductor
                    onClic: Reproductor.siguiente(musica.reproductor)
                }
            }
        }

        // ---------------------------------------------------------- Centro
        // El tiempo, la hora y la fecha (y la grabación, si se graba), juntos.
        // Clic en el tiempo = previsión; en la hora = calendario
        Isla {
            id: centro
            x: Math.round((contenido.width - width) / 2)
            relleno: 10
            // Sin espacio entre elementos: el de la grabación, aun oculto,
            // dejaba 10 px de más a la derecha de la fecha. Lleva el suyo
            espacio: 0

            SystemClock {
                id: reloj
                precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes
            }
            readonly property var dias: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
            readonly property var meses: ["ene", "feb", "mar", "abr", "may", "jun", "jul",
                "ago", "sep", "oct", "nov", "dic"]

            // El tiempo: icono y grados, sin la «C» (clic = previsión)
            Item {
                id: climaDentro
                visible: Ajustes.islaClima && Tiempo.listo
                implicitWidth: filaClima.implicitWidth
                implicitHeight: Tema.altoBarra
                Row {
                    id: filaClima
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.icono
                        font.family: Tema.mono
                        font.pixelSize: Tema.letra + 4
                        color: Tema.blanco
                    }
                    Mono {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.temperatura + "°"
                        color: climaRaton.containsMouse || Paneles.esta("pildora", barra.modelData, "clima") ? Tema.blanco : Tema.texto
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
            // Separador fino entre el tiempo y la hora
            Item {
                visible: climaDentro.visible
                implicitWidth: 21
                implicitHeight: Tema.altoBarra
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 12
                    color: Tema.claro(0.18)
                }
            }

            // Hora y fecha en una línea (segundos según Ajustes › Fecha y hora).
            // Clic = calendario
            Item {
                implicitWidth: hora.implicitWidth
                implicitHeight: Tema.altoBarra
                Row {
                    id: hora
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Mono {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(reloj.date, (Ajustes.reloj24 ? "HH:mm" : "h:mm AP") + (Ajustes.relojSegundos ? ":ss" : ""))
                        color: horaRaton.containsMouse || Paneles.esta("pildora", barra.modelData, "calendario") ? Tema.texto : Tema.blanco
                        font.pixelSize: Tema.letra + 1
                    }
                    Mono {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${centro.dias[reloj.date.getDay()]} ${reloj.date.getDate()} ${centro.meses[reloj.date.getMonth()]}`
                        color: Tema.texto
                        font.bold: false
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
                implicitWidth: filaGrabando.implicitWidth + 10
                implicitHeight: 22
                Row {
                    id: filaGrabando
                    x: 10
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
        }

        // Las notificaciones, en su isla justo a la derecha de la hora y
        // siempre a la vista (con o sin avisos: el punto rojo marca los
        // nuevos). Su panel y los avisos que llegan salen debajo, en el centro
        Campana {
            id: notificaciones
            x: centro.x + centro.width + Tema.separacion
            cual: "notificaciones"
            pantalla: barra.modelData
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
            // (la campana ya no va aquí: está en el centro, junto a la hora)

            // Lo que necesitan las islas de la derecha (no se ve: no ocupa sitio)
            Item {
                id: estado
                visible: false
                readonly property var dispositivos: Networking.devices.values
                readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
                readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
                readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null

                readonly property var adaptador: Bluetooth.defaultAdapter
                readonly property int conectados: Bluetooth.devices.values.filter(d => d.connected).length

                readonly property var salida: Pipewire.defaultAudioSink
                PwObjectTracker { objects: [estado.salida] }
                readonly property real volumen: salida?.audio?.volume ?? 0
                readonly property bool mudo: salida?.audio?.muted ?? true

                readonly property var bateria: UPower.displayDevice
                readonly property bool hayBateria: bateria && bateria.isLaptopBattery
                readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
                readonly property bool cargando: hayBateria
                    && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)
            }

            // Wi-Fi, teclado, Bluetooth, volumen, batería y centro de control,
            // juntos en una isla y solo con sus iconos (el nombre de la red y
            // los porcentajes, al dejar el ratón encima). Con «Paneles que
            // salen de su isla», la isla entera se convierte en el panel y sus
            // iconos quedan arriba: el del panel abierto, marcado (elegida), y
            // pulsar otro cambia de página sin cerrar
            Isla {
                id: islaEstado
                relleno: 4
                espacio: 4
                ayuda: [estado.cable ? "Cable" : estado.redWifi ? estado.redWifi.name : "Sin red",
                        "Volumen " + (estado.mudo ? "silenciado" : Math.round(estado.volumen * 100) + "%"),
                        estado.hayBateria ? "Batería " + estado.carga + "%" + (estado.cargando ? (estado.carga < 100 ? " · cargando" : " · enchufada") : "") : ""]
                    .filter(t => t !== "").join("  ·  ")

                // Wi-Fi o cable: del color del tema con conexión. Con el wifi apagado (y sin cable) no sale
                Ficha {
                    readonly property var senales: ["󰤟", "󰤢", "󰤥", "󰤨"]
                    icono: estado.cable ? "󰈀"
                        : estado.redWifi ? senales[Math.min(3, Math.floor(estado.redWifi.signalStrength * 4))]
                        : !Networking.wifiEnabled ? "󰤭" : "󰤮"
                    // (apagado sigue a la vista, en gris: desde aquí se vuelve a encender)
                    visible: estado.cable !== null || estado.wifi !== null
                    apagada: estado.cable === null && !Networking.wifiEnabled
                    cable: estado.cable !== null
                    activa: estado.cable !== null || estado.redWifi !== null
                    // VPN conectada: un escudito en la esquina del icono
                    insignia: Vpn.conectadas.length > 0 ? "󰦝" : ""
                    elegida: Paneles.esta("pildora", barra.modelData, "red")
                    onClic: Paneles.abrirPagina(barra.modelData, "red", "derecha")
                }

                // Distribución del teclado: clic = la siguiente. Con una sola no sale
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

                // Bluetooth (cuántos hay conectados). Apagado sigue a la vista,
                // en gris: el centro de control ya no lo lleva y desde aquí se
                // vuelve a encender
                Ficha {
                    readonly property bool encendido: estado.adaptador?.enabled ?? false
                    visible: estado.adaptador !== null
                    icono: !encendido ? "󰂲" : estado.conectados > 0 ? "󰂱" : "󰂯"
                    texto: encendido && estado.conectados > 0 ? String(estado.conectados) : ""
                    activa: encendido
                    apagada: !encendido
                    elegida: Paneles.esta("pildora", barra.modelData, "bt")
                    onClic: Paneles.abrirPagina(barra.modelData, "bt", "derecha")
                }

                // Volumen · rueda = subir/bajar · clic central = silenciar
                Ficha {
                    icono: estado.mudo ? "󰖁" : estado.volumen < 0.34 ? "󰕿" : estado.volumen < 0.67 ? "󰖀" : "󰕾"
                    volumen: estado.volumen
                    mudo: estado.mudo
                    // (silenciado sigue a la vista, en gris)
                    visible: estado.salida !== null
                    apagada: estado.mudo
                    elegida: Paneles.esta("pildora", barra.modelData, "sonido")
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
                Ficha {
                    visible: estado.hayBateria
                    icono: estado.cargando ? "󰂄" : "󰁹"
                    carga: estado.carga / 100
                    cargando: estado.cargando
                    // Cargando: el relleno ondea, como agua entrando
                    ola: estado.cargando && estado.carga < 100
                    // Por colores, como en el iPhone (Tema.bateria)
                    colorCarga: Tema.bateria(estado.carga / 100, estado.cargando)
                    colorIcono: !estado.cargando && estado.carga <= 15 ? Tema.bateria(estado.carga / 100, false) : tinta
                    // (una página más del panel de la derecha: del volumen a la
                    // batería se pasa deslizando, sin cerrar)
                    elegida: Paneles.esta("pildora", barra.modelData, "bateria")
                    onClic: Paneles.abrirPagina(barra.modelData, "bateria", "derecha")
                }

                // Centro de control
                Ficha {
                    icono: "󰍜"
                    elegida: Paneles.esta("pildora", barra.modelData, "control")
                    onClic: Paneles.abrirPagina(barra.modelData, "control", "derecha")
                }
            }
        }
    }
}
