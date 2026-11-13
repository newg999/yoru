// ============================================================================
//  Cerradura — lo que se ve al bloquear la pantalla y al iniciar sesión
//  Estilo «Noche» (Yoru, 夜): el fondo casi nítido moviéndose despacio, un
//  cielo de estrellas que titilan (y alguna fugaz) y todo fino y centrado
//
//      ·        ✦          ·            ·              (arriba: red, volumen...)
//           ·            ·        ✦
//                       夜                  ← marca de agua, detrás de la hora
//                     16:29                 ← fina; los dos puntos laten
//                  ───────────
//          MARTES · 10 DE NOVIEMBRE · 14°
//
//          [ la música ]   [ las notificaciones ]
//
//                      (D)
//                      don
//            󰌾                       󰈈 󰌌 →   ← un punto por letra
//            ──────═══▓▓█▓▓═══──────────   ← la luz crece con cada letra,
//                                              y cada tecla lanza destellos
//   ⏻                Contraseña incorrecta              (esquina)
//
//  Mientras no tocas nada, abajo solo pone «Escribe para desbloquear»; al
//  escribir o mover el ratón sube tu foto, tu nombre y la contraseña (y se
//  vuelve a esconder si pasa un rato sin escribir nada; esconderContrasena:
//  false la deja siempre a la vista).
//
//  Animaciones (animar: false las quita, y el cielo se queda quieto): al
//  bloquear el fondo se acerca y cada parte entra por turno; cada tecla
//  lanza dos destellos por la raya (y laten mientras comprueba la
//  contraseña); al fallar la raya se pone roja y
//  tiembla; al acertar, salir() abre el candado, todo sube y se funde, y
//  avisa con la señal fuera() (entonces se desbloquea).
//
//  Solo usa QtQuick: no depende del resto de Yoru, para que la pantalla de
//  inicio (system/greetd/yoru/, que corre como otro usuario) use este mismo
//  archivo. Los colores y la letra se le pasan. Los iconos van dibujados
//  (SVG) y no con la Nerd Font: el usuario de la pantalla de inicio no la ve.
//  El 夜 solo sale si hay letra japonesa (google-noto-serif-cjk-vf-fonts).
//
//  ⏻ abre Suspender / Reiniciar / Apagar (señal «energia»). 󰈈 enseña lo
//  escrito, 󰌌 cambia la distribución del teclado (señal «cambiarTeclado»;
//  solo sale si hay más de una).
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
    property bool animar: true

    // Contenido
    property string nombre: ""                // quien entra (su inicial, sin foto)
    property var fotos: []                    // posibles fotos (la primera que exista)
    property string pista: "Contraseña"
    property string mensaje: ""
    property bool error: false
    // En rojo hasta que vuelves a escribir (sin tocar «error», que viene de
    // fuera: asignarlo aquí rompería el enlace y el siguiente fallo no se vería)
    // (y nunca mientras comprueba o se abre)
    readonly property bool enRojo: error && campo.text === "" && !ocupada && !abierto
    property bool ocupada: false              // comprobando la contraseña
    property string teclado: ""               // distribución («ES»); vacío = sin botón 󰌌
    property alias texto: campo.text
    property alias campo: campo
    default property alias esquina: esquina.data   // abajo a la derecha
    property alias encima: encima.data             // en lugar del nombre (p. ej. elegir usuario)
    property alias arriba: arriba.data             // arriba a la derecha (estado del equipo)
    property alias widgets: widgets.data           // bajo la hora (el tiempo, la batería...)
    property alias abajo: abajo.data               // entre la hora y la contraseña (música, avisos)
    readonly property alias altoAbajo: abajo.height // lo que cabe ahí
    property string detalle: ""                    // junto a la fecha
    property bool esconderContrasena: true

    // ¿Se ve la caja de la contraseña? Al escribir, al mover el ratón, al
    // fallar...; y se esconde tras un rato sin nada escrito
    property bool despierta: !esconderContrasena
    function despertar() {
        despierta = true;
        dormir.restart();
    }
    Timer {
        id: dormir
        interval: 15000
        onTriggered: if (cerradura.esconderContrasena && campo.text === "" && !cerradura.ocupada && !menu.abierto)
            cerradura.despierta = false
    }
    onErrorChanged: if (error) despertar()
    onMensajeChanged: if (mensaje !== "") despertar()

    signal enviar(string contrasena)
    signal energia(string accion)             // "suspend" · "reboot" · "poweroff"
    signal cambiarTeclado()
    signal fuera()                            // salir() ha terminado: ya se puede desbloquear
    signal toque()                            // un clic fuera de todo (cierra lo que esté abierto)

    function sacudir() {
        sacudida.restart();
    }

    // Contraseña buena: el candado se abre, todo sube y se funde
    property bool abierto: false
    function salir() {
        abierto = true;
        menu.abierto = false;
        if (animar)
            salida.start();
        else
            fuera();
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
        candadoAbierto: "M18,8A2,2 0 0,1 20,10V20A2,2 0 0,1 18,22H6C4.89,22 4,21.1 4,20V10A2,2 0 0,1 6,8H15V6A3,3 0 0,0 12,3A3,3 0 0,0 9,6H7A5,5 0 0,1 12,1A5,5 0 0,1 17,6V8H18M12,17A2,2 0 0,0 14,15A2,2 0 0,0 12,13A2,2 0 0,0 10,15A2,2 0 0,0 12,17Z",
        flecha: "M4,11V13H16L10.5,18.5L11.92,19.92L19.84,12L11.92,4.08L10.5,5.5L16,11H4Z",
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
            color: cerradura.conAlfa(cerradura.colorAcento, zona.containsMouse ? 0.14 : 0)
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

    // ------------------------------------------------------- Animaciones
    // Cuánto ha entrado cada parte (0 → 1, una detrás de otra) y cuánto se
    // ha ido todo al desbloquear (0 → 1)
    property real pFondo: animar ? 0 : 1
    property real pCabeza: animar ? 0 : 1
    property real pWidgets: animar ? 0 : 1
    property real pAbajo: animar ? 0 : 1
    property real pAcceso: animar ? 0 : 1
    property real pSalida: 0
    Component.onCompleted: if (animar) entrada.start()

    component Paso: SequentialAnimation {
        id: paso
        property string que
        property int espera: 0
        property int dura: 900
        PauseAnimation { duration: paso.espera }
        NumberAnimation { target: cerradura; property: paso.que; from: 0; to: 1; duration: paso.dura; easing.type: Easing.OutQuint }
    }
    ParallelAnimation {
        id: entrada
        Paso { que: "pFondo"; dura: 1100 }
        Paso { que: "pCabeza"; espera: 120; dura: 1000 }
        Paso { que: "pWidgets"; espera: 200 }
        Paso { que: "pAbajo"; espera: 260 }
        Paso { que: "pAcceso"; espera: 320 }
    }
    SequentialAnimation {
        id: salida
        PauseAnimation { duration: 220 }        // el candado se abre
        NumberAnimation { target: cerradura; property: "pSalida"; to: 1; duration: 600; easing.type: Easing.InOutSine }
        ScriptAction { script: cerradura.fuera() }
    }

    // Al salir, primero se funde lo de encima y después el fondo (los dos a
    // la vez se veía brusco)
    readonly property real fuera1: Math.min(1, pSalida / 0.65)
    readonly property real fuera2: Math.max(0, (pSalida - 0.3) / 0.7)
    readonly property real queda: 1 - fuera1

    // Cada parte: se funde y se mueve un poquito al entrar; al salir, sube
    // apenas
    component Entra: Translate {
        property real paso: 1
        property real desde: 10
        y: (1 - paso) * desde - cerradura.fuera1 * 18
    }

    // Las cifras de la hora: finas y pegadas (sin el aire de encima y debajo)
    component Cifra: Text {
        color: cerradura.colorTexto
        font.family: cerradura.fuente
        font.pixelSize: cabeza.tam
        font.weight: Font.ExtraLight
        font.features: { "tnum": 1 }
        height: Math.round(cabeza.tam * 0.9)
        verticalAlignment: Text.AlignVCenter
    }

    // ------------------------------------------------------------ Fondo
    // El fondo, apenas desenfocado, se mueve muy despacio (como si
    // respirara); encima, un velo de noche más fuerte arriba y abajo
    Rectangle {
        anchors.fill: parent
        color: cerradura.colorOscuro
        opacity: 1 - cerradura.fuera2
    }
    Item {
        id: capaFondo
        anchors.fill: parent
        clip: true
        // Se acerca al bloquear y se aleja un poco al desbloquear
        opacity: cerradura.pFondo * (1 - cerradura.fuera2)
        scale: 1.03 - 0.03 * cerradura.pFondo + 0.015 * cerradura.fuera2

        Item {
            id: deriva
            // Algo más grande que la pantalla, para moverse sin enseñar el borde.
            // Recorre un ocho tumbado: una vuelta cada dos minutos
            property real fase: 0
            width: parent.width * 1.06
            height: parent.height * 1.06
            x: -parent.width * 0.03 + Math.sin(fase) * parent.width * 0.024
            y: -parent.height * 0.03 + Math.sin(2 * fase) * parent.height * 0.022
            NumberAnimation on fase {
                running: cerradura.animar && cerradura.visible
                from: 0
                to: 2 * Math.PI
                duration: 120000
                loops: Animation.Infinite
            }

            Image {
                id: imagen
                anchors.fill: parent
                source: cerradura.fondo
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
                // Ya desenfocado: se carga antes de enseñar la pantalla
                asynchronous: cerradura.desenfocar
                visible: !cerradura.desenfocar
            }
            MultiEffect {
                anchors.fill: parent
                source: imagen
                visible: cerradura.desenfocar && imagen.status === Image.Ready
                blurEnabled: true
                blur: 0.5
                blurMax: 32
                autoPaddingEnabled: false
            }
        }
        Rectangle {
            anchors.fill: parent
            color: cerradura.conAlfa(cerradura.colorOscuro, 0.22)
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: cerradura.conAlfa(cerradura.colorOscuro, 0.78) }
                GradientStop { position: 0.42; color: cerradura.conAlfa(cerradura.colorOscuro, 0.12) }
                GradientStop { position: 0.62; color: cerradura.conAlfa(cerradura.colorOscuro, 0.12) }
                GradientStop { position: 1; color: cerradura.conAlfa(cerradura.colorOscuro, 0.8) }
            }
        }
    }

    // ------------------------------------------------------- El cielo
    // Estrellas que titilan (más arriba que abajo) y, de vez en cuando, una
    // estrella fugaz. Sin animaciones, quietas
    Item {
        id: cielo
        anchors.fill: parent
        opacity: cerradura.pFondo * cerradura.queda

        Repeater {
            model: 90
            Item {
                id: estrella
                required property int index
                // Unas pocas, más grandes y con halo
                readonly property bool grande: index < 6
                readonly property real fx: Math.random()
                readonly property real fy: Math.pow(Math.random(), 1.7) * 0.62
                readonly property real brillo: grande ? 0.9 : 0.2 + Math.random() * 0.55
                readonly property real tam: grande ? 2.6 : (Math.random() < 0.8 ? 1.4 : 2)
                x: Math.round(fx * cielo.width)
                y: Math.round(fy * cielo.height)
                width: 0
                height: 0
                // Se apagan al bajar, para no ensuciar la contraseña
                opacity: brillo * Math.min(1, (0.66 - fy) / 0.25)

                Rectangle {
                    visible: estrella.grande
                    anchors.centerIn: parent
                    width: 11
                    height: 11
                    radius: width / 2
                    color: cerradura.conAlfa(cerradura.colorAcento, 0.16)
                }
                Rectangle {
                    id: punto
                    anchors.centerIn: parent
                    width: estrella.tam
                    height: estrella.tam
                    radius: width / 2
                    color: estrella.grande ? cerradura.colorAcento : cerradura.colorTexto
                    SequentialAnimation on opacity {
                        running: cerradura.animar && cerradura.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: Math.random() * 4000 }
                        NumberAnimation { to: 0.2; duration: 1400 + Math.random() * 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1400 + Math.random() * 2600; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // La estrella fugaz: cruza en diagonal hacia abajo a la izquierda
        Item {
            id: fugaz
            property real p: 0
            property real sx: 0
            property real sy: 0
            readonly property real angulo: 152
            readonly property real recorrido: Math.min(420, cielo.width * 0.3)
            x: sx + Math.cos(angulo * Math.PI / 180) * recorrido * p
            y: sy + Math.sin(angulo * Math.PI / 180) * recorrido * p
            width: 0
            height: 0
            rotation: angulo
            visible: p > 0 && p < 1
            opacity: Math.sin(p * Math.PI)
            Rectangle {
                x: -width
                y: -height / 2
                width: 130
                height: 1.6
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: cerradura.colorTexto }
                }
            }
            NumberAnimation on p {
                id: cruzar
                running: false
                from: 0
                to: 1
                duration: 1100
                easing.type: Easing.OutCubic
            }
        }
        Timer {
            running: cerradura.animar && cerradura.visible && cerradura.queda > 0
            repeat: true
            interval: 9000
            onTriggered: {
                interval = 9000 + Math.random() * 16000;   // la próxima, cuando sea
                fugaz.sx = cielo.width * (0.35 + Math.random() * 0.6);
                fugaz.sy = cielo.height * (0.02 + Math.random() * 0.22);
                cruzar.restart();
            }
        }
    }

    // Un clic en cualquier sitio vuelve a la contraseña (y cierra el menú);
    // mover el ratón la enseña
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: cerradura.despertar()
        onClicked: {
            menu.abierto = false;
            cerradura.toque();
            cerradura.despertar();
            campo.forceActiveFocus();
        }
    }

    // ------------------------------------------------ 夜, la hora y la fecha
    property date ahora: new Date()
    Timer {
        running: cerradura.visible
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: cerradura.ahora = new Date()
    }

    // El kanji de Yoru («noche»), si hay letra japonesa en el sistema
    readonly property string fuenteKanji: {
        const hay = Qt.fontFamilies();
        for (const f of ["Noto Serif CJK JP", "Noto Sans CJK JP", "Source Han Serif JP"])
            if (hay.indexOf(f) >= 0)
                return f;
        return "";
    }

    Column {
        id: cabeza
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(cerradura.height * 0.1)
        spacing: 0
        opacity: cerradura.pCabeza * cerradura.queda
        transform: Entra { paso: cerradura.pCabeza; desde: -12 }

        readonly property int tam: Math.round(Math.min(cerradura.height * 0.2, cerradura.width * 0.14))

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: hora.width
            height: hora.height

            // Detrás de la hora, enorme y casi transparente
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.round(cabeza.tam * 0.02)
                visible: cerradura.fuenteKanji !== ""
                text: "夜"
                color: cerradura.colorAcento
                opacity: 0.075
                font.family: cerradura.fuenteKanji
                font.pixelSize: Math.round(cabeza.tam * 1.75)
                font.weight: Font.Bold
            }

            // Fina, y los dos puntos laten con los segundos
            Row {
                id: hora
                Cifra { text: Qt.formatTime(cerradura.ahora, "HH") }
                Cifra {
                    text: ":"
                    opacity: !cerradura.animar || cerradura.ahora.getSeconds() % 2 === 0 ? 1 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutSine } }
                    transform: Translate { y: -Math.round(cabeza.tam * 0.04) }
                }
                Cifra { text: Qt.formatTime(cerradura.ahora, "mm") }
            }
        }
        Item { width: 1; height: Math.round(cerradura.height * 0.018) }

        // Una raya de luz que se apaga por los lados
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(hora.width * 0.62)
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: cerradura.conAlfa(cerradura.colorAcento, 0.7) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Item { width: 1; height: Math.round(cerradura.height * 0.018) }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const t = Qt.locale("es_ES").toString(cerradura.ahora, "dddd  ·  d 'de' MMMM");
                return (t + (cerradura.detalle ? "  ·  " + cerradura.detalle : "")).toUpperCase();
            }
            color: cerradura.colorTexto
            opacity: 0.85
            font.family: cerradura.fuente
            font.pixelSize: cerradura.tamFecha
            font.weight: Font.Medium
            font.letterSpacing: Math.round(cerradura.tamFecha * 0.22)
        }
        Item { width: 1; height: Math.round(cerradura.height * 0.02) }

        // Bajo la fecha: los widgets
        Row {
            id: widgets
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            opacity: cerradura.pWidgets
            transform: Entra { paso: cerradura.pWidgets; desde: 8 }
        }
    }

    readonly property int tamFecha: Math.round(Math.max(12, height * 0.017))

    // ----------------------------------------- Entre la hora y la contraseña
    Item {
        id: abajo
        anchors {
            left: parent.left; right: parent.right
            top: cabeza.bottom; topMargin: Math.round(cerradura.height * 0.04)
            bottom: acceso.top; bottomMargin: Math.round(cerradura.height * 0.03)
        }
        opacity: cerradura.pAbajo * cerradura.queda
        transform: Entra { paso: cerradura.pAbajo; desde: 12 }
    }

    // ------------------------------------------ Quién entra y contraseña
    // Mientras duerme, solo la pista; al despertar sube todo
    // Lo que queda por debajo de la contraseña: ni pegada al borde ni en medio
    readonly property int margenAcceso: Math.round(height * 0.11)
    readonly property real pDespierta: despierta ? 1 : 0
    property real verAcceso: pDespierta
    Behavior on verAcceso { NumberAnimation { duration: cerradura.animar ? 520 : 0; easing.type: Easing.OutQuint } }

    readonly property int anchoCampo: 340

    // Dormida: la pista, que respira, sobre la raya donde irá la contraseña
    Column {
        id: pistaDormida
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: cerradura.margenAcceso + 22
        spacing: 12
        opacity: (1 - cerradura.verAcceso) * cerradura.pAcceso * cerradura.queda
        visible: opacity > 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ESCRIBE PARA DESBLOQUEAR"
            color: cerradura.colorTexto
            font.family: cerradura.fuente
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 3
            SequentialAnimation on opacity {
                running: pistaDormida.visible && cerradura.animar
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.95; duration: 1800; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 140
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: cerradura.conAlfa(cerradura.colorAcento, 0.45) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // Detrás de la foto y la contraseña, una sombra muy difuminada: así se
    // leen bien sobre cualquier fondo, también uno claro
    Item {
        anchors.centerIn: acceso
        width: acceso.width + 200
        height: acceso.height + 120
        opacity: acceso.opacity
        Rectangle {
            id: charco
            anchors.fill: parent
            anchors.margins: 50
            radius: height / 2
            color: cerradura.colorOscuro
            visible: false
        }
        MultiEffect {
            anchors.fill: charco
            source: charco
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            opacity: 0.6
        }
    }

    Column {
        id: acceso
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: cerradura.margenAcceso
        width: cerradura.anchoCampo
        spacing: 10
        opacity: cerradura.verAcceso * cerradura.pAcceso * cerradura.queda
        transform: Entra { paso: Math.min(cerradura.verAcceso, cerradura.pAcceso); desde: 14 }

        // La foto, con un aro de luz, y el nombre debajo
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            // Foto (~/.face o la de AccountsService) o la inicial en un círculo
            Item {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 68
                height: 68
                property int cual: 0
                readonly property bool conFoto: foto.status === Image.Ready

                // Un aro de luz alrededor, que brilla más al escribir
                Rectangle {
                    id: aro
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: cerradura.enRojo ? cerradura.colorRojo : cerradura.colorAcento
                    opacity: campo.text !== "" || cerradura.enRojo ? 0.9 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: aro.border.color
                        shadowBlur: 0.8
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        blurMax: 20
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: !avatar.conFoto
                    color: cerradura.conAlfa(cerradura.colorAcento, 0.16)
                    Text {
                        anchors.centerIn: parent
                        text: cerradura.nombre.charAt(0).toUpperCase()
                        color: cerradura.colorTexto
                        font.family: cerradura.fuente
                        font.pixelSize: 28
                        font.weight: Font.Light
                    }
                }
                Image {
                    id: foto
                    anchors.fill: parent
                    visible: false
                    source: cerradura.fotos[avatar.cual] ?? ""
                    sourceSize: Qt.size(136, 136)
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

            // El nombre (o lo que ponga la pantalla de inicio: elegir usuario)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: encima.children.length === 0
                text: cerradura.nombre
                color: cerradura.colorTexto
                font.family: cerradura.fuente
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Item {
                id: encima
                anchors.horizontalCenter: parent.horizontalCenter
                width: childrenRect.width
                height: childrenRect.height
                visible: children.length > 0
            }
        }

        Item { width: 1; height: 4 }

        // La contraseña: sin caja, solo una raya que se enciende al escribir
        Item {
            id: caja
            width: cerradura.anchoCampo
            height: 46

            transform: Translate { id: desplazamiento }
            SequentialAnimation {
                id: sacudida
                NumberAnimation { target: desplazamiento; property: "x"; to: -9; duration: 60 }
                NumberAnimation { target: desplazamiento; property: "x"; to: 8; duration: 80 }
                NumberAnimation { target: desplazamiento; property: "x"; to: -5; duration: 80 }
                NumberAnimation { target: desplazamiento; property: "x"; to: 3; duration: 70 }
                NumberAnimation { target: desplazamiento; property: "x"; to: 0; duration: 60 }
            }

            // El candado: late mientras comprueba, se pone rojo al fallar y
            // se abre al acertar
            Item {
                id: candado
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                width: 20
                height: 20
                Icono {
                    id: iconoCandado
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    trazo: cerradura.abierto ? cerradura.trazos.candadoAbierto : cerradura.trazos.candado
                    tinta: cerradura.enRojo ? cerradura.colorRojo
                        : campo.text !== "" || cerradura.abierto ? cerradura.colorAcento : cerradura.colorGris
                    SequentialAnimation on opacity {
                        running: cerradura.ocupada && cerradura.animar
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
                // Al abrirse, un saltito
                Connections {
                    target: cerradura
                    function onAbiertoChanged() {
                        if (cerradura.abierto && cerradura.animar)
                            salto.restart();
                    }
                }
                SequentialAnimation {
                    id: salto
                    NumberAnimation { target: candado; property: "scale"; to: 1.25; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: candado; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutCubic }
                }
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
                horizontalAlignment: ver ? TextInput.AlignHCenter : TextInput.AlignLeft
                echoMode: ver ? TextInput.Normal : TextInput.Password
                // Lo escrito no se ve: en su lugar, los puntos (más abajo)
                color: ver ? cerradura.colorTexto : "transparent"
                selectionColor: cerradura.conAlfa(cerradura.colorAcento, 0.35)
                selectedTextColor: color
                font.family: cerradura.fuente
                font.pixelSize: 16
                font.letterSpacing: 1
                enabled: !cerradura.ocupada
                focus: true
                clip: true
                cursorDelegate: Rectangle {
                    width: 1.5
                    color: cerradura.colorAcento
                    // Sin escribir no hace falta: la raya encendida ya dice que está lista
                    visible: campo.cursorVisible && campo.ver
                }
                // Cualquier tecla la enseña (también las que no escriben)
                Keys.onPressed: cerradura.despertar()
                onTextChanged: cerradura.despertar()
                onAccepted: if (text !== "") cerradura.enviar(text)
                // Esc: cierra lo abierto (menú de apagar, avisos) y borra lo escrito
                Keys.onEscapePressed: {
                    cerradura.toque();
                    menu.abierto ? menu.abierto = false : campo.clear();
                }

                // Centrados en la raya (no en el campo, que tiene el candado
                // a un lado y los botones al otro)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(caja.width / 2 - campo.x - width / 2)
                    visible: campo.text === ""
                    text: cerradura.ocupada ? "Comprobando…" : cerradura.pista
                    color: cerradura.colorGris
                    font.family: cerradura.fuente
                    font.pixelSize: 15
                    font.letterSpacing: 0.5
                }

                // Un punto por letra (centrados en la raya, como la pista):
                // sin ellos no se sabía si faltaba o sobraba algo. Cada uno
                // entra creciendo y se encoge al borrarlo; si no caben, se
                // juntan y se hacen más pequeños
                Row {
                    id: puntos
                    readonly property int n: campo.ver ? 0 : campo.text.length
                    readonly property real tam: Math.max(4, Math.min(8, campo.width / Math.max(1, n) * 0.5))
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(caja.width / 2 - campo.x - width / 2)
                    spacing: tam * 0.9
                    Repeater {
                        // Fijos y reutilizados: así solo se anima el que entra o sale
                        model: 64
                        Rectangle {
                            id: punto
                            required property int index
                            readonly property bool puesto: index < puntos.n
                            width: puntos.tam
                            height: width
                            radius: width / 2
                            color: cerradura.enRojo ? cerradura.colorRojo : cerradura.colorTexto
                            scale: puesto ? 1 : 0
                            visible: puesto || scale > 0.01
                            Behavior on scale {
                                NumberAnimation {
                                    duration: cerradura.animar ? (punto.puesto ? 260 : 140) : 0
                                    easing.type: punto.puesto ? Easing.OutBack : Easing.InCubic
                                    easing.overshoot: 2.2
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: botones
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 0

                BotonIcono {
                    trazo: campo.ver ? cerradura.trazos.ojoTachado : cerradura.trazos.ojo
                    tam: 16
                    onPulsado: {
                        campo.ver = !campo.ver;
                        campo.forceActiveFocus();
                    }
                }
                BotonIcono {
                    // Solo con más de una distribución: con una no hay a qué cambiar
                    visible: cerradura.teclado !== ""
                    trazo: cerradura.trazos.teclado
                    tam: 16
                    onPulsado: {
                        cerradura.cambiarTeclado();
                        campo.forceActiveFocus();
                    }
                    Text {
                        // La distribución, pequeñita en la esquina del icono
                        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 1; bottomMargin: 1 }
                        text: cerradura.teclado
                        color: cerradura.colorGris
                        font.family: cerradura.fuente
                        font.pixelSize: 8
                        font.bold: true
                    }
                }
                // Enviar: la flecha se enciende en cuanto hay algo escrito
                BotonIcono {
                    trazo: cerradura.trazos.flecha
                    tam: 18
                    tinta: campo.text !== "" ? cerradura.colorAcento : cerradura.colorGris
                    onPulsado: campo.accepted()
                }
            }

            // La raya: de fondo, tenue; encima, la luz, que crece desde el
            // centro al escribir y brilla
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: cerradura.conAlfa(cerradura.colorAcento, 0.32)
            }
            Rectangle {
                id: luz
                anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.bottom }
                height: 2.5
                radius: 1.25
                // Con foco, 40 %; cada letra la alarga hasta llenar la raya
                // (con 10 letras); al fallar, entera y roja
                width: parent.width * (cerradura.enRojo ? 1
                    : campo.text !== "" ? Math.min(1, 0.4 + campo.text.length * 0.06)
                    : campo.activeFocus ? 0.4 : 0)
                Behavior on width { NumberAnimation { duration: cerradura.animar ? 520 : 0; easing.type: Easing.OutQuint } }
                readonly property color tono: cerradura.enRojo ? cerradura.colorRojo : cerradura.colorAcento
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: cerradura.conAlfa(luz.tono, 0) }
                    GradientStop { position: 0.2; color: luz.tono }
                    GradientStop { position: 0.8; color: luz.tono }
                    GradientStop { position: 1; color: cerradura.conAlfa(luz.tono, 0) }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: luz.tono
                    shadowBlur: 1.0
                    shadowOpacity: 0.9
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 24
                }
            }

            // Los destellos: cada tecla lanza dos, desde el centro hacia los
            // lados, que recorren la raya y se apagan. Mientras comprueba la
            // contraseña, salen solos, como un latido
            Item {
                id: destellos
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.bottom }
                height: 10
                visible: cerradura.animar
                property int siguiente: 0
                function lanzar() {
                    const d = chispas.itemAt(siguiente);
                    siguiente = (siguiente + 1) % chispas.count;
                    d?.lanzar();
                }
                Connections {
                    target: campo
                    property int antes: 0
                    function onTextChanged() {
                        if (campo.text.length > antes)
                            destellos.lanzar();
                        antes = campo.text.length;
                    }
                }
                Timer {
                    running: cerradura.ocupada && destellos.visible
                    interval: 520
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: destellos.lanzar()
                }

                // Unos pocos que se reutilizan (escribiendo deprisa, se solapan)
                Repeater {
                    id: chispas
                    model: 6
                    Item {
                        id: chispa
                        anchors.fill: parent
                        property real p: 1
                        function lanzar() { recorre.restart(); }
                        NumberAnimation on p {
                            id: recorre
                            running: false
                            from: 0
                            to: 1
                            duration: 700
                            easing.type: Easing.OutCubic
                        }
                        visible: p < 1
                        opacity: 1 - p * p

                        // Una a cada lado, la mitad de la raya de recorrido
                        Repeater {
                            model: [-1, 1]
                            Rectangle {
                                required property int modelData
                                width: 46
                                height: 3
                                radius: 1.5
                                y: (parent.height - height) / 2
                                x: (destellos.width - width) / 2 + modelData * chispa.p * (destellos.width - width) / 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.lighter(luz.tono, 1.5) }
                                    GradientStop { position: 1; color: "transparent" }
                                }
                            }
                        }
                    }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: luz.tono
                    shadowBlur: 0.8
                    shadowOpacity: 1
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 20
                }
            }
        }

        Text {
            width: caja.width
            height: 16
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
        opacity: cerradura.pCabeza * cerradura.queda
    }

    Row {
        id: esquina
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 12
        opacity: cerradura.pAcceso * cerradura.queda
    }

    // --------------------------------------------- Apagar (abajo a la izquierda)
    BotonIcono {
        id: botonEnergia
        anchors { left: parent.left; bottom: parent.bottom; margins: 22 }
        trazo: cerradura.trazos.energia
        tam: 20
        opacity: cerradura.pAcceso * cerradura.queda
        onPulsado: menu.abierto = !menu.abierto
    }

    Rectangle {
        id: menu
        property bool abierto: false
        visible: opacity > 0
        opacity: abierto ? 1 : 0
        scale: abierto ? 1 : 0.97
        transformOrigin: Item.BottomLeft
        Behavior on opacity { NumberAnimation { duration: cerradura.animar ? 200 : 0; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: cerradura.animar ? 260 : 0; easing.type: Easing.OutQuint } }
        anchors { left: botonEnergia.left; bottom: botonEnergia.top; bottomMargin: 8 }
        width: 170
        height: opciones.height + 12
        radius: 14
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
                    radius: 9
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
                            menu.abierto = false;
                            cerradura.energia(modelData.accion);
                        }
                    }
                }
            }
        }
    }
}
