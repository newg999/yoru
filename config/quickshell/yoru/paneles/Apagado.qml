// ============================================================================
//  Apagado — el menú de sesión, a pantalla completa (Mod+Shift+BackSpace)
//
//  Sobre tu fondo desenfocado (como el bloqueo), tu foto, un saludo y cinco
//  botones redondos:
//
//                         (D)
//                Hasta luego, don
//           encendido hace 13 h 20 min
//
//     ( 󰌾 )   ( 󰤄 )   ( 󰍃 )   ( 󰜉 )   ( 󰐥 )
//   Bloquear Suspender  Cerrar  Reiniciar Apagar
//      [B]      [S]      [C]      [R]      [A]
//
//    ← → para moverte · Enter para elegir · o la letra · Esc o clic fuera
//    para cerrar
//
//  Cerrar sesión, reiniciar y apagar no van al instante: el aro del botón
//  se llena en 3 s («Apagando en 3…») y hasta entonces se puede cancelar
//  (Esc, un clic o moverse); Enter otra vez (o la letra) lo hace ya.
//
//  Para añadir opciones: una línea en «opciones» de comun/Sesion.qml.
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.comun

PanelWindow {
    id: panel

    required property ShellScreen modelData
    readonly property bool abierto: Paneles.abierto === "apagado" && Paneles.pantalla === modelData

    // 0 = cerrado · 1 = abierto. La ventana sigue hasta que acaba de irse
    property real progreso: abierto ? 1 : 0
    Behavior on progreso {
        NumberAnimation { duration: Tema.normal * 1.6; easing.type: Easing.OutCubic }
    }

    screen: modelData
    visible: abierto || progreso > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-apagado"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var opciones: Sesion.opciones
    readonly property string casa: Quickshell.env("HOME")
    readonly property string usuario: Quickshell.env("USER") ?? ""
    property int elegida: 0

    // La que espera para hacerse (cerrar sesión, reiniciar, apagar), y cuánto
    // le falta (0 → 1 en 3 s)
    property var pendiente: null
    property real cuenta: 0
    readonly property int segundos: Math.max(1, Math.ceil(3 * (1 - cuenta)))
    NumberAnimation {
        id: contar
        target: panel
        property: "cuenta"
        from: 0
        to: 1
        duration: 3000
        onFinished: if (panel.pendiente) panel.hacer(panel.pendiente)
    }
    function cancelar() {
        contar.stop();
        pendiente = null;
        cuenta = 0;
    }

    onAbiertoChanged: {
        cancelar();
        if (abierto) {
            elegida = 0;
            Sesion.leerEncendido();
            teclas.forceActiveFocus();
        }
    }

    function elegir(opcion) {
        if (!opcion)
            return;
        elegida = opciones.indexOf(opcion);
        // Las que no tienen vuelta atrás esperan 3 s; si ya estaba
        // esperando, se hace ya
        if (opcion.peligrosa && pendiente !== opcion && Ajustes.animaciones) {
            pendiente = opcion;
            contar.restart();
            return;
        }
        hacer(opcion);
    }
    function hacer(opcion) {
        cancelar();
        Sesion.elegir(opcion);
    }
    function mover(paso) {
        cancelar();
        elegida = (elegida + paso + opciones.length) % opciones.length;
    }

    // ---------------------------------------------------- Fondo de detrás
    // Tu fondo, desenfocado (el mismo que usa el bloqueo, aún más borroso),
    // y un velo de noche
    Item {
        anchors.fill: parent
        opacity: panel.progreso

        Rectangle {
            anchors.fill: parent
            color: Tema.oscuro
        }
        Image {
            id: imagen
            anchors.fill: parent
            source: "file://" + panel.casa + "/.cache/fondo-bloqueo-borroso.jpg"
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(960, 540)
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: imagen
            visible: imagen.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: -0.1
            autoPaddingEnabled: false
            // Se acerca un poco al abrirse
            scale: 1.04 - 0.04 * panel.progreso
        }
        Rectangle {
            anchors.fill: parent
            color: Tema.sombra(0.45)
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.sombra(0.4) }
                GradientStop { position: 0.5; color: Tema.sombra(0) }
                GradientStop { position: 1; color: Tema.sombra(0.6) }
            }
        }
        // Un clic fuera de todo: cancela lo que esperaba o cierra
        MouseArea {
            anchors.fill: parent
            onClicked: panel.pendiente ? panel.cancelar() : Paneles.cerrar()
        }
    }

    // Las teclas
    Item {
        id: teclas
        focus: true
        Keys.onLeftPressed: panel.mover(-1)
        Keys.onRightPressed: panel.mover(1)
        Keys.onTabPressed: panel.mover(1)
        Keys.onBacktabPressed: panel.mover(-1)
        Keys.onReturnPressed: panel.elegir(panel.opciones[panel.elegida])
        Keys.onEnterPressed: panel.elegir(panel.opciones[panel.elegida])
        Keys.onSpacePressed: panel.elegir(panel.opciones[panel.elegida])
        Keys.onEscapePressed: panel.pendiente ? panel.cancelar() : Paneles.cerrar()
        Keys.onPressed: event => {
            const o = panel.opciones.find(o => o.tecla === event.text.toLowerCase());
            if (o) {
                panel.elegir(o);
                event.accepted = true;
            }
        }
    }

    // ------------------------------------------------------------ Lo de delante
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(panel.modelData.height * 0.03)
        spacing: 0
        opacity: panel.progreso
        transform: Translate { y: (1 - panel.progreso) * 24 }

        // Tu foto (o tu inicial)
        Item {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76
            property int cual: 0
            readonly property var fotos: ["file://" + panel.casa + "/.face",
                                          "file:///var/lib/AccountsService/icons/" + panel.usuario]
            readonly property bool conFoto: foto.status === Image.Ready
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 8; height: width
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: Tema.claro(0.45)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: !avatar.conFoto
                color: Tema.claro(0.16)
                Text {
                    anchors.centerIn: parent
                    text: panel.usuario.charAt(0).toUpperCase()
                    color: Tema.texto
                    font.family: Tema.fuente
                    font.pixelSize: 32
                    font.weight: Font.Light
                }
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                visible: avatar.conFoto
                color: "transparent"
                Image {
                    id: foto
                    anchors.fill: parent
                    source: avatar.fotos[avatar.cual] ?? ""
                    sourceSize: Qt.size(152, 152)
                    fillMode: Image.PreserveAspectCrop
                    onStatusChanged: if (status === Image.Error && avatar.cual < avatar.fotos.length - 1)
                        avatar.cual++
                }
            }
        }
        Item { width: 1; height: 18 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Hasta luego, " + panel.usuario
            color: Tema.texto
            font.family: Tema.fuente
            font.pixelSize: 28
            font.weight: Font.Light
        }
        Item { width: 1; height: 6 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (Sesion.encendido ? "ENCENDIDO HACE " + Sesion.encendido : " ").toUpperCase()
            color: Tema.gris
            font.family: Tema.fuente
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 2
        }
        Item { width: 1; height: 44 }

        // Los botones
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 26

            Repeater {
                model: panel.opciones
                Column {
                    id: opcion
                    required property var modelData
                    required property int index
                    readonly property bool elegida: panel.elegida === index
                    readonly property bool esperando: panel.pendiente === modelData
                    // Las que no tienen vuelta atrás, en rojo al elegirlas
                    readonly property color tono: modelData.peligrosa && elegida ? Tema.rojo : Tema.blanco
                    spacing: 12

                    // Entran una detrás de otra, subiendo un poco
                    opacity: 0
                    transform: Translate { id: sube; y: 14 }
                    Connections {
                        target: panel
                        function onAbiertoChanged() {
                            if (panel.abierto)
                                entra.restart();
                        }
                    }
                    Component.onCompleted: if (panel.abierto) entra.restart()
                    SequentialAnimation {
                        id: entra
                        PropertyAction { target: opcion; property: "opacity"; value: 0 }
                        PropertyAction { target: sube; property: "y"; value: 14 }
                        PauseAnimation { duration: Ajustes.animaciones ? 60 + opcion.index * 45 : 0 }
                        ParallelAnimation {
                            NumberAnimation { target: opcion; property: "opacity"; to: 1; duration: Tema.normal * 1.5; easing.type: Easing.OutCubic }
                            NumberAnimation { target: sube; property: "y"; to: 0; duration: Tema.normal * 2; easing.type: Easing.OutQuint }
                        }
                    }

                    Item {
                        id: boton
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 84; height: 84
                        scale: opcion.elegida ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }

                        // El círculo de cristal
                        Rectangle {
                            id: circulo
                            anchors.fill: parent
                            radius: width / 2
                            color: opcion.elegida ? Qt.alpha(opcion.tono, 0.16) : Tema.sombra(0.4)
                            border.width: 1
                            border.color: opcion.elegida ? Qt.alpha(opcion.tono, 0.6) : Tema.claro(0.14)
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            Behavior on border.color { ColorAnimation { duration: Tema.rapida } }
                        }
                        // Brillo alrededor de la elegida
                        RectangularShadow {
                            anchors.fill: circulo
                            z: -1
                            radius: width / 2
                            blur: 30
                            spread: 0
                            color: Qt.alpha(opcion.tono, 0.35)
                            opacity: opcion.elegida ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
                        }
                        // La cuenta atrás: un aro que se llena
                        Canvas {
                            id: aro
                            anchors.fill: parent
                            anchors.margins: -5
                            visible: opcion.esperando
                            property real p: opcion.esperando ? panel.cuenta : 0
                            onPChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                c.lineWidth = 3;
                                c.lineCap = "round";
                                c.strokeStyle = opcion.tono;
                                c.beginPath();
                                c.arc(width / 2, height / 2, width / 2 - 2, -Math.PI / 2, -Math.PI / 2 + p * 2 * Math.PI);
                                c.stroke();
                            }
                        }
                        Texto {
                            anchors.centerIn: parent
                            text: opcion.modelData.icono
                            font.pixelSize: 30
                            font.bold: false
                            color: opcion.elegida ? opcion.tono : Tema.texto
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Al moverse, no al entrar: si el ratón ya estaba
                            // ahí al abrir, no elige nada (Apagar, por ejemplo)
                            onPositionChanged: if (!panel.pendiente) panel.elegida = opcion.index
                            onClicked: panel.elegir(opcion.modelData)
                        }
                    }

                    // El nombre (o la cuenta atrás)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: opcion.esperando
                            ? ({"c": "Cerrando en ", "r": "Reiniciando en ", "a": "Apagando en "}[opcion.modelData.tecla] ?? "En ") + panel.segundos + "…"
                            : opcion.modelData.titulo
                        color: opcion.elegida ? opcion.tono : Tema.texto
                        opacity: opcion.elegida ? 1 : 0.75
                        font.family: Tema.fuente
                        font.pixelSize: 13
                        font.weight: opcion.elegida ? Font.DemiBold : Font.Normal
                    }
                    // La tecla
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 22; height: 22; radius: 6
                        color: Tema.claro(0.08)
                        border.width: 1
                        border.color: Tema.claro(0.2)
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            text: opcion.modelData.tecla.toUpperCase()
                            color: Tema.gris
                            font.family: Tema.fuente
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    // Abajo: qué se puede hacer (o cómo cancelar la cuenta atrás)
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Math.round(panel.modelData.height * 0.08) }
        opacity: panel.progreso * 0.8
        text: panel.pendiente ? "Esc o un clic para cancelar  ·  Enter para hacerlo ya"
            : "← → elegir  ·  Enter o la letra  ·  Esc cierra"
        color: panel.pendiente ? Tema.texto : Tema.gris
        font.family: Tema.fuente
        font.pixelSize: 12
    }
}
