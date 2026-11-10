// ============================================================================
//  Fondos — elegir fondo de pantalla
//  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin abrir esto
//
//  Detrás, a pantalla completa, el fondo elegido desenfocado (cambia con un
//  fundido al moverte: así se ve cómo queda, y el texto se lee siempre).
//  Delante, una galería de tarjetas inclinadas: la elegida en el centro y
//  más grande; a cada lado, dos más pequeñas y apagadas. Es una rueda:
//  tras la última, la primera.
//
//          ╱▔▔╱ ╱▔▔▔╱ ╱▔▔▔▔▔▔╱ ╱▔▔▔╱ ╱▔▔╱
//         ╱  ╱ ╱   ╱ ╱ elegida╱ ╱   ╱ ╱  ╱
//                    anime-8ge2x1
//          3840×2160  ·  ✓ PUESTO  ·  9 / 36
//      [←][→] elegir  [↵] poner  [Supr] borrar  [Esc] cerrar
//         ( Uno al azar )  ( Buscar más fondos )
//
//    ← → (o la rueda, o un clic en otra) para moverte · Enter (o clic en la
//    elegida) para ponerlo · Esc o clic fuera para cerrar · Supr (o la
//    papelera de la elegida) dos veces = mandarlo a la papelera; la primera
//    vez lo pide abajo, en rojo
//
//  Los fondos salen de ~/.local/share/wallpapers (scripts/fondos.sh hace las
//  tarjetas, las vistas y mira la resolución la primera vez) y se ponen con
//  niri/scripts/wallpaper.sh, que también los lleva al bloqueo, al inicio de
//  sesión y a «yoru tema fondo». Buscar fondos nuevos (wallhaven) está en
//  Ajustes › Fondo (Descubrir.qml).
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.comun

