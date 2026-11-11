// ============================================================================
//  Páginas «red», «bt» y «sonido»: solo lo de la ficha que se pulsó en las
//  islas en píldoras (barra/BarraIslas.qml), como en el dock
//
//    red      como el panel de red del dock (PaginaRed.qml)
//    bt       la misma, con la lista de Bluetooth
//    sonido   como el panel de sonido del dock (PaginaSonido.qml)
//    musica   lo que suena, en pequeño: carátula, canción, progreso y
//             botones (bajo la isla de la música y de su ancho)
//
//  El centro de control entero sigue en la página «control» (ver Paginas.qml)
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

Column {
    id: pagina

    property string cual: "red"
    property bool activa: false
    property var pantalla: null
    property int altoMax: 700
    spacing: 10

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var btConectados: Bluetooth.devices.values.filter(d => d.connected)

    // ------------------------------------------------------------- Red
    PaginaRed {
        visible: pagina.cual === "red" || pagina.cual === "bt"
        width: parent.width
        pantalla: pagina.pantalla
        altoMax: pagina.altoMax
        inicial: pagina.cual === "bt" ? "bt" : "wifi"
        activa: pagina.activa && (pagina.cual === "red" || pagina.cual === "bt")
    }

    // ---------------------------------------------------------- Música
    readonly property var reproductor: Reproductor.actual
    // Mpris no avisa de la posición: se pregunta cada segundo mientras se ve
    Timer {
        running: pagina.activa && pagina.cual === "musica" && (pagina.reproductor?.isPlaying ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: pagina.reproductor.positionChanged()
    }
    function tiempo(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), seg = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${seg}` : `${m}:${seg}`;
    }

    // Una tarjeta sobre la propia carátula, muy desenfocada y oscurecida
    // (como el reproductor del bloqueo): la carátula, la canción, por dónde
    // va (lo que lleva y lo que falta) y los botones
    ClippingRectangle {
        id: tarjetaMusica
        visible: pagina.cual === "musica"
        width: parent.width
        height: musica.height + 28
        radius: Tema.esquina(Tema.radioPanel - 4)
        color: Tema.caja
        readonly property string imagen: Reproductor.caratula(pagina.reproductor)
        readonly property bool sonando: pagina.reproductor?.isPlaying ?? false

        Image {
            id: fondoArte
            anchors.fill: parent
            visible: false
            source: tarjetaMusica.imagen
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        MultiEffect {
            anchors.fill: parent
            source: fondoArte
            visible: fondoArte.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 64
            brightness: -0.3
            saturation: 0.3
            autoPaddingEnabled: false
            opacity: 0.8
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
        }
        // Un velo de abajo arriba: los botones se leen sobre cualquier carátula
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Tema.sombra(0.35) }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: tarjetaMusica.radius
            color: "transparent"
            border.width: 1
            border.color: Tema.claro(0.08)
        }

        Column {
            id: musica
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10

            Row {
                width: parent.width
                spacing: 12
                ClippingRectangle {
                    id: caratula
                    width: 58; height: 58
                    radius: Tema.esquina(Tema.radioPanel - 6)
                    color: Tema.claro(0.08)
                    Texto {
                        anchors.centerIn: parent
                        visible: tarjetaMusica.imagen === ""
                        text: "󰝚"
                        font.pixelSize: 22
                        color: Tema.gris
                    }
                    Image {
                        anchors.fill: parent
                        visible: tarjetaMusica.imagen !== ""
                        source: tarjetaMusica.imagen
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(116, 116)
                        asynchronous: true
                        // Late un poco con la música
                        scale: tarjetaMusica.sonando ? 1 : 0.94
                        Behavior on scale { NumberAnimation { duration: Tema.ms(500); easing.type: Easing.OutCubic } }
                    }
                }
                Column {
                    width: parent.width - caratula.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    // De dónde sale, en pequeño y en mayúsculas
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Reproductor.nombre(pagina.reproductor).toUpperCase()
                        font.pixelSize: 9
                        font.letterSpacing: 1.2
                        color: Tema.gris
                    }
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Reproductor.titulo(pagina.reproductor) || "Sin título"
                        color: Tema.blanco
                        font.pixelSize: 14
                    }
                    Texto {
                        width: parent.width
                        visible: text !== ""
                        elide: Text.ElideRight
                        text: pagina.reproductor?.trackArtist ?? ""
                        font.bold: false
                        font.pixelSize: 12
                        opacity: 0.75
                    }
                }
            }

            Column {
                visible: (pagina.reproductor?.length ?? 0) > 0
                width: parent.width
                spacing: 0
                Deslizador {
                    width: parent.width
                    conOndas: true
                    ondas: pagina.activa && tarjetaMusica.sonando
                    valor: pagina.reproductor ? pagina.reproductor.position / pagina.reproductor.length : 0
                    onMovido: nuevo => {
                        if (pagina.reproductor?.canSeek)
                            pagina.reproductor.position = nuevo * pagina.reproductor.length;
                    }
                }
                Item {
                    width: parent.width
                    height: 12
                    Texto {
                        text: pagina.tiempo(pagina.reproductor?.position ?? 0)
                        font.bold: false; font.pixelSize: 10; color: Tema.gris
                        font.features: { "tnum": 1 }
                    }
                    // Lo que falta
                    Texto {
                        anchors.right: parent.right
                        text: "-" + pagina.tiempo((pagina.reproductor?.length ?? 0) - (pagina.reproductor?.position ?? 0))
                        font.bold: false; font.pixelSize: 10; color: Tema.gris
                        font.features: { "tnum": 1 }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22
                BotonIcono {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: "󰒮"
                    onClic: Reproductor.anterior(pagina.reproductor)
                }
                Rectangle {
                    width: 42; height: 42; radius: 21
                    color: Tema.blanco
                    scale: playRaton.pressed ? 0.92 : playRaton.containsMouse ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                    Texto {
                        anchors.centerIn: parent
                        // (el de pausa, centrado; el de play, un poco a la derecha: se ve centrado)
                        anchors.horizontalCenterOffset: tarjetaMusica.sonando ? 0 : 1
                        text: tarjetaMusica.sonando ? "󰏤" : "󰐊"
                        font.pixelSize: 20
                        color: Tema.oscuro
                    }
                    MouseArea {
                        id: playRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pagina.reproductor?.togglePlaying()
                    }
                }
                BotonIcono {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: "󰒭"
                    onClic: Reproductor.siguiente(pagina.reproductor)
                }
            }
        }
    }

    // ---------------------------------------------------------- Sonido
    PaginaSonido {
        visible: pagina.cual === "sonido"
        width: parent.width
        altoMax: pagina.altoMax
        activa: pagina.activa && pagina.cual === "sonido"
    }
}
