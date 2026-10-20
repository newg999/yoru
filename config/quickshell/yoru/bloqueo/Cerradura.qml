// ============================================================================
//  Cerradura — lo que se ve al bloquear la pantalla y al iniciar sesión
//
//                                         (arriba: música, clima, red... )
//
//                              22:59
//                    Jueves, 7 de mayo de 2026
//
//              (D)  [ 󰌾  ••••••          󰈈  󰌌  ↵ ]
//                      Contraseña incorrecta
//
//   ⏻                                                  (esquina)
//
//  Solo usa QtQuick: no depende del resto de Yoru, para que la pantalla de
//  inicio (system/greetd/yoru/, que corre como otro usuario) use este mismo
//  archivo. Los colores y la letra se le pasan. Los iconos van dibujados
//  (SVG) y no con la Nerd Font: el usuario de la pantalla de inicio no la ve.
//
//  ⏻ abre Suspender / Reiniciar / Apagar (señal «energia»). 󰈈 enseña lo
//  escrito, 󰌌 cambia la distribución del teclado (señal «cambiarTeclado»).
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
    property string nombre: ""                // quien entra (su inicial, sin foto)
    property var fotos: []                    // posibles fotos (la primera que exista)
    property string pista: "Contraseña"
    property string mensaje: ""
    property bool error: false
    // En rojo hasta que vuelves a escribir (sin tocar «error», que viene de
    // fuera: asignarlo aquí rompería el enlace y el siguiente fallo no se vería)
    readonly property bool enRojo: error && campo.text === ""
    property bool ocupada: false              // comprobando la contraseña
    property string teclado: ""               // distribución («es»), en la ayuda de 󰌌
    property alias texto: campo.text
    property alias campo: campo
    default property alias esquina: esquina.data   // abajo a la derecha
    property alias encima: encima.data             // encima de la contraseña (p. ej. elegir usuario)
    property alias arriba: arriba.data             // arriba a la derecha (estado del equipo)

    signal enviar(string contrasena)
    signal energia(string accion)             // "suspend" · "reboot" · "poweroff"
    signal cambiarTeclado()

    function sacudir() {
        sacudida.restart();
    }

    function conAlfa(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Iconos de Material Design Icons (Apache 2.0), de 24x24
    readonly property var trazos: ({
        candado: "M12,17A2,2 0 0,0 14,15C14,13.89 13.1,13 12,13A2,2 0 0,0 10,15A2,2 0 0,0 12,17M18,8A2,2 0 0,1 20,10V20A2,2 0 0,1 18,22H6A2,2 0 0,1 4,20V10C4,8.89 4.9,8 6,8H7V6A5,5 0 0,1 12,1A5,5 0 0,1 17,6V8H18M12,3A3,3 0 0,0 9,6V8H15V6A3,3 0 0,0 12,3Z",
        ojo: "M12,9A3,3 0 0,0 9,12A3,3 0 0,0 12,15A3,3 0 0,0 15,12A3,3 0 0,0 12,9M12,17A5,5 0 0,1 7,12A5,5 0 0,1 12,7A5,5 0 0,1 17,12A5,5 0 0,1 12,17M12,4.5C7,4.5 2.73,7.61 1,12C2.73,16.39 7,19.5 12,19.5C17,19.5 21.27,16.39 23,12C21.27,7.61 17,4.5 12,4.5Z",
        ojoTachado: "M11.83,9L15,12.16C15,12.11 15,12.05 15,12A3,3 0 0,0 12,9C11.94,9 11.89,9 11.83,9M7.53,9.8L9.08,11.35C9.03,11.56 9,11.77 9,12A3,3 0 0,0 12,15C12.22,15 12.44,14.97 12.65,14.92L14.2,16.47C13.53,16.8 12.79,17 12,17A5,5 0 0,1 7,12C7,11.21 7.2,10.47 7.53,9.8M2,4.27L4.28,6.55L4.73,7C3.08,8.3 1.78,10 1,12C2.73,16.39 7,19.5 12,19.5C13.55,19.5 15.03,19.2 16.38,18.66L16.81,19.08L19.73,22L21,20.73L3.27,3M12,7A5,5 0 0,1 17,12C17,12.64 16.87,13.26 16.64,13.82L19.57,16.75C21.07,15.5 22.27,13.86 23,12C21.27,7.61 17,4.5 12,4.5C10.6,4.5 9.26,4.75 8,5.2L10.17,7.35C10.74,7.13 11.35,7 12,7Z",
        teclado: "M19,10H17V8H19M19,13H17V11H19M16,10H14V8H16M16,13H14V11H16M16,17H8V15H16M7,10H5V8H7M7,13H5V11H7M8,11H10V13H8M8,8H10V10H8M11,11H13V13H11M11,8H13V10H11M20,5H4C2.89,5 2,5.89 2,7V17A2,2 0 0,0 4,19H20A2,2 0 0,0 22,17V7C22,5.89 21.1,5 20,5Z",
        intro: "M19,7V11H5.83L9.41,7.41L8,6L2,12L8,18L9.41,16.58L5.83,13H21V7H19Z",
        energia: "M16.56,5.44L15.11,6.89C16.84,7.94 18,9.83 18,12A6,6 0 0,1 12,18A6,6 0 0,1 6,12C6,9.83 7.16,7.94 8.88,6.88L7.44,5.44C5.36,6.88 4,9.28 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12C20,9.28 18.64,6.88 16.56,5.44M13,3H11V13H13",
        luna: "M17.75,4.09L15.22,6.03L16.13,9.09L13.5,7.28L10.87,9.09L11.78,6.03L9.25,4.09L12.44,4L13.5,1L14.56,4L17.75,4.09M21.25,11L19.61,12.25L20.2,14.23L18.5,13.06L16.8,14.23L17.39,12.25L15.75,11L17.81,10.95L18.5,9L19.19,10.95L21.25,11M18.97,15.95C19.8,15.87 20.69,17.05 20.16,17.8C19.84,18.25 19.5,18.67 19.08,19.07C15.17,23 8.84,23 4.94,19.07C1.03,15.17 1.03,8.83 4.94,4.93C5.34,4.53 5.76,4.17 6.21,3.85C6.96,3.32 8.14,4.21 8.06,5.04C7.79,7.9 8.75,10.87 10.95,13.06C13.14,15.26 16.1,16.22 18.97,15.95Z",
        reiniciar: "M12,4C14.1,4 16.1,4.8 17.6,6.3C20.7,9.4 20.7,14.5 17.6,17.6C15.8,19.5 13.3,20.2 10.9,19.9L11.4,17.9C13.1,18.1 14.9,17.5 16.2,16.2C18.5,13.9 18.5,10.1 16.2,7.7C15.1,6.6 13.5,6 12,6V10.6L7,5.6L12,0.6V4M6.3,17.6C3.7,15 3.3,11 5.1,7.9L6.6,9.4C5.5,11.6 5.9,14.4 7.8,16.2C8.3,16.7 8.9,17.1 9.6,17.4L9,19.4C8,19 7.1,18.4 6.3,17.6Z"
    })

    component Icono: Image {
        property string trazo
        property color tinta: cerradura.colorTexto
        width: 18
        height: 18
        sourceSize: Qt.size(width * 2, height * 2)
        source: "data:image/svg+xml;utf8," + encodeURIComponent(
            `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="${Qt.rgba(tinta.r, tinta.g, tinta.b, 1)}" d="${trazo}"/></svg>`)
    }

    // Botón redondo con un icono (los de la contraseña y el de apagar)
    component BotonIcono: Item {
        id: boton
        property string trazo
        property color tinta: cerradura.colorGris
        property int tam: 18
        signal pulsado()
        width: tam + 12
        height: tam + 12
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: cerradura.conAlfa(cerradura.colorAcento, zona.containsMouse ? 0.12 : 0)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Icono {
            anchors.centerIn: parent
            width: boton.tam
            height: boton.tam
            trazo: boton.trazo
            tinta: zona.containsMouse ? cerradura.colorTexto : boton.tinta
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
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
    // Bastante oscuro: el fondo apenas se intuye y el texto se lee siempre
    Rectangle {
        anchors.fill: parent
        color: cerradura.conAlfa(cerradura.colorOscuro, 0.55)
    }

    // Un clic en cualquier sitio vuelve a la contraseña (y cierra el menú)
    MouseArea {
        anchors.fill: parent
        onClicked: {
            menu.visible = false;
            campo.forceActiveFocus();
        }
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
        id: reloj
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: centro.top
        anchors.bottomMargin: 22
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(cerradura.ahora, "HH:mm")
            color: cerradura.colorAcento
            font.family: cerradura.fuente
            font.pixelSize: Math.round(Math.min(112, cerradura.height / 8))
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const t = Qt.locale("es_ES").toString(cerradura.ahora, "dddd, d 'de' MMMM 'de' yyyy");
                return t.charAt(0).toUpperCase() + t.slice(1);
            }
            color: cerradura.colorTexto
            font.family: cerradura.fuente
            font.pixelSize: 18
        }
    }

    // ------------------------------------------------- Foto y contraseña
    Column {
        id: centro
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.5 - fila.height / 2)
        spacing: 10

        Item {
            id: encima
            anchors.horizontalCenter: parent.horizontalCenter
            width: childrenRect.width
            height: childrenRect.height
            visible: children.length > 0
        }

        Row {
            id: fila
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            // Foto (~/.face o la de AccountsService) o la inicial en un círculo
            Item {
                id: avatar
                width: 52
                height: 52
                anchors.verticalCenter: parent.verticalCenter
                property int cual: 0
                readonly property bool conFoto: foto.status === Image.Ready

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: !avatar.conFoto
                    color: cerradura.conAlfa(cerradura.colorAcento, 0.12)
                    border.width: 1
                    border.color: cerradura.conAlfa(cerradura.colorAcento, 0.35)
                    Text {
                        anchors.centerIn: parent
                        text: cerradura.nombre.charAt(0).toUpperCase()
                        color: cerradura.colorAcento
                        font.family: cerradura.fuente
                        font.pixelSize: 22
                        font.bold: true
                    }
                }
                Image {
                    id: foto
                    anchors.fill: parent
                    visible: false
                    source: cerradura.fotos[avatar.cual] ?? ""
                    sourceSize: Qt.size(104, 104)
                    fillMode: Image.PreserveAspectCrop
                    // Si no existe, la siguiente de la lista
                    onStatusChanged: if (status === Image.Error && avatar.cual < cerradura.fotos.length - 1)
                        avatar.cual++
                }
                Rectangle {
                    id: mascara
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    visible: avatar.conFoto
                    source: foto
                    maskEnabled: true
                    maskSource: mascara
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            Rectangle {
                id: caja
                width: 300
                height: 52
                radius: 12
                color: cerradura.conAlfa(cerradura.colorOscuro, 0.6)
                border.width: 2
                border.color: cerradura.enRojo ? cerradura.colorRojo
                    : campo.activeFocus ? cerradura.conAlfa(cerradura.colorAcento, 0.85)
                    : cerradura.conAlfa(cerradura.colorAcento, 0.2)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                transform: Translate { id: desplazamiento }
                SequentialAnimation {
                    id: sacudida
                    NumberAnimation { target: desplazamiento; property: "x"; to: -12; duration: 50 }
                    NumberAnimation { target: desplazamiento; property: "x"; to: 12; duration: 70 }
                    NumberAnimation { target: desplazamiento; property: "x"; to: -8; duration: 70 }
                    NumberAnimation { target: desplazamiento; property: "x"; to: 0; duration: 60 }
                }

                Icono {
                    id: candado
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    trazo: cerradura.trazos.candado
                    tinta: cerradura.enRojo ? cerradura.colorRojo : cerradura.colorGris
                }

                TextInput {
                    id: campo
                    property bool ver: false
                    anchors {
                        left: candado.right; leftMargin: 12
                        right: botones.left; rightMargin: 6
                        top: parent.top; bottom: parent.bottom
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: ver ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    color: cerradura.colorTexto
                    selectionColor: cerradura.conAlfa(cerradura.colorAcento, 0.35)
                    font.family: cerradura.fuente
                    font.pixelSize: 15
                    font.letterSpacing: ver ? 0 : 2
                    enabled: !cerradura.ocupada
                    focus: true
                    clip: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: cerradura.colorAcento
                        visible: campo.cursorVisible
                    }
                    onAccepted: if (text !== "") cerradura.enviar(text)
                    // Esc: cierra el menú de apagar, o borra lo escrito
                    Keys.onEscapePressed: menu.visible ? menu.visible = false : campo.clear()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 4
                        visible: campo.text === ""
                        text: cerradura.ocupada ? "Comprobando…" : cerradura.pista
                        color: cerradura.colorGris
                        font.family: cerradura.fuente
                        font.pixelSize: 14
                    }
                }

                Row {
                    id: botones
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 0

                    BotonIcono {
                        trazo: campo.ver ? cerradura.trazos.ojoTachado : cerradura.trazos.ojo
                        onPulsado: {
                            campo.ver = !campo.ver;
                            campo.forceActiveFocus();
                        }
                    }
                    BotonIcono {
                        trazo: cerradura.trazos.teclado
                        onPulsado: {
                            cerradura.cambiarTeclado();
                            campo.forceActiveFocus();
                        }
                        Text {
                            // La distribución, pequeñita en la esquina del icono
                            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 1; bottomMargin: 1 }
                            visible: cerradura.teclado !== ""
                            text: cerradura.teclado
                            color: cerradura.colorGris
                            font.family: cerradura.fuente
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }
                    BotonIcono {
                        trazo: cerradura.trazos.intro
                        tinta: campo.text !== "" ? cerradura.colorTexto : cerradura.colorGris
                        onPulsado: campo.accepted()
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: (avatar.width + fila.spacing) / 2   // bajo la contraseña
            width: caja.width
            height: 18
            horizontalAlignment: Text.AlignHCenter
            text: cerradura.mensaje
            color: cerradura.enRojo ? cerradura.colorRojo : cerradura.colorGris
            font.family: cerradura.fuente
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    // ------------------------------------------------------- Arriba y esquina
    Row {
        id: arriba
        anchors { right: parent.right; top: parent.top; margins: 22 }
        spacing: 18
    }

    Row {
        id: esquina
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 12
    }

    // --------------------------------------------- Apagar (abajo a la izquierda)
    BotonIcono {
        id: botonEnergia
        anchors { left: parent.left; bottom: parent.bottom; margins: 22 }
        trazo: cerradura.trazos.energia
        tam: 20
        onPulsado: menu.visible = !menu.visible
    }

    Rectangle {
        id: menu
        visible: false
        anchors { left: botonEnergia.left; bottom: botonEnergia.top; bottomMargin: 8 }
        width: 170
        height: opciones.height + 12
        radius: 12
        color: cerradura.conAlfa(cerradura.colorOscuro, 0.92)
        border.width: 1
        border.color: cerradura.conAlfa(cerradura.colorAcento, 0.15)

        Column {
            id: opciones
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

            Repeater {
                model: [
                    {texto: "Suspender", accion: "suspend", trazo: cerradura.trazos.luna},
                    {texto: "Reiniciar", accion: "reboot", trazo: cerradura.trazos.reiniciar},
                    {texto: "Apagar", accion: "poweroff", trazo: cerradura.trazos.energia}
                ]
                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 36
                    radius: 8
                    color: cerradura.conAlfa(cerradura.colorAcento, opcion.containsMouse ? 0.1 : 0)
                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Icono {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            trazo: modelData.trazo
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.texto
                            color: cerradura.colorTexto
                            font.family: cerradura.fuente
                            font.pixelSize: 14
                        }
                    }
                    MouseArea {
                        id: opcion
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menu.visible = false;
                            cerradura.energia(modelData.accion);
                        }
                    }
                }
            }
        }
    }
}
