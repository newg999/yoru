// ============================================================================
//  MusicaBloqueo — la tarjeta de lo que suena, bajo la hora del bloqueo
//
//    ┌──────────────────────────────────────────┐
//    │ [carátula]  Elegante                     │
//    │             Natos y Waor     󰒮  󰏤  󰒭    │
//    │             ━━━━━━━━━━━━━──────────      │
//    └──────────────────────────────────────────┘
//
//  Sin nada sonando (ni en pausa), no sale.
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.comun

Rectangle {
    id: tarjeta

    readonly property var reproductor: Reproductor.actual
    readonly property string titulo: Reproductor.titulo(reproductor)

    visible: reproductor !== null && titulo !== ""
    width: 460
    height: 104
    radius: Tema.esquina(20)
    color: Qt.rgba(Tema.oscuro.r, Tema.oscuro.g, Tema.oscuro.b, 0.55)
    border.width: 1
    border.color: Tema.claro(0.1)

    // La posición no avisa sola: se pregunta cada segundo mientras suena
    Timer {
        running: tarjeta.visible && (tarjeta.reproductor?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: tarjeta.reproductor.positionChanged()
    }

    component Boton: Texto {
        id: boton
        signal pulsado()
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 20
        color: zona.containsMouse ? Tema.blanco : Tema.texto
        MouseArea {
            id: zona
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
    }

    // Carátula con las esquinas redondeadas (o una nota si no la hay)
    Item {
        id: caratula
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
        width: 76
        height: 76
        readonly property bool conImagen: imagen.status === Image.Ready

        Rectangle {
            anchors.fill: parent
            radius: Tema.esquina(12)
            color: Tema.claro(0.08)
            visible: !caratula.conImagen
            Texto {
                anchors.centerIn: parent
                text: "󰎈"
                font.pixelSize: 30
                color: Tema.gris
            }
        }
        Image {
            id: imagen
            anchors.fill: parent
            visible: false
            source: Reproductor.caratula(tarjeta.reproductor)
            sourceSize: Qt.size(152, 152)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            id: mascara
            anchors.fill: parent
            radius: Tema.esquina(12)
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: caratula.conImagen
            source: imagen
            maskEnabled: true
            maskSource: mascara
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Column {
        anchors {
            left: caratula.right; leftMargin: 16
            right: parent.right; rightMargin: 18
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        Texto {
            width: parent.width
            text: tarjeta.titulo
            font.pixelSize: 16
            font.bold: true
            color: Tema.texto
            elide: Text.ElideRight
        }
        Item {
            width: parent.width
            height: 28

            Texto {
                anchors { left: parent.left; right: controles.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: tarjeta.reproductor?.trackArtist ?? ""
                font.pixelSize: 13
                font.bold: false
                color: Tema.gris
                elide: Text.ElideRight
            }
            Row {
                id: controles
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 18
                Boton {
                    visible: tarjeta.reproductor?.canGoPrevious ?? false
                    text: "󰒮"
                    onPulsado: tarjeta.reproductor.previous()
                }
                Boton {
                    text: tarjeta.reproductor?.isPlaying ? "󰏤" : "󰐊"
                    font.pixelSize: 24
                    color: Tema.blanco
                    onPulsado: tarjeta.reproductor.togglePlaying()
                }
                Boton {
                    visible: tarjeta.reproductor?.canGoNext ?? false
                    text: "󰒭"
                    onPulsado: tarjeta.reproductor.next()
                }
            }
        }
        // Por dónde va
        Rectangle {
            visible: (tarjeta.reproductor?.length ?? 0) > 0
            width: parent.width
            height: 3
            radius: 1.5
            color: Tema.claro(0.15)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, (tarjeta.reproductor?.position ?? 0) / Math.max(1, tarjeta.reproductor?.length ?? 1)))
                height: parent.height
                radius: parent.radius
                color: Tema.blanco
            }
        }
    }
}
