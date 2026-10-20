// ============================================================================
//  Cerradura — lo que se ve al bloquear la pantalla y al iniciar sesión
//
//                          14:32
//                  martes, 20 de octubre
//
//                           (D)
//                           don
//                  [ ••••••••         ]
//                  Contraseña incorrecta
//                                                    󰁹 80%   (esquina)
//
//  Solo usa QtQuick: no depende del resto de Yoru, para que la pantalla de
//  inicio (system/greetd/yoru/, que corre como otro usuario) use este mismo
//  archivo. Los colores y la letra se le pasan.
// ============================================================================
import QtQuick
import QtQuick.Effects

Item {
    id: cerradura

    // Aspecto. El fondo llega ya desenfocado y oscurecido (wallpaper.sh): así
    // carga al instante. Con desenfocar: true, se desenfoca aquí (más lento)
    property url fondo: ""
    property bool desenfocar: false
    property color colorTexto: "#e5e9f0"
    property color colorGris: "#8a8f98"
    property color colorAcento: "#ffffff"
    property color colorOscuro: "#1a1b1e"
    property color colorRojo: "#bf616a"
    property string fuente: "Noto Sans"

    // Contenido
    property string nombre: ""                // quien entra
    property string pista: "Contraseña"
    property string mensaje: ""
    property bool error: false
    // En rojo hasta que vuelves a escribir (sin tocar «error», que viene de
    // fuera: asignarlo aquí rompería el enlace y el siguiente fallo no se vería)
    readonly property bool enRojo: error && campo.text === ""
    property bool ocupada: false              // comprobando la contraseña
    property alias texto: campo.text
    property alias campo: campo
    default property alias esquina: esquina.data   // abajo a la derecha
    property alias encima: encima.data             // encima del nombre (p. ej. elegir usuario)

    signal enviar(string contrasena)

    function sacudir() {
        sacudida.restart();
    }

    // ------------------------------------------------------------ Fondo
    Rectangle {
        anchors.fill: parent
        color: cerradura.colorOscuro
    }
    Image {
        id: imagen
        anchors.fill: parent
        source: cerradura.fondo
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, width / 2), Math.max(1, height / 2))   // va desenfocado: basta a media resolución
        // Pequeño y ya desenfocado: se carga antes de enseñar la pantalla
        asynchronous: cerradura.desenfocar
        visible: !cerradura.desenfocar
    }
    MultiEffect {
        anchors.fill: parent
        source: imagen
        visible: cerradura.desenfocar && imagen.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        saturation: -0.1
        autoPaddingEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(cerradura.colorOscuro.r, cerradura.colorOscuro.g, cerradura.colorOscuro.b, 0.25)
    }

    // ------------------------------------------------------------ Reloj
    property date ahora: new Date()
    Timer {
        running: cerradura.visible
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: cerradura.ahora = new Date()
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(cerradura.ahora, "HH:mm")
            color: cerradura.colorAcento
            font.family: cerradura.fuente
            font.pixelSize: Math.min(120, cerradura.height / 7)
            font.bold: true
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const t = Qt.locale("es_ES").toString(cerradura.ahora, "dddd, d 'de' MMMM");
                return t.charAt(0).toUpperCase() + t.slice(1);
            }
            color: cerradura.colorTexto
            font.family: cerradura.fuente
            font.pixelSize: 20
        }
    }

    // ------------------------------------------------- Usuario y clave
    Column {
        id: centro
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.52)
        width: 320
        spacing: 14

        Item {
            id: encima
            width: parent.width
            height: childrenRect.height
            visible: children.length > 0
        }

        // Inicial del nombre en un círculo
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76; radius: 38
            color: Qt.rgba(cerradura.colorAcento.r, cerradura.colorAcento.g, cerradura.colorAcento.b, 0.14)
            border.width: 2
            border.color: Qt.rgba(cerradura.colorAcento.r, cerradura.colorAcento.g, cerradura.colorAcento.b, 0.5)
            Text {
                anchors.centerIn: parent
                text: cerradura.nombre.charAt(0).toUpperCase()
                color: cerradura.colorAcento
                font.family: cerradura.fuente
                font.pixelSize: 32
                font.bold: true
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cerradura.nombre
            color: cerradura.colorTexto
            font.family: cerradura.fuente
            font.pixelSize: 18
            font.bold: true
        }

        Rectangle {
            id: caja
            width: parent.width
            height: 48
            radius: 24
            color: Qt.rgba(cerradura.colorOscuro.r, cerradura.colorOscuro.g, cerradura.colorOscuro.b, 0.55)
            border.width: campo.activeFocus ? 2 : 1
            border.color: cerradura.enRojo ? cerradura.colorRojo
                : campo.activeFocus ? Qt.rgba(cerradura.colorAcento.r, cerradura.colorAcento.g, cerradura.colorAcento.b, 0.8)
                : Qt.rgba(cerradura.colorAcento.r, cerradura.colorAcento.g, cerradura.colorAcento.b, 0.2)

            transform: Translate { id: desplazamiento }
            SequentialAnimation {
                id: sacudida
                loops: 1
                NumberAnimation { target: desplazamiento; property: "x"; to: -12; duration: 50 }
                NumberAnimation { target: desplazamiento; property: "x"; to: 12; duration: 70 }
                NumberAnimation { target: desplazamiento; property: "x"; to: -8; duration: 70 }
                NumberAnimation { target: desplazamiento; property: "x"; to: 0; duration: 60 }
            }

            TextInput {
                id: campo
                anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: cerradura.colorTexto
                font.family: cerradura.fuente
                font.pixelSize: 16
                font.letterSpacing: 3
                enabled: !cerradura.ocupada
                focus: true
                clip: true
                // Sin texto, el cursor quedaría encima de la pista («Contra|seña»)
                cursorDelegate: Rectangle {
                    width: 2
                    color: cerradura.colorAcento
                    visible: campo.text !== "" && campo.cursorVisible
                }
                onAccepted: if (text !== "") cerradura.enviar(text)

                Text {
                    anchors.centerIn: parent
                    visible: campo.text === ""
                    text: cerradura.ocupada ? "Comprobando…" : cerradura.pista
                    color: cerradura.colorGris
                    font.family: cerradura.fuente
                    font.pixelSize: 14
                    font.letterSpacing: 0
                }
            }
        }

        Text {
            width: parent.width
            height: 20
            horizontalAlignment: Text.AlignHCenter
            text: cerradura.mensaje
            color: cerradura.enRojo ? cerradura.colorRojo : cerradura.colorGris
            font.family: cerradura.fuente
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    Row {
        id: esquina
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 12
    }
}
