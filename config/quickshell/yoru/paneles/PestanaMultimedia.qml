// ============================================================================
//  Pestaña Multimedia del panel central: lo que se está escuchando, en grande
//
//    ┌────────────────────────────────────────────┐
//    │   (carátula desenfocada de fondo)     [󰝚] │  elegir reproductor
//    │              ( carátula )             [󰓃] │  salida de audio
//    │         Canción · Artista · Álbum     [󰕾] │  volumen del reproductor
//    │   ━━━━━━━━━━━━○────────────────────        │
//    │         󰒟   󰒮   ( 󰏤 )   󰒭   󰑖          │  aleatorio · repetir
//    └────────────────────────────────────────────┘
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.comun

Item {
    id: multimedia

    property bool activa: false
    readonly property var reproductor: Reproductor.actual
    property string menu: ""          // "" · "reproductores" · "salidas" · "volumen"
    onActivaChanged: menu = ""

    implicitHeight: 420

    // Mpris no avisa de la posición: se pregunta cada segundo mientras se ve
    Timer {
        running: multimedia.activa && (multimedia.reproductor?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: multimedia.reproductor.positionChanged()
    }

    function tiempo(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), seg = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${seg}` : `${m}:${seg}`;
    }

    ClippingRectangle {
        id: fondo
        anchors.fill: parent
        radius: 12
        color: Tema.caja

        // Carátula desenfocada y oscurecida detrás de todo
        Image {
            id: fondoImagen
            anchors.fill: parent
            source: multimedia.reproductor?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(256, 256)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: fondoImagen
            visible: fondoImagen.status === Image.Ready
            blurEnabled: true
            blurMax: 64
            blur: 1
            brightness: -0.35
            saturation: 0.1
            opacity: 0.8
        }

        // ------------------------------------------------ Nada sonando
        Column {
            visible: !multimedia.reproductor
            anchors.centerIn: parent
            spacing: 10
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰝛"
                font.pixelSize: 56
                color: Tema.tenue
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No suena nada"
                font.bold: false
                color: Tema.gris
            }
        }

        // ------------------------------------------------ Reproductor
        Column {
            visible: multimedia.reproductor !== null
            anchors { left: parent.left; right: parent.right; leftMargin: 80; rightMargin: 80; verticalCenter: parent.verticalCenter }
            spacing: 14

            // Carátula redonda; gira despacio mientras suena
            ClippingRectangle {
                id: disco
                anchors.horizontalCenter: parent.horizontalCenter
                width: 170; height: 170
                radius: 85
                color: Tema.claro(0.08)
                border.width: 3
                border.color: Tema.claro(0.6)
                // Suavizado: sin esto el borde se ve dentado al girar
                layer.enabled: true
                layer.smooth: true
                layer.samples: 8

                Image {
                    id: caratula
                    anchors.fill: parent
                    source: multimedia.reproductor?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(340, 340)
                }
                Texto {
                    anchors.centerIn: parent
                    visible: caratula.status !== Image.Ready
                    text: "󰝚"
                    font.pixelSize: 60
                    color: Tema.tenue
                }

                RotationAnimation on rotation {
                    running: multimedia.activa && (multimedia.reproductor?.isPlaying ?? false)
                    loops: Animation.Infinite
                    from: disco.rotation; to: disco.rotation + 360
                    duration: 24000
                }
            }

            Column {
                width: parent.width
                spacing: 3
                Texto {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Reproductor.titulo(multimedia.reproductor) || "Sin título"
                    elide: Text.ElideRight
                    font.pixelSize: 16
                    color: Tema.blanco
                }
                Texto {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: [multimedia.reproductor?.trackArtist, multimedia.reproductor?.trackAlbum]
                        .filter(t => t).join(" · ")
                    elide: Text.ElideRight
                    font.bold: false
                    font.pixelSize: 12
                    color: Tema.texto
                }
                Texto {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "en " + Reproductor.nombre(multimedia.reproductor)
                    font.bold: false
                    font.pixelSize: 10
                    color: Tema.gris
                }
            }

            // Progreso
            Column {
                width: parent.width
                spacing: 2
                visible: (multimedia.reproductor?.length ?? 0) > 0

                Deslizador {
                    width: parent.width
                    valor: multimedia.reproductor ? multimedia.reproductor.position / multimedia.reproductor.length : 0
                    onMovido: nuevo => {
                        if (multimedia.reproductor?.canSeek)
                            multimedia.reproductor.position = nuevo * multimedia.reproductor.length;
                    }
                }
                Item {
                    width: parent.width
                    height: 14
                    Texto {
                        text: multimedia.tiempo(multimedia.reproductor?.position ?? 0)
                        font.bold: false; font.pixelSize: 11; color: Tema.gris
                    }
                    Texto {
                        anchors.right: parent.right
                        text: multimedia.tiempo(multimedia.reproductor?.length ?? 0)
                        font.bold: false; font.pixelSize: 11; color: Tema.gris
                    }
                }
            }

            // Botones
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                BotonIcono {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: multimedia.reproductor?.shuffleSupported ?? false
                    icono: "󰒟"
                    colorIcono: multimedia.reproductor?.shuffle ? Tema.blanco : Tema.tenue
                    onClic: multimedia.reproductor.shuffle = !multimedia.reproductor.shuffle
                }
                BotonIcono {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 38
                    icono: "󰒮"
                    onClic: multimedia.reproductor.previous()
                }
                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: playRaton.containsMouse ? Tema.blanco : Tema.texto
                    scale: playRaton.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.rapida } }
                    Texto {
                        anchors.centerIn: parent
                        text: multimedia.reproductor?.isPlaying ? "󰏤" : "󰐊"
                        font.pixelSize: 28
                        color: Tema.oscuro
                    }
                    MouseArea {
                        id: playRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: multimedia.reproductor.togglePlaying()
                    }
                }
                BotonIcono {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 38
                    icono: "󰒭"
                    onClic: multimedia.reproductor.next()
                }
                BotonIcono {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: multimedia.reproductor?.loopSupported ?? false
                    readonly property int estado: multimedia.reproductor?.loopState ?? MprisLoopState.None
                    icono: estado === MprisLoopState.Track ? "󰑘" : "󰑖"
                    colorIcono: estado === MprisLoopState.None ? Tema.tenue : Tema.blanco
                    // Sin repetir → repetir la lista → repetir la canción → sin repetir
                    onClic: multimedia.reproductor.loopState =
                        estado === MprisLoopState.None ? MprisLoopState.Playlist
                        : estado === MprisLoopState.Playlist ? MprisLoopState.Track
                        : MprisLoopState.None
                }
            }
        }

        // ------------------------------------------ Botones de la derecha
        Column {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 10

            Repeater {
                model: [
                    {id: "reproductores", icono: "󰝚"},
                    {id: "salidas", icono: "󰓃"},
                    {id: "volumen", icono: "󰕾"}
                ]
                Rectangle {
                    id: lateral
                    required property var modelData
                    readonly property bool elegido: multimedia.menu === modelData.id
                    width: 40; height: 40; radius: 20
                    color: elegido ? Tema.blanco : lateralRaton.containsMouse ? Tema.claro(0.18) : Tema.claro(0.08)
                    border.width: 1
                    border.color: Tema.claro(0.15)
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    Texto {
                        anchors.centerIn: parent
                        text: lateral.modelData.icono
                        font.pixelSize: 16
                        color: lateral.elegido ? Tema.oscuro : Tema.texto
                    }
                    MouseArea {
                        id: lateralRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: multimedia.menu = lateral.elegido ? "" : lateral.modelData.id
                    }
                }
            }
        }

        // ------------------------------------ Menú flotante de esos botones
        Rectangle {
            id: menuFlotante
            visible: opacity > 0
            opacity: multimedia.menu !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
            anchors { right: parent.right; rightMargin: 66; verticalCenter: parent.verticalCenter }
            width: 300
            height: contenidoMenu.implicitHeight + 16
            radius: 12
            color: Tema.panel
            border.width: 1
            border.color: Tema.claro(0.25)

            // Los clics dentro no cierran nada
            MouseArea { anchors.fill: parent }

            Column {
                id: contenidoMenu
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                spacing: 2

                // Reproductores abiertos
                Repeater {
                    model: multimedia.menu === "reproductores" ? Reproductor.todos : []
                    Fila {
                        required property var modelData
                        width: contenidoMenu.width
                        icono: modelData.isPlaying ? "󰏤" : "󰐊"
                        titulo: Reproductor.nombre(modelData)
                        detalle: Reproductor.titulo(modelData)
                        seleccionada: modelData === multimedia.reproductor
                        onClic: {
                            Reproductor.elegido = modelData;
                            multimedia.menu = "";
                        }
                    }
                }

                // Salidas de audio
                Repeater {
                    model: multimedia.menu === "salidas"
                        ? Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream) : []
                    Fila {
                        required property var modelData
                        width: contenidoMenu.width
                        icono: "󰓃"
                        titulo: modelData.description || modelData.nickname || modelData.name
                        seleccionada: Pipewire.defaultAudioSink === modelData
                        onClic: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }

                // Volumen: el del reproductor si lo permite; si no, el general
                FilaVolumen {
                    visible: multimedia.menu === "volumen" && !(multimedia.reproductor?.volumeSupported ?? false)
                    width: contenidoMenu.width
                    nodo: Pipewire.defaultAudioSink
                    onElegir: multimedia.menu = "salidas"
                }
                Item {
                    visible: multimedia.menu === "volumen" && (multimedia.reproductor?.volumeSupported ?? false)
                    width: contenidoMenu.width
                    height: 40
                    Texto {
                        id: iconoVolumen
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "󰝚"
                        font.pixelSize: 16
                    }
                    Deslizador {
                        anchors {
                            left: iconoVolumen.right; leftMargin: 12
                            right: porcentaje.left; rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        valor: multimedia.reproductor?.volume ?? 0
                        onMovido: nuevo => multimedia.reproductor.volume = nuevo
                    }
                    Texto {
                        id: porcentaje
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: Math.round((multimedia.reproductor?.volume ?? 0) * 100) + "%"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
