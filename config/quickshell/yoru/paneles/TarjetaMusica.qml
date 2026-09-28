// ============================================================================
//  Lo que suena: carátula, canción, barra de progreso y botones.
//  Clic en la barra de progreso = saltar a ese punto (si el reproductor deja).
// ============================================================================
import QtQuick
import Quickshell.Widgets
import qs.comun

Tarjeta {
    id: tarjeta

    property bool activa: true       // el panel está abierto (si no, no se refresca)

    readonly property var reproductor: Reproductor.actual
    signal ampliar()     // clic en la carátula = pestaña Multimedia

    // Mpris no avisa de la posición: se pregunta cada segundo mientras se ve
    Timer {
        running: tarjeta.activa && (tarjeta.reproductor?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: tarjeta.reproductor.positionChanged()
    }

    function tiempo(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // Sin nada sonando
    Column {
        visible: !tarjeta.reproductor
        anchors.centerIn: parent
        spacing: 8
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰝛"
            font.pixelSize: 36
            color: Tema.tenue
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No suena nada"
            font.bold: false
            font.pixelSize: 12
            color: Tema.gris
        }
    }

    Column {
        visible: tarjeta.reproductor !== null
        anchors { fill: parent; margins: 16 }
        spacing: 10

        // Carátula redonda (o una nota si no tiene)
        Item {
            width: parent.width
            height: 110

            ClippingRectangle {
                anchors.centerIn: parent
                width: 104; height: 104
                radius: 52
                color: Tema.claro(0.08)
                border.width: 2
                border.color: Tema.claro(0.5)

                Image {
                    id: caratula
                    anchors.fill: parent
                    source: tarjeta.reproductor?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(208, 208)
                }
                Texto {
                    anchors.centerIn: parent
                    visible: caratula.status !== Image.Ready
                    text: "󰝚"
                    font.pixelSize: 36
                    color: Tema.tenue
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tarjeta.ampliar()
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2
            Texto {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tarjeta.reproductor?.trackTitle || "Sin título"
                elide: Text.ElideRight
                font.pixelSize: 13
                color: Tema.blanco
            }
            Texto {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tarjeta.reproductor?.trackArtist || tarjeta.reproductor?.identity || ""
                elide: Text.ElideRight
                font.bold: false
                font.pixelSize: 11
                color: Tema.gris
            }
        }

        // Progreso
        Column {
            width: parent.width
            spacing: 2
            visible: (tarjeta.reproductor?.length ?? 0) > 0

            Deslizador {
                width: parent.width
                implicitHeight: 16
                valor: tarjeta.reproductor ? tarjeta.reproductor.position / tarjeta.reproductor.length : 0
                onMovido: nuevo => {
                    if (tarjeta.reproductor?.canSeek)
                        tarjeta.reproductor.position = nuevo * tarjeta.reproductor.length;
                }
            }
            Item {
                width: parent.width
                height: 14
                Texto {
                    text: tarjeta.tiempo(tarjeta.reproductor?.position ?? 0)
                    font.bold: false; font.pixelSize: 10; color: Tema.gris
                }
                Texto {
                    anchors.right: parent.right
                    text: tarjeta.tiempo(tarjeta.reproductor?.length ?? 0)
                    font.bold: false; font.pixelSize: 10; color: Tema.gris
                }
            }
        }

        // Botones
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            BotonIcono {
                anchors.verticalCenter: parent.verticalCenter
                icono: "󰒮"
                onClic: tarjeta.reproductor.previous()
            }
            Rectangle {
                width: 44; height: 44; radius: 22
                color: playRaton.containsMouse ? Tema.blanco : Tema.texto
                scale: playRaton.pressed ? 0.92 : 1
                Behavior on scale { NumberAnimation { duration: Tema.rapida } }
                Texto {
                    anchors.centerIn: parent
                    text: tarjeta.reproductor?.isPlaying ? "󰏤" : "󰐊"
                    font.pixelSize: 22
                    color: Tema.oscuro
                }
                MouseArea {
                    id: playRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tarjeta.reproductor.togglePlaying()
                }
            }
            BotonIcono {
                anchors.verticalCenter: parent.verticalCenter
                icono: "󰒭"
                onClic: tarjeta.reproductor.next()
            }
        }
    }
}