PanelWindow {
    id: panel

    required property ShellScreen modelData
    readonly property bool abierto: Paneles.abierto === "fondos" && Paneles.pantalla === modelData

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
    WlrLayershell.namespace: "yoru-fondos"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string casa: Quickshell.env("HOME")

    // La galería: la del centro (9:16) al 46 % del alto de la pantalla; las
    // de al lado, más pequeñas. Las tarjetas se inclinan (paralelogramos)
    readonly property int altoTarjeta: Math.round(Math.min(modelData.height * 0.46, modelData.width * 0.42 * 16 / 9))
    readonly property int anchoTarjeta: Math.round(altoTarjeta * 9 / 16)
    readonly property real inclinacion: 0.16    // desplazamiento horizontal por px de alto
    readonly property int separacion: 24
    readonly property real escala1: 0.8         // las de al lado
    readonly property real escala2: 0.64        // las de los extremos
    // Del centro de una tarjeta al de la siguiente (las escaladas ocupan menos)
    readonly property real paso1: anchoTarjeta * (1 + escala1) / 2 + separacion
    readonly property real paso2: anchoTarjeta * (escala1 + escala2) / 2 + separacion

    property var fondos: []          // [{ruta, miniatura, vista, medida, nombre}]
    property string actual: ""
    property bool cargando: false
    readonly property var elegido: fondos[carrusel.currentIndex] ?? null

    // Borrar: la primera vez (Supr o la papelera) lo pide; la segunda, a la papelera
    property string aBorrar: ""
    function borrar(fondo) {
        if (!fondo || borrador.running)
            return;
        if (aBorrar !== fondo.ruta) {
            aBorrar = fondo.ruta;
            olvidarBorrar.restart();
            return;
        }
        aBorrar = "";
        borrador.command = [Quickshell.shellPath("scripts/wallhaven.py"), "borrar", fondo.ruta];
        borrador.running = true;
    }
    Timer {
        id: olvidarBorrar
        interval: 4000
        onTriggered: panel.aBorrar = ""
    }
    Process {
        id: borrador
        onExited: {
            const i = carrusel.currentIndex;
            leer.running = true;
            actualFile.reload();
            carrusel.currentIndex = Math.max(0, Math.min(i, panel.fondos.length - 2));
        }
    }

    onAbiertoChanged: {
        if (abierto) {
            cargando = fondos.length === 0;
            aBorrar = "";
            leer.running = true;
            actualFile.reload();
            carrusel.forceActiveFocus();
        }
    }

    function poner(fondo) {
        if (!fondo)
            return;
        actual = fondo.ruta;
        Niri.lanzar([casa + "/.config/niri/scripts/wallpaper.sh", fondo.ruta]);
        Paneles.cerrar();
    }

    FileView {
        id: actualFile
        path: panel.casa + "/.cache/wallpaper-actual"
        onLoaded: panel.actual = text().trim()
    }

    Process {
        id: leer
        command: [Quickshell.shellPath("scripts/fondos.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.fondos = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [ruta, miniatura, vista, medida] = l.split("\t");
                    return {ruta, miniatura, vista: vista ?? "", medida: medida ?? "",
                            nombre: ruta.split("/").pop().replace(/\.[^.]+$/, "")};
                });
                panel.cargando = false;
                const i = panel.fondos.findIndex(f => f.ruta === panel.actual);
                carrusel.positionViewAtIndex(Math.max(i, 0), PathView.Center);
                carrusel.currentIndex = Math.max(i, 0);
            }
        }
    }

    // ---------------------------------------------------- Fondo de detrás
    // El elegido, desenfocado, a pantalla completa. Dos capas que se turnan:
    // la nueva aparece encima de la anterior con un fundido
    Item {
        id: detras
        anchors.fill: parent
        opacity: panel.progreso
        property bool usaA: true
        readonly property string vista: panel.elegido?.vista ? "file://" + panel.elegido.vista : ""
        onVistaChanged: {
            if (vista === "")
                return;
            usaA = !usaA;
            (usaA ? capaA : capaB).source = vista;
        }

        Rectangle {
            anchors.fill: parent
            color: Tema.oscuro
        }
        Item {
            id: imagenes
            anchors.fill: parent
            visible: false
            Image {
                id: capaA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: detras.usaA && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal * 2; easing.type: Easing.InOutSine } }
            }
            Image {
                id: capaB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: !detras.usaA && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tema.normal * 2; easing.type: Easing.InOutSine } }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: imagenes
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.1
            autoPaddingEnabled: false
        }
        // Un velo, más oscuro abajo (donde va el texto) y por los bordes
        Rectangle {
            anchors.fill: parent
            color: Tema.sombra(0.35)
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.sombra(0.35) }
                GradientStop { position: 0.45; color: Tema.sombra(0) }
                GradientStop { position: 0.7; color: Tema.sombra(0.2) }
                GradientStop { position: 1; color: Tema.sombra(0.75) }
            }
        }
        // Un clic fuera de todo cierra
        MouseArea {
            anchors.fill: parent
            onClicked: Paneles.cerrar()
        }
    }

    Item {
        anchors.fill: parent
        opacity: panel.progreso
        // Al abrirse, sube un poco desde abajo
        transform: Translate { y: (1 - panel.progreso) * 30 }

        // ---------------------------------------------------- Galería
        // Siete puestos: la elegida en medio, dos visibles a cada lado y uno
        // invisible en cada punta (por ahí entran y salen). Los huecos no son
        // iguales (las de los lados son más pequeñas): PathPercent pone cada
        // puesto en su sitio
        PathView {
            id: carrusel
            readonly property int puestos: 7
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Math.round(panel.modelData.height * 0.08)
            width: parent.width
            height: panel.altoTarjeta + 40
            model: panel.fondos
            pathItemCount: puestos
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            highlightMoveDuration: Ajustes.animaciones ? 340 : 0
            cacheItemCount: 6
            interactive: false      // se mueve con teclas, rueda y clics
            focus: true

            // Siete puestos a 1/7 uno de otro (la elegida en 0.5); los dos de
            // las puntas, invisibles, y algo más allá de cada punta, el final
            path: Path {
                id: path
                readonly property real cx: carrusel.width / 2
                readonly property real fuera: panel.paso2 + panel.anchoTarjeta * panel.escala2 * 0.6
                startX: cx - panel.paso1 - panel.paso2 - 2 * fuera
                startY: carrusel.height / 2

                PathAttribute { name: "escala"; value: panel.escala2 * 0.8 }
                PathAttribute { name: "presencia"; value: 0 }
                PathAttribute { name: "luz"; value: 0.3 }
                PathLine { relativeX: path.fuera; relativeY: 0 }
                PathPercent { value: 1 / 14 }
                PathAttribute { name: "escala"; value: panel.escala2 * 0.85 }
                PathAttribute { name: "presencia"; value: 0 }
                PathAttribute { name: "luz"; value: 0.3 }
                PathLine { relativeX: path.fuera; relativeY: 0 }
                PathPercent { value: 3 / 14 }
                PathAttribute { name: "escala"; value: panel.escala2 }
                PathAttribute { name: "presencia"; value: 1 }
                PathAttribute { name: "luz"; value: 0.4 }
                PathLine { relativeX: panel.paso2; relativeY: 0 }
                PathPercent { value: 5 / 14 }
                PathAttribute { name: "escala"; value: panel.escala1 }
                PathAttribute { name: "presencia"; value: 1 }
                PathAttribute { name: "luz"; value: 0.6 }
                PathLine { relativeX: panel.paso1; relativeY: 0 }
                PathPercent { value: 7 / 14 }
                PathAttribute { name: "escala"; value: 1 }
                PathAttribute { name: "presencia"; value: 1 }
                PathAttribute { name: "luz"; value: 1 }
                PathLine { relativeX: panel.paso1; relativeY: 0 }
                PathPercent { value: 9 / 14 }
                PathAttribute { name: "escala"; value: panel.escala1 }
                PathAttribute { name: "presencia"; value: 1 }
                PathAttribute { name: "luz"; value: 0.6 }
                PathLine { relativeX: panel.paso2; relativeY: 0 }
                PathPercent { value: 11 / 14 }
                PathAttribute { name: "escala"; value: panel.escala2 }
                PathAttribute { name: "presencia"; value: 1 }
                PathAttribute { name: "luz"; value: 0.4 }
                PathLine { relativeX: path.fuera; relativeY: 0 }
                PathPercent { value: 13 / 14 }
                PathAttribute { name: "escala"; value: panel.escala2 * 0.85 }
                PathAttribute { name: "presencia"; value: 0 }
                PathAttribute { name: "luz"; value: 0.3 }
                PathLine { relativeX: path.fuera; relativeY: 0 }
                PathPercent { value: 1 }
                PathAttribute { name: "escala"; value: panel.escala2 * 0.8 }
                PathAttribute { name: "presencia"; value: 0 }
                PathAttribute { name: "luz"; value: 0.3 }
            }

            Keys.onLeftPressed: decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onReturnPressed: panel.poner(panel.elegido)
            Keys.onEnterPressed: panel.poner(panel.elegido)
            Keys.onEscapePressed: panel.aBorrar !== "" ? panel.aBorrar = "" : Paneles.cerrar()
            Keys.onDeletePressed: panel.borrar(panel.elegido)
            onCurrentIndexChanged: panel.aBorrar = ""

            // La rueda pasa de una en una (sin esto, un giro salta varias)
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => {
                    if (e.angleDelta.y < 0 || e.angleDelta.x < 0)
                        carrusel.incrementCurrentIndex();
                    else
                        carrusel.decrementCurrentIndex();
                }
            }

            Texto {
                visible: panel.fondos.length === 0
                anchors.centerIn: parent
                text: panel.cargando ? "Preparando miniaturas…"
                    : "No hay fondos: busca alguno en Ajustes › Fondo, o echa imágenes en wallpapers/"
                font.bold: false
                color: Tema.texto
            }

            delegate: Item {
                id: tarjeta
                required property var modelData
                required property int index
                readonly property bool elegida: PathView.isCurrentItem
                readonly property bool puesto: modelData.ruta === panel.actual
                readonly property bool marcada: panel.aBorrar === modelData.ruta
                readonly property real luz: PathView.luz ?? 0
                readonly property bool enFila: opacity > 0.5
                // Lo que se va a la derecha el borde de arriba (y a la izquierda el de abajo)
                readonly property real sesgo: panel.inclinacion * height / 2
                width: panel.anchoTarjeta
                height: panel.altoTarjeta
                scale: PathView.escala ?? 0.5
                z: scale
                opacity: PathView.presencia ?? 0

                // La forma: un paralelogramo. La tarjeta se dibuja RECTA en una
                // capa con 2 px de margen transparente, y lo que se inclina es
                // la capa entera: así el filtrado de la textura alisa los bordes
                // (inclinada tal cual salen dientes de sierra), y al moverse solo
                // se desplaza una imagen ya hecha
                Item {
                    id: forma
                    anchors.fill: parent
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -panel.inclinacion, 0, tarjeta.sesgo,
                                             0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1)
                    }

                    // Sombra debajo de la elegida, para que se despegue
                    RectangularShadow {
                        anchors.fill: parent
                        visible: tarjeta.elegida
                        radius: Tema.esquina(14)
                        blur: 36
                        spread: 2
                        offset.y: 10
                        color: Qt.rgba(0, 0, 0, 0.55)
                    }

                    Item {
                        anchors { fill: parent; margins: -2 }
                        layer.enabled: true
                        layer.smooth: true

                        ClippingRectangle {
                            anchors { fill: parent; margins: 2 }
                            radius: Tema.esquina(14)
                            color: Tema.caja

                            // La foto, enderezada (inclinada al revés) y algo más
                            // ancha, para que llene las esquinas sin deformarse
                            Image {
                                x: -tarjeta.sesgo
                                width: parent.width + 2 * tarjeta.sesgo
                                height: parent.height
                                source: "file://" + tarjeta.modelData.miniatura
                                sourceSize: Qt.size(360, 640)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, panel.inclinacion, 0, -tarjeta.sesgo,
                                                         0, 1, 0, 0,
                                                         0, 0, 1, 0,
                                                         0, 0, 0, 1)
                                }
                            }
                            // Apagadas según lo lejos que estén (con una capa
                            // oscura: transparentes se mezclarían con lo de detrás)
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 1 - tarjeta.luz)
                            }
                            // La que se va a borrar, teñida de rojo
                            Rectangle {
                                anchors.fill: parent
                                color: Tema.rojo
                                opacity: tarjeta.marcada ? 0.35 : 0
                                Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                            }
                        }

                        // Borde: del tema en la elegida (rojo si se va a borrar),
                        // un hilo claro en las demás
                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            radius: Tema.esquina(14)
                            color: "transparent"
                            border.width: tarjeta.elegida ? 3 : 1
                            border.color: tarjeta.marcada ? Tema.rojo : tarjeta.elegida ? Tema.blanco : Tema.claro(0.12)
                            Behavior on border.color { ColorAnimation { duration: Tema.rapida } }
                        }
                    }
                }

                HoverHandler { id: encima }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: tarjeta.enFila
                    onClicked: {
                        if (tarjeta.elegida)
                            panel.poner(tarjeta.modelData);
                        else
                            carrusel.currentIndex = tarjeta.index;
                    }
                }

                // Papelera: solo en la elegida y con el ratón encima (o si ya
                // se ha pedido borrarla), en la esquina de arriba, que con la
                // inclinación queda más a la derecha
                Rectangle {
                    visible: tarjeta.elegida
                    opacity: encima.hovered || tarjeta.marcada ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                    anchors { right: parent.right; top: parent.top; topMargin: 12; rightMargin: 12 - tarjeta.sesgo * 0.85 }
                    width: 32; height: 32; radius: 16
                    color: tarjeta.marcada || papelera.containsMouse ? Tema.rojo : Tema.sombra(0.7)
                    border.width: 1
                    border.color: Tema.claro(0.15)
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    Texto {
                        anchors.centerIn: parent
                        text: "󰩹"
                        font.pixelSize: 15
                        color: tarjeta.marcada || papelera.containsMouse ? Tema.oscuro : Tema.texto
                    }
                    MouseArea {
                        id: papelera
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.borrar(tarjeta.modelData)
                    }
                }
            }
        }

        // ------------------------------------- Nombre, datos y lo que se puede hacer
        Column {
            visible: panel.fondos.length > 0
            anchors { top: carrusel.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
            spacing: 12

            // El nombre, grande y fino
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.elegido?.nombre ?? ""
                color: Tema.blanco
                font.family: Tema.fuente
                font.pixelSize: 24
                font.weight: Font.Light
                font.letterSpacing: 0.5
            }

            // Resolución · puesto ahora · posición
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                component Dato: Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.texto
                    opacity: 0.8
                    font.family: Tema.fuente
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 1.5
                    font.features: { "tnum": 1 }
                }
                component Punto: Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 3; radius: 1.5
                    color: Tema.gris
                }
                Dato {
                    visible: text !== ""
                    text: panel.elegido?.medida ?? ""
                }
                Punto { visible: (panel.elegido?.medida ?? "") !== "" }
                Rectangle {
                    visible: panel.elegido?.ruta === panel.actual
                    anchors.verticalCenter: parent.verticalCenter
                    width: puestoFila.width + 16
                    height: 20
                    radius: 10
                    color: Tema.claro(0.16)
                    border.width: 1
                    border.color: Tema.claro(0.35)
                    Row {
                        id: puestoFila
                        anchors.centerIn: parent
                        spacing: 5
                        Texto { text: "󰄬"; font.pixelSize: 11; color: Tema.blanco }
                        Texto { text: "PUESTO"; font.pixelSize: 10; font.letterSpacing: 1.5; color: Tema.blanco }
                    }
                }
                Punto { visible: panel.elegido?.ruta === panel.actual }
                Dato {
                    text: `${carrusel.currentIndex + 1} / ${panel.fondos.length}`
                }
            }

            // Las teclas, como teclitas; o, si se ha pedido borrar, el aviso
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(teclas.width, aviso.width)
                height: 26

                Row {
                    id: teclas
                    anchors.centerIn: parent
                    spacing: 18
                    opacity: panel.aBorrar === "" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tema.rapida } }

                    Repeater {
                        model: [
                            {teclas: ["←", "→"], que: "elegir"},
                            {teclas: ["↵"], que: "poner"},
                            {teclas: ["Supr"], que: "borrar"},
                            {teclas: ["Esc"], que: "cerrar"}
                        ]
                        Row {
                            id: atajo
                            required property var modelData
                            spacing: 4
                            Repeater {
                                model: atajo.modelData.teclas
                                Rectangle {
                                    required property string modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(22, letraTecla.implicitWidth + 12)
                                    height: 22
                                    radius: 6
                                    color: Tema.claro(0.1)
                                    border.width: 1
                                    border.color: Tema.claro(0.22)
                                    // Un borde más grueso abajo, como una tecla de verdad
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                                        height: 2
                                        radius: 1
                                        color: Tema.claro(0.12)
                                    }
                                    Texto {
                                        id: letraTecla
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -1
                                        text: parent.modelData
                                        font.pixelSize: 11
                                        color: Tema.texto
                                    }
                                }
                            }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: 3
                                text: atajo.modelData.que
                                font.pixelSize: 12
                                font.bold: false
                                color: Tema.texto
                                opacity: 0.75
                            }
                        }
                    }
                }

                // ¿Borrar? Abajo, no encima de la foto
                Row {
                    id: aviso
                    anchors.centerIn: parent
                    spacing: 8
                    opacity: panel.aBorrar !== "" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰩹"
                        font.pixelSize: 14
                        color: Tema.rojo
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "¿A la papelera? Pulsa Supr otra vez (Esc no)"
                        font.pixelSize: 13
                        color: Tema.rojo
                    }
                }
            }

            Item { width: 1; height: 2 }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Repeater {
                    model: [
                        {id: "azar", icono: "󰒝", texto: "Uno al azar"},
                        {id: "descubrir", icono: "󰍉", texto: "Buscar más fondos"}
                    ]
                    Rectangle {
                        id: boton
                        required property var modelData
                        width: filaBoton.width + 30
                        height: 36
                        radius: 18
                        color: botonRaton.containsMouse ? Tema.claro(0.2) : Tema.sombra(0.45)
                        border.width: 1
                        border.color: botonRaton.containsMouse ? Tema.claro(0.4) : Tema.claro(0.15)
                        scale: botonRaton.pressed ? 0.96 : 1
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Behavior on scale { NumberAnimation { duration: Tema.rapida } }

                        Row {
                            id: filaBoton
                            anchors.centerIn: parent
                            spacing: 8
                            Texto { text: boton.modelData.icono; font.pixelSize: 14; color: Tema.blanco }
                            Texto { text: boton.modelData.texto; font.pixelSize: 12 }
                        }
                        MouseArea {
                            id: botonRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (boton.modelData.id === "azar")
                                    panel.poner(panel.fondos[Math.floor(Math.random() * panel.fondos.length)]);
                                else
                                    Paneles.alternar("ajustes", panel.modelData, "fondo");
                            }
                        }
                    }
                }
            }
        }
    }
}
