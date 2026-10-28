// ============================================================================
//  Páginas «red», «bt» y «sonido»: solo lo de la ficha que se pulsó en las
//  islas en píldoras (barra/BarraIslas.qml), como en el dock
//
//    red      [󰖩 Wi-Fi  ●]  y debajo las VPN y las redes (SeccionWifi)
//    bt       [󰂯 Bluetooth ●]  y los dispositivos (SeccionBluetooth)
//    sonido   salidas y micrófonos, con su volumen (SeccionAudio)
//    musica   lo que suena, en pequeño: carátula, canción, progreso y
//             botones (bajo la isla de la música y de su ancho)
//
//  El centro de control entero sigue en la página «control» (ver Paginas.qml)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

Column {
    id: pagina

    property string cual: "red"
    property bool activa: false
    spacing: 10

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var btConectados: Bluetooth.devices.values.filter(d => d.connected)

    // ------------------------------------------------------------- Red
    Baldosa {
        visible: pagina.cual === "red"
        width: parent.width
        conFlecha: false
        icono: Networking.wifiEnabled ? "󰖩" : "󰖪"
        titulo: "Wi-Fi"
        detalle: pagina.redWifi ? pagina.redWifi.name : Networking.wifiEnabled ? "Sin conectar" : "Apagado"
        encendida: Networking.wifiEnabled
        onAlternar: Networking.wifiEnabled = !Networking.wifiEnabled
        onElegir: alternar()
    }
    SeccionWifi {
        visible: pagina.cual === "red"
        width: parent.width
        activa: pagina.activa && pagina.cual === "red"
    }

    // ------------------------------------------------------- Bluetooth
    Baldosa {
        visible: pagina.cual === "bt"
        width: parent.width
        conFlecha: false
        icono: pagina.adaptador?.enabled ? "󰂯" : "󰂲"
        titulo: "Bluetooth"
        detalle: !pagina.adaptador ? "No disponible"
            : !pagina.adaptador.enabled ? "Apagado"
            : pagina.btConectados.length === 1 ? pagina.btConectados[0].name
            : pagina.btConectados.length > 1 ? pagina.btConectados.length + " conectados"
            : "Encendido"
        encendida: pagina.adaptador?.enabled ?? false
        onAlternar: Radios.alternarBluetooth()
        onElegir: alternar()
    }
    SeccionBluetooth {
        visible: pagina.cual === "bt"
        width: parent.width
        activa: pagina.activa && pagina.cual === "bt"
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

    Row {
        visible: pagina.cual === "musica"
        width: parent.width
        spacing: 12
        ClippingRectangle {
            id: caratula
            width: 52; height: 52
            radius: Tema.esquina(10)
            color: Tema.caja
            readonly property string imagen: Reproductor.caratula(pagina.reproductor)
            Texto {
                anchors.centerIn: parent
                visible: caratula.imagen === ""
                text: "󰝚"
                font.pixelSize: 20
            }
            Image {
                anchors.fill: parent
                visible: caratula.imagen !== ""
                source: caratula.imagen
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(104, 104)
                asynchronous: true
            }
        }
        Column {
            width: parent.width - caratula.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Texto {
                width: parent.width
                elide: Text.ElideRight
                text: Reproductor.titulo(pagina.reproductor) || "Sin título"
                color: Tema.blanco
                font.pixelSize: 13
            }
            Texto {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: pagina.reproductor?.trackArtist ?? ""
                font.bold: false
                font.pixelSize: 11
            }
            Texto {
                width: parent.width
                elide: Text.ElideRight
                text: "en " + Reproductor.nombre(pagina.reproductor)
                font.bold: false
                font.pixelSize: 10
                color: Tema.gris
            }
        }
    }

    Column {
        visible: pagina.cual === "musica" && (pagina.reproductor?.length ?? 0) > 0
        width: parent.width
        spacing: 2
        Deslizador {
            width: parent.width
            conOndas: true
            ondas: pagina.activa && (pagina.reproductor?.isPlaying ?? false)
            valor: pagina.reproductor ? pagina.reproductor.position / pagina.reproductor.length : 0
            onMovido: nuevo => {
                if (pagina.reproductor?.canSeek)
                    pagina.reproductor.position = nuevo * pagina.reproductor.length;
            }
        }
        Item {
            width: parent.width
            height: 14
            Texto {
                text: pagina.tiempo(pagina.reproductor?.position ?? 0)
                font.bold: false; font.pixelSize: 10; color: Tema.gris
            }
            Texto {
                anchors.right: parent.right
                text: pagina.tiempo(pagina.reproductor?.length ?? 0)
                font.bold: false; font.pixelSize: 10; color: Tema.gris
            }
        }
    }

    Row {
        visible: pagina.cual === "musica"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        BotonIcono {
            anchors.verticalCenter: parent.verticalCenter
            icono: "󰒮"
            onClic: pagina.reproductor?.previous()
        }
        Rectangle {
            width: 40; height: 40; radius: 20
            color: playRaton.containsMouse ? Tema.blanco : Tema.texto
            Texto {
                anchors.centerIn: parent
                text: pagina.reproductor?.isPlaying ? "󰏤" : "󰐊"
                font.pixelSize: 18
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
            onClic: pagina.reproductor?.next()
        }
    }

    // ---------------------------------------------------------- Sonido
    SeccionAudio {
        visible: pagina.cual === "sonido"
        width: parent.width
        volumen: true
    }
    SeccionAudio {
        visible: pagina.cual === "sonido"
        width: parent.width
        entrada: true
        volumen: true
    }
}
