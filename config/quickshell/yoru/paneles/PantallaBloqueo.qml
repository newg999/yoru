// ============================================================================
//  Lo que se ve en la pantalla de bloqueo (lo usa Bloqueo.qml, una por
//  pantalla): el fondo desenfocado, la hora, la fecha y la contraseña.
//
//                         21:05
//                 lunes, 28 de septiembre
//
//                 ┌──────────────────────┐
//                 │ 󰌾  ••••••••          │
//                 └──────────────────────┘
//                  Contraseña incorrecta
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.comun

Item {
    id: pantalla

    // Estado compartido (Bloqueo.qml)
    required property var bloqueo

    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var dias: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: Tema.oscuro
    }

    // El fondo de pantalla (wallpaper.sh mantiene este enlace), desenfocado
    Image {
        id: fondo
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/fondo-bloqueo"
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(pantalla.width / 2, pantalla.height / 2)
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: fondo
        visible: fondo.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.35
        saturation: -0.3
    }

    // Entrada suave
    opacity: 0
    Component.onCompleted: opacity = 1
    Behavior on opacity { NumberAnimation { duration: Tema.normal } }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 8

        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(reloj.date, "HH:mm")
            font.pixelSize: 120
            color: Tema.blanco
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: pantalla.dias[reloj.date.getDay()] + ", " + reloj.date.getDate() + " de " + pantalla.meses[reloj.date.getMonth()]
            font.bold: false
            font.pixelSize: 20
        }

        Item { width: 1; height: 50 }

        // ------------------------------------------------------ Contraseña
        Rectangle {
            id: campo
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340
            height: 52
            radius: 14
            color: Tema.panel
            border.width: 2
            border.color: pantalla.bloqueo.error !== "" ? Tema.rojo
                : pantalla.bloqueo.comprobando ? Tema.gris : Tema.panelBorde
            Behavior on border.color { ColorAnimation { duration: Tema.rapida } }

            // Sacudida al fallar
            transform: Translate { id: sacudida }
            SequentialAnimation {
                id: temblor
                loops: 2
                NumberAnimation { target: sacudida; property: "x"; to: -10; duration: 40 }
                NumberAnimation { target: sacudida; property: "x"; to: 10; duration: 80 }
                NumberAnimation { target: sacudida; property: "x"; to: 0; duration: 40 }
            }
            Connections {
                target: pantalla.bloqueo
                function onFallo() {
                    temblor.restart();
                    entrada.text = "";
                }
            }

            Texto {
                id: candado
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                text: pantalla.bloqueo.comprobando ? "󰔟" : "󰌾"
                font.pixelSize: 18
                color: Tema.gris
            }
            TextInput {
                id: entrada
                anchors {
                    left: candado.right; leftMargin: 14
                    right: parent.right; rightMargin: 18
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                enabled: !pantalla.bloqueo.comprobando
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Tema.texto
                font.family: Tema.fuente
                font.pixelSize: 18
                font.letterSpacing: 2
                clip: true
                onTextChanged: if (text !== "") pantalla.bloqueo.error = ""
                Keys.onReturnPressed: pantalla.bloqueo.comprobar(text)
                Keys.onEnterPressed: pantalla.bloqueo.comprobar(text)
                Keys.onEscapePressed: text = ""

                Texto {
                    visible: entrada.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: pantalla.bloqueo.comprobando ? "Comprobando…" : "Contraseña de " + Quickshell.env("USER")
                    font.bold: false
                    font.pixelSize: 14
                    color: Tema.gris
                }
            }
        }

        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 24
            text: pantalla.bloqueo.error
            font.bold: false
            font.pixelSize: 13
            color: Tema.rojo
        }
    }

    // Abajo: lo que suena
    Texto {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
        visible: Reproductor.actual !== null && (Reproductor.actual?.trackTitle ?? "") !== ""
        text: (Reproductor.actual?.isPlaying ? "󰝚  " : "󰏤  ") + (Reproductor.actual?.trackTitle ?? "")
            + (Reproductor.actual?.trackArtist ? "  ·  " + Reproductor.actual.trackArtist : "")
        textFormat: Text.PlainText
        font.bold: false
        font.pixelSize: 13
        color: Tema.gris
    }

    // Que la contraseña tenga el foco en cuanto aparece
    function enfocar() {
        entrada.forceActiveFocus();
    }
}
