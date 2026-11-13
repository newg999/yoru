// ============================================================================
//  BarraIsla — una sola isla arriba en el centro, viva: en reposo es una
//  píldora pequeña y, cuando pasa algo, cambia de forma para enseñarlo y
//  vuelve a su tamaño. Dentro vive la lunita (Personaje.qml).
//  (Ajustes › Barra y dock › Isla)
//
//    reposo     ( ◕‿◕  • ━ •   18:42   󰖩 󰂯 󰕾 󰁹 )
//    aviso      ( [icono]  Telegram                       )   4,5 s
//               (          Ana: ¿bajas ya?                )   (ratón encima: espera)
//    volumen    ( 󰕾  ━━━━━━━━━━━○──────  45% )            1,5 s (brillo y micro igual)
//    canción    ( [carátula]  Título · Artista   ılıl )     3 s al empezar una
//    cargador   ( 󰂄  Cargando · 54% )                       2,5 s al enchufar o desenchufar
//
//    clic en la luna = tus apps · en la hora = calendario · a la derecha =
//    centro de control · rueda = escritorio anterior / siguiente
//    en un aviso: clic = abrirlo · clic derecho = quitarlo
//    en la canción: clic = Multimedia
//
//  La luna: contenta con música, se asusta un poco con cada aviso, suda con
//  poca batería, se duerme si no usas el equipo y te sigue con la mirada
//  si pasas el ratón por la isla. Clic en ella: te guiña un ojo.
//  Los paneles cuelgan de la isla (Paneles.islaUnica), y con uno abierto
//  la isla no cambia de forma.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

