// ============================================================================
//  MusicaBloqueo — lo que suena, en el bloqueo (como el reproductor del
//  iPhone): sobre la carátula desenfocada, la carátula grande, el título,
//  el artista, por dónde va (con los tiempos) y los botones
//
//    ┌──────────────────────────────────────────────┐
//    │ [carátula]  ELISA                            │
//    │             Elegante                         │
//    │             Natos y Waor                     │
//    │  1:23 ━━━━━━━━━━━━━━──────────────── -2:10   │
//    │                 󰒮     󰏤     󰒭                │
//    └──────────────────────────────────────────────┘
//
//  Sin nada sonando (ni en pausa), no sale.
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.comun

ClippingRectangle {
    id: tarjeta

    readonly property var reproductor: Reproductor.actual
    readonly property string titulo: Reproductor.titulo(reproductor)
    readonly property string arte: Reproductor.caratula(reproductor)
    readonly property real largo: reproductor?.length ?? 0
    readonly property real posicion: reproductor?.position ?? 0

    readonly property bool hay: reproductor !== null && titulo !== ""
    visible: hay
    width: 440
    height: 158
    radius: Tema.esquina(24)
    color: Tema.sombra(0.55)
    border.width: 1
    border.color: Tema.claro(0.12)

    // La posición no avisa sola: se pregunta cada segundo mientras suena
    Timer {
        running: tarjeta.visible && (tarjeta.reproductor?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: tarjeta.reproductor.positionChanged()
    }

    function tiempo(s) {
        s = Math.max(0, Math.round(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // De fondo, la propia carátula muy desenfocada y oscurecida
    Image {
        id: fondoArte
        anchors.fill: parent
        visible: false
        source: tarjeta.arte
        sourceSize: Qt.size(120, 120)
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
        brightness: -0.25
        saturation: 0.2
        autoPaddingEnabled: false
        opacity: 0.75
    }

    component Boton: Item {
        id: boton
        property string icono
        property int tam: 22
        property bool grande: false
        signal pulsado()
        width: grande ? 42 : 34
        height: width
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: boton.grande ? Tema.blanco : Tema.claro(zona.containsMouse ? 0.14 : 0)
            scale: zona.pressed ? 0.88 : zona.containsMouse && boton.grande ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
            anchors.centerIn: parent
            text: boton.icono
            font.family: Tema.mono
            font.pixelSize: boton.tam
            color: boton.grande ? Tema.oscuro : Tema.texto
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
    }

    // Carátula con las esquinas redondeadas (o una nota si no la hay)
    ClippingRectangle {
        id: caratula
        x: 14
        y: 14
        width: 70
        height: 70
        radius: Tema.esquina(14)
        color: Tema.claro(0.1)
        Text {
            anchors.centerIn: parent
            visible: imagen.status !== Image.Ready
            text: "󰎈"
            font.family: Tema.mono
            font.pixelSize: 30
            color: Tema.gris
        }
        Image {
            id: imagen
            anchors.fill: parent
            source: tarjeta.arte
            sourceSize: Qt.size(152, 152)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // Late un poco con la música
            scale: tarjeta.reproductor?.isPlaying ? 1 : 0.92
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        }
    }

    Column {
        anchors {
            left: caratula.right; leftMargin: 14
            right: parent.right; rightMargin: 18
            verticalCenter: caratula.verticalCenter
        }
        spacing: 2
        Text {
            width: parent.width
            text: Reproductor.nombre(tarjeta.reproductor).toUpperCase()
            color: Tema.gris
            font.family: Tema.fuente
            font.pixelSize: 10
            font.letterSpacing: 1.4
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: tarjeta.titulo
            color: Tema.texto
            font.family: Tema.fuente
            font.pixelSize: 17
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: tarjeta.reproductor?.trackArtist ?? ""
            color: Tema.texto
            opacity: 0.7
            font.family: Tema.fuente
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    // Por dónde va y los botones
    Item {
        id: progreso
        anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18 }
        y: caratula.y + caratula.height + 8
        height: 14
        visible: tarjeta.largo > 0
        Text {
            id: llevado
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            text: tarjeta.tiempo(tarjeta.posicion)
            color: Tema.gris
            font.family: Tema.fuente
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
        Rectangle {
            anchors { left: llevado.right; right: queda.left; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
            height: 4
            radius: 2
            color: Tema.claro(0.18)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, tarjeta.posicion / Math.max(1, tarjeta.largo)))
                height: parent.height
                radius: parent.radius
                color: Tema.blanco
                Behavior on width { NumberAnimation { duration: 900 } }
            }
        }
        Text {
            id: queda
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 40
            horizontalAlignment: Text.AlignRight
            text: "-" + tarjeta.tiempo(tarjeta.largo - tarjeta.posicion)
            color: Tema.gris
            font.family: Tema.fuente
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        spacing: 26
        Boton {
            visible: tarjeta.reproductor?.canGoPrevious ?? false
            icono: "󰒮"
            onPulsado: tarjeta.reproductor.previous()
        }
        Boton {
            grande: true
            icono: tarjeta.reproductor?.isPlaying ? "󰏤" : "󰐊"
            tam: 22
            onPulsado: tarjeta.reproductor.togglePlaying()
        }
        Boton {
            visible: tarjeta.reproductor?.canGoNext ?? false
            icono: "󰒭"
            onPulsado: tarjeta.reproductor.next()
        }
    }
}
