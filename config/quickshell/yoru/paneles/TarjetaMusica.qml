// ============================================================================
//  TarjetaMusica — la página de la izquierda de la isla (barra/BarraIsla.qml):
//  solo lo que suena, en grande. Sin nada sonando, lo dice.
//
//            ┌────────────────┐
//            │                │
//            │    carátula    │
//            │                │
//            └────────────────┘
//               Whisper My Name
//              Drake · ICEMAN
//                 en Brave
//     0:08 ━━━━━━━━━━━━━○─────────────── 3:42
//             󰒮      ( 󰏤 )      󰒭
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun

Item {
    id: musica

    property var pantalla: null
    // Si se ve (para preguntar la posición solo entonces)
    property bool activa: false
    property color acento: Tema.blanco
    // El tamaño de la isla (Ajustes › Tamaño de la isla)
    property real k: 1
    function m(n) { return Math.round(n * k); }

    readonly property var r: Reproductor.actual
    readonly property bool sonando: r?.isPlaying ?? false
    readonly property real largo: r?.length ?? 0
    readonly property bool conBarra: (r?.canSeek ?? false) && largo > 0
    readonly property real posicion: arrastre.pressed ? arrastre.destino : (r?.position ?? 0)
    function tiempo(s) {
        s = Math.max(0, Math.round(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    // La posición no avisa sola: se pregunta cada segundo mientras suena
    Timer {
        running: musica.activa && musica.sonando
        interval: 1000
        repeat: true
        onTriggered: musica.r?.positionChanged()
    }

    implicitHeight: r ? columna.implicitHeight : nada.implicitHeight

    // ---------------------------------------------------- Nada sonando
    Column {
        id: nada
        visible: !musica.r
        width: parent.width
        topPadding: musica.m(40)
        bottomPadding: musica.m(40)
        spacing: musica.m(8)
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰝛"
            font.pixelSize: musica.m(42)
            color: Tema.gris
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No suena nada"
            font.bold: false
            font.pixelSize: musica.m(13)
            color: Tema.gris
        }
    }

    // ---------------------------------------------------- Lo que suena
    Column {
        id: columna
        visible: musica.r !== null
        width: parent.width
        spacing: musica.m(6)

        // La carátula, grande
        ClippingRectangle {
            id: caratula
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(musica.m(220), parent.width - musica.m(40))
            height: width
            radius: Tema.esquina(18)
            color: Tema.cajaHover
            border.width: 1
            border.color: Tema.claro(0.08)
            // Respira un poco con la música (pausada, algo más pequeña)
            scale: musica.sonando ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Tema.normal * 2; easing.type: Easing.OutCubic } }
            Image {
                id: imagen
                anchors.fill: parent
                source: musica.r ? Reproductor.caratula(musica.r) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(caratula.width * 2, caratula.height * 2)
            }
            Texto {
                visible: imagen.status !== Image.Ready
                anchors.centerIn: parent
                text: "󰎆"
                font.pixelSize: musica.m(56)
                color: Tema.gris
            }
        }

        Item { width: 1; height: musica.m(6) }

        Texto {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Reproductor.titulo(musica.r) || Reproductor.nombre(musica.r)
            textFormat: Text.PlainText
            font.pixelSize: musica.m(18)
            color: Tema.blanco
        }
        Texto {
            width: parent.width
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: [musica.r?.trackArtist ?? "", musica.r?.trackAlbum ?? ""].filter(t => t !== "").join(" · ")
            textFormat: Text.PlainText
            font.bold: false
            font.pixelSize: musica.m(13)
            color: Tema.texto
        }
        Texto {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "en " + Reproductor.nombre(musica.r)
            textFormat: Text.PlainText
            font.bold: false
            font.pixelSize: musica.m(11)
            color: Tema.gris
        }

        Item { width: 1; height: musica.m(4) }

        // La barra para avanzar: se pulsa o se arrastra
        Item {
            visible: musica.conBarra
            width: parent.width
            height: musica.m(22)
            Texto {
                id: tiempoYa
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: musica.m(36)
                text: musica.tiempo(musica.posicion)
                font.bold: false
                font.pixelSize: musica.m(11)
                color: Tema.gris
            }
            Texto {
                id: tiempoTotal
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: musica.m(36)
                horizontalAlignment: Text.AlignRight
                text: musica.tiempo(musica.largo)
                font.bold: false
                font.pixelSize: musica.m(11)
                color: Tema.gris
            }
            Item {
                id: pista
                anchors { left: tiempoYa.right; right: tiempoTotal.left; leftMargin: 6; rightMargin: 6; top: parent.top; bottom: parent.bottom }
                readonly property real fraccion: Math.max(0, Math.min(1, musica.posicion / Math.max(1, musica.largo)))
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: arrastre.containsMouse || arrastre.pressed ? 6 : 4
                    radius: height / 2
                    color: Tema.claro(0.12)
                    Behavior on height { NumberAnimation { duration: Tema.rapida } }
                    Rectangle {
                        width: parent.width * pista.fraccion
                        height: parent.height
                        radius: parent.radius
                        color: musica.acento
                    }
                }
                Rectangle {
                    x: pista.width * pista.fraccion - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: arrastre.containsMouse || arrastre.pressed ? 14 : 10
                    height: width; radius: width / 2
                    color: musica.acento
                }
                MouseArea {
                    id: arrastre
                    property real destino: 0
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function calcular(x) {
                        destino = Math.max(0, Math.min(1, x / Math.max(1, width))) * musica.largo;
                    }
                    onPressed: e => calcular(e.x)
                    onPositionChanged: e => { if (pressed) calcular(e.x); }
                    onReleased: {
                        if (musica.r?.canSeek)
                            musica.r.position = destino;
                    }
                }
            }
        }

        // Anterior · play/pausa (grande, redondo) · siguiente
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: musica.m(28)
            Repeater {
                model: [
                    {icono: "󰒮", grande: false, hacer: () => Reproductor.anterior(musica.r)},
                    {icono: musica.sonando ? "󰏤" : "󰐊", grande: true, hacer: () => musica.r?.togglePlaying()},
                    {icono: "󰒭", grande: false, hacer: () => Reproductor.siguiente(musica.r)}
                ]
                Rectangle {
                    id: mando
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: musica.m(modelData.grande ? 58 : 42)
                    height: width
                    radius: width / 2
                    color: modelData.grande ? (mandoRaton.containsMouse ? Qt.darker(musica.acento, 1.1) : musica.acento)
                        : mandoRaton.containsMouse ? Tema.cajaHover : "transparent"
                    scale: mandoRaton.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    Texto {
                        anchors.centerIn: parent
                        text: mando.modelData.icono
                        font.pixelSize: musica.m(mando.modelData.grande ? 26 : 22)
                        color: mando.modelData.grande ? Tema.oscuro : Tema.texto
                    }
                    MouseArea {
                        id: mandoRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mando.modelData.hacer()
                    }
                }
            }
        }
    }
}