PanelWindow {
    id: barra
    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    // Sitio para cuando crece; solo reserva lo de la barra
    implicitHeight: Tema.margenBarra + 120
    exclusiveZone: Tema.zonaBarra
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    // Solo la isla recibe clics (y nada en el overview). Con un panel
    // abierto, toda la franja de arriba: un clic al lado de la isla lo
    // cierra (como con las islas de siempre)
    mask: Niri.overview ? vacia : barra.algoAbierto ? regionFranja : region
    Region { id: vacia }
    Region { id: region; item: isla }
    Region { id: regionFranja; item: franja }
    readonly property bool algoAbierto: Paneles.abierto !== ""
    Item {
        id: franja
        width: parent.width
        height: Tema.margenBarra + Tema.altoBarra
    }
    MouseArea {
        anchors.fill: franja
        enabled: barra.algoAbierto
        onClicked: Paneles.cerrar()
    }
    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : desenfoque
    Region { id: desenfoque; item: isla; radius: isla.radius }

    // La cafeína (Despierto) se agarra a una ventana visible: esta
    IdleInhibitor {
        window: barra
        enabled: Despierto.activo && barra.backingWindowVisible
    }
    // Sin usar el equipo un rato: la luna se duerme
    IdleMonitor {
        id: reposo
        timeout: 180
        respectInhibitors: true
    }

    // Los paneles cuelgan de la isla
    Component.onCompleted: Paneles.islaUnica = Object.assign({}, Paneles.islaUnica, {[modelData.name]: isla})

    readonly property bool enfocada: (Niri.escritorios.find(e => e.is_focused)?.output ?? modelData.name) === modelData.name
    readonly property bool panelAbierto: Paneles.abierto !== "" && Paneles.pantalla === modelData

    // ------------------------------------------------------- Estado
    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [barra.salida, barra.entrada] }
    readonly property real volumen: salida?.audio?.volume ?? 0
    readonly property bool mudo: salida?.audio?.muted ?? true

    readonly property var dispositivos: Networking.devices.values
    readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter

    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria && bateria.isLaptopBattery
    readonly property int carga: hayBateria ? Math.round(bateria.percentage * 100) : 0
    readonly property bool cargando: hayBateria
        && (bateria.state === UPowerDeviceState.Charging || bateria.state === UPowerDeviceState.FullyCharged)

    readonly property var musica: Reproductor.actual
    readonly property bool sonando: musica?.isPlaying ?? false

    // ------------------------------------------------------- Actividades
    // Lo que enseña ahora: "" (reposo) · "aviso" · "volumen" · "micro" ·
    // "brillo" · "cancion" · "cargador"
    property string actividad: ""
    property var aviso: null            // la entrada de Notificaciones
    function mostrar(que, ms) {
        // Al arrancar, todo «cambia» de golpe: eso no cuenta
        if (!listo || !enfocada || panelAbierto)
            return;
        actividad = que;
        fin.interval = ms;
        fin.restart();
    }
    Timer {
        id: fin
        // Con el ratón encima de un aviso, espera
        onTriggered: {
            if (barra.actividad === "aviso" && raton.containsMouse) {
                restart();
                return;
            }
            barra.terminar();
        }
    }
    function terminar() {
        if (actividad === "aviso" && aviso)
            Notificaciones.ocultar(aviso);
        actividad = "";
        aviso = null;
    }
    onPanelAbiertoChanged: if (panelAbierto) terminar()

    property bool listo: false
    Timer { interval: 2500; running: true; onTriggered: barra.listo = true }

    // Avisos: el más nuevo
    Connections {
        target: Notificaciones
        function onEmergentesChanged() {
            const e = Notificaciones.emergentes[0];
            if (!e || e === barra.aviso)
                return;
            if (!barra.listo || !barra.enfocada || barra.panelAbierto) {
                // No se enseña: que no se quede pendiente para siempre
                if (barra.listo && barra.enfocada)
                    Notificaciones.ocultar(e);
                return;
            }
            barra.aviso = e;
            barra.mostrar("aviso", 4500);
            luna.sorpresa();
        }
    }
    // Volumen, micrófono y brillo
    Connections {
        target: barra.salida?.audio ?? null
        function onVolumeChanged() { barra.mostrar("volumen", 1500); }
        function onMutedChanged() { barra.mostrar("volumen", 1500); }
    }
    Connections {
        target: barra.entrada?.audio ?? null
        function onVolumeChanged() { barra.mostrar("micro", 1500); }
        function onMutedChanged() { barra.mostrar("micro", 1500); }
    }
    Connections {
        target: Brillo
        function onCambiadoConTecla() { barra.mostrar("brillo", 1500); }
    }
    // La canción, al empezar una (sin pisar un aviso)
    readonly property string cancion: musica ? (musica.trackTitle ?? "") + "·" + (musica.trackArtist ?? "") : ""
    onCancionChanged: if (sonando && musica?.trackTitle && actividad !== "aviso") mostrar("cancion", 3200)
    // El cargador
    onCargandoChanged: if (hayBateria && actividad !== "aviso") mostrar("cargador", 2500)

    // ------------------------------------------------------- La isla
    Rectangle {
        id: isla
        readonly property bool reposando: barra.actividad === ""
        // El ancho y el alto de lo que se enseña ahora
        readonly property Item contenido: barra.actividad === "aviso" ? cajaAviso
            : ["volumen", "micro", "brillo"].includes(barra.actividad) ? cajaNivel
            : barra.actividad === "cancion" ? cajaCancion
            : barra.actividad === "cargador" ? cajaCargador
            : cajaReposo
        // Lo que pide su contenido + el margen (cada uno dice su alto)
        width: Math.round(contenido.implicitWidth + 2 * relleno)
        height: contenido.altoIsla
        readonly property int relleno: reposando ? 8 : 14
        x: Math.round((barra.width - width) / 2)
        y: Tema.margenBarra
        radius: Math.min(height / 2, Tema.altoBarra / 2 + 8)
        // Creciendo queda encima de las ventanas: casi opaca, para leerse
        color: reposando ? Tema.isla : Tema.sombra(Math.max(0.96, Ajustes.opacidadIslas))
        Behavior on color { ColorAnimation { duration: Tema.normal } }
        border.width: Tema.borde(1)
        border.color: Tema.islaBorde
        clip: true
        Behavior on width { NumberAnimation { duration: Tema.rebote; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
        Behavior on height { NumberAnimation { duration: Tema.rebote; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

        // Para Panel.qml (las islas de siempre se funden; esta, no)
        function aportar(clave, cuanto) {}
        readonly property bool vacia: false

        // El ratón: la luna lo sigue con la mirada (la isla no cambia de tamaño)
        MouseArea {
            id: raton
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (barra.actividad === "aviso" && barra.aviso) {
                    const a = barra.aviso;
                    barra.terminar();
                    if (e.button === Qt.LeftButton)
                        Notificaciones.abrir(a);
                } else if (barra.actividad === "cancion") {
                    barra.terminar();
                    Paneles.abrirPagina(barra.modelData, "multimedia", "centro");
                } else if (barra.actividad !== "") {
                    barra.terminar();
                } else {
                    Paneles.abrirPagina(barra.modelData, "control", "centro");
                }
            }
            onWheel: e => Niri.accion(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
        }

        // ------------------------------------------------- Reposo
        Row {
            id: cajaReposo
            readonly property int altoIsla: Tema.altoBarra
            readonly property bool activa: isla.contenido === cajaReposo
            anchors.centerIn: parent
            spacing: 10
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            height: Tema.altoBarra

            // La luna: clic = tus apps
            Item {
                width: luna.width
                height: parent.height
                Personaje {
                    id: luna
                    anchors.verticalCenter: parent.verticalCenter
                    tam: Tema.altoBarra - 8
                    contento: barra.sonando
                    dormido: reposo.isIdle
                    preocupado: barra.hayBateria && !barra.cargando && barra.carga <= 15
                    siguiendo: raton.containsMouse
                    mirada: {
                        const p = luna.mapFromItem(isla, raton.mouseX, raton.mouseY);
                        return Qt.point(Math.max(-1, Math.min(1, (p.x - luna.width / 2) / 60)),
                                        Math.max(-1, Math.min(1, (p.y - luna.height / 2) / 14)));
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        luna.guino();
                        Paneles.alternar("lanzador", barra.modelData, "");
                    }
                }
            }

            // Escritorios: el activo, alargado
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: Niri.escritoriosDe(barra.modelData.name)
                    Rectangle {
                        required property var modelData
                        readonly property bool activo: modelData.is_active
                        anchors.verticalCenter: parent.verticalCenter
                        width: activo ? 18 : 7
                        height: 7
                        radius: 3.5
                        color: activo ? Tema.blanco : modelData.active_window_id !== null ? Tema.claro(0.45) : Tema.claro(0.2)
                        Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Tema.normal } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Niri.irA(parent.modelData)
                        }
                    }
                }
            }

            // Grabando: punto rojo y lo que lleva
            Row {
                visible: Grabacion.grabando
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Tema.rojo
                    SequentialAnimation on opacity {
                        running: Grabacion.grabando && Ajustes.animaciones
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Grabacion.tiempo
                    color: Tema.rojo
                }
            }

            // La hora: clic = calendario
            Item {
                width: hora.implicitWidth
                height: parent.height
                SystemClock { id: reloj; precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes }
                Texto {
                    id: hora
                    anchors.centerIn: parent
                    text: Qt.formatTime(reloj.date, Ajustes.relojSegundos ? "HH:mm:ss" : "HH:mm")
                    color: Tema.blanco
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Paneles.abrirPagina(barra.modelData, "calendario", "centro")
                }
            }

            // La bandeja (siempre: que la isla no cambie de ancho con el ratón)
            Bandeja {
                visible: Ajustes.islaBandeja
                anchors.verticalCenter: parent.verticalCenter
                ventana: barra
                color: "transparent"
                border.width: 0
                relleno: 0
            }

            // El estado: clic = centro de control
            Row {
                id: estado
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Texto {
                    readonly property var senales: ["󰤟", "󰤢", "󰤥", "󰤨"]
                    visible: barra.cable !== null || Networking.wifiEnabled
                    text: barra.cable ? "󰈀" : barra.redWifi ? senales[Math.min(3, Math.floor(barra.redWifi.signalStrength * 4))] : "󰤮"
                    font.pixelSize: Tema.letra + 2
                    color: barra.cable || barra.redWifi ? Tema.texto : Tema.tenue
                }
                Texto {
                    visible: barra.adaptador?.enabled ?? false
                    text: Bluetooth.devices.values.some(d => d.connected) ? "󰂱" : "󰂯"
                    font.pixelSize: Tema.letra + 2
                }
                Texto {
                    text: barra.mudo ? "󰖁" : barra.volumen < 0.34 ? "󰕿" : barra.volumen < 0.67 ? "󰖀" : "󰕾"
                    font.pixelSize: Tema.letra + 2
                    color: barra.mudo ? Tema.tenue : Tema.texto
                }
                Row {
                    visible: barra.hayBateria
                    spacing: 3
                    Texto {
                        text: barra.cargando ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(barra.carga / 20))]
                        font.pixelSize: Tema.letra + 2
                        color: !barra.cargando && barra.carga <= 15 ? Tema.rojo : Tema.texto
                    }
                    Texto {
                        visible: barra.carga <= 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: barra.carga + "%"
                        font.pixelSize: Tema.letra - 1
                        color: Tema.gris
                    }
                }
            }
        }

        // ------------------------------------------------- Un aviso
        Item {
            id: cajaAviso
            readonly property int altoIsla: Math.max(60, textosAviso.implicitHeight + 24)
            readonly property bool activa: isla.contenido === cajaAviso
            readonly property var n: barra.aviso?.n ?? null
            anchors.centerIn: parent
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            implicitWidth: Math.min(440, Math.max(260, 40 + 12 + textosAviso.implicitWidth))
            implicitHeight: filaAviso.implicitHeight
            width: implicitWidth
            height: implicitHeight
          Row {
            id: filaAviso
            spacing: 12

            Rectangle {
                width: 40; height: 40
                anchors.verticalCenter: parent.verticalCenter
                radius: Tema.esquina(12)
                color: Tema.caja
                IconImage {
                    id: iconoAviso
                    anchors.centerIn: parent
                    implicitSize: 26
                    source: cajaAviso.n ? Notificaciones.imagen(cajaAviso.n) : ""
                    // Sin icono (o uno que no existe): la campana
                    visible: source !== "" && status === Image.Ready
                }
                Texto {
                    visible: !iconoAviso.visible
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.pixelSize: 18
                    color: Tema.blanco
                }
            }
            Column {
                id: textosAviso
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 440 - 52)
                spacing: 2
                // La app, en mayúsculas pequeñas (como las tarjetas de avisos)
                Texto {
                    visible: text !== ""
                    width: Math.min(implicitWidth, 388)
                    elide: Text.ElideRight
                    text: (cajaAviso.n?.appName ?? "").toUpperCase()
                    textFormat: Text.PlainText
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                    color: Tema.gris
                }
                Texto {
                    width: Math.min(implicitWidth, 388)
                    elide: Text.ElideRight
                    text: cajaAviso.n ? (cajaAviso.n.summary || cajaAviso.n.appName || "Aviso") : ""
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                    color: Tema.blanco
                }
                Texto {
                    width: Math.min(implicitWidth, 388)
                    visible: text !== ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    text: cajaAviso.n ? (cajaAviso.n.body ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : ""
                    textFormat: Text.PlainText
                    font.bold: false
                    font.pixelSize: 12
                    color: Tema.gris
                }
            }
          }
        }

        // ---------------------------------- Volumen, micrófono o brillo
        Row {
            id: cajaNivel
            readonly property int altoIsla: Tema.altoBarra + 6
            readonly property bool activa: isla.contenido === cajaNivel
            readonly property string tipo: ["volumen", "micro", "brillo"].includes(barra.actividad) ? barra.actividad : tipoAntes
            property string tipoAntes: "volumen"
            onTipoChanged: tipoAntes = tipo
            readonly property var nodo: tipo === "micro" ? barra.entrada : barra.salida
            readonly property bool mudo: tipo !== "brillo" && (nodo?.audio?.muted ?? true)
            readonly property real valor: tipo === "brillo" ? (Brillo.pantallas[0]?.valor ?? 0) : (nodo?.audio?.volume ?? 0)
            anchors.centerIn: parent
            spacing: 12
            height: Tema.altoBarra
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }

            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: cajaNivel.tipo === "brillo" ? (cajaNivel.valor < 0.35 ? "󰃞" : cajaNivel.valor < 0.7 ? "󰃟" : "󰃠")
                    : cajaNivel.tipo === "micro" ? (cajaNivel.mudo ? "󰍭" : "󰍬")
                    : cajaNivel.mudo ? "󰖁" : cajaNivel.valor < 0.34 ? "󰕿" : cajaNivel.valor < 0.67 ? "󰖀" : "󰕾"
                font.pixelSize: Tema.letra + 4
                color: cajaNivel.mudo ? Tema.tenue : Tema.blanco
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 190; height: 6; radius: 3
                color: Tema.claro(0.12)
                Rectangle {
                    width: parent.width * Math.min(1, cajaNivel.valor)
                    height: parent.height; radius: 3
                    color: cajaNivel.mudo ? Tema.tenue : Tema.blanco
                    Behavior on width { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                }
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                horizontalAlignment: Text.AlignRight
                text: cajaNivel.mudo ? "No" : Math.round(cajaNivel.valor * 100) + "%"
                color: Tema.texto
            }
        }

        // -------------------------------------------- Empieza una canción
        Row {
            id: cajaCancion
            readonly property int altoIsla: 58
            readonly property bool activa: isla.contenido === cajaCancion
            anchors.centerIn: parent
            spacing: 12
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }

            ClippingRectangle {
                width: 40; height: 40
                anchors.verticalCenter: parent.verticalCenter
                radius: Tema.esquina(10)
                color: Tema.caja
                Image {
                    anchors.fill: parent
                    source: barra.musica ? Reproductor.caratula(barra.musica) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(80, 80)
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Texto {
                    width: Math.min(implicitWidth, 260)
                    elide: Text.ElideRight
                    text: barra.musica?.trackTitle ?? ""
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                    color: Tema.blanco
                }
                Texto {
                    width: Math.min(implicitWidth, 260)
                    elide: Text.ElideRight
                    text: barra.musica?.trackArtist ?? ""
                    textFormat: Text.PlainText
                    font.bold: false
                    font.pixelSize: 12
                    color: Tema.gris
                }
            }
            // Unas barritas que bailan
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        id: barrita
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; radius: 1.5
                        height: 6
                        color: Tema.blanco
                        SequentialAnimation on height {
                            running: cajaCancion.activa && Ajustes.animaciones
                            loops: Animation.Infinite
                            NumberAnimation { to: 6 + (barrita.index % 2 ? 10 : 14); duration: 260 + barrita.index * 70; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 5; duration: 260 + barrita.index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------ El cargador
        Row {
            id: cajaCargador
            readonly property int altoIsla: Tema.altoBarra + 6
            readonly property bool activa: isla.contenido === cajaCargador
            anchors.centerIn: parent
            spacing: 10
            height: Tema.altoBarra
            opacity: activa ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: barra.cargando ? "󰂄" : "󰁹"
                font.pixelSize: Tema.letra + 4
                color: barra.cargando ? Tema.bateria(barra.carga / 100, true) : Tema.texto
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: (barra.cargando ? "Cargando" : "Sin cargador") + "  " + Tema.suave(barra.carga + "%")
                textFormat: Text.StyledText
                color: Tema.blanco
            }
        }
    }
}
