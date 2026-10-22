// ============================================================================
//  Fondos — elegir fondo de pantalla, al estilo de Omarchy
//  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin abrir esto
//
//  Sin recuadro: sobre el escritorio, con un velo oscuro, una fila de cuatro
//  tarjetas inclinadas (paralelogramos), casi pegadas. La elegida es la
//  primera, con el borde de Yoru; a su derecha, las que vienen. Las que
//  pasan a la izquierda se desvanecen.
//
//    ← → (o la rueda, o arrastrando) para moverte · Enter (o clic en la
//    elegida) para ponerlo · clic en otra la elige · Esc o clic fuera
//    para cerrar · Supr (o la papelera) dos veces = mandarlo a la papelera
//
//  Los fondos salen de ~/.local/share/wallpapers (scripts/fondos.sh hace
//  las miniaturas la primera vez) y se ponen con niri/scripts/wallpaper.sh,
//  que también los lleva al bloqueo, al inicio de sesión y a «yoru tema fondo».
//  Buscar fondos nuevos (wallhaven) está en Ajustes › Fondo (Descubrir.qml).
// ============================================================================
import QtQuick
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
        NumberAnimation { duration: Tema.normal * 1.4; easing.type: Easing.OutCubic }
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
    // Cuatro tarjetas (9:16) casi pegadas, del ancho que quepa (hasta el 60 %
    // de la pantalla y el 38 % de su alto), y cuánto se inclinan
    readonly property int visibles: 4
    readonly property int separacion: 14
    readonly property int anchoTarjeta: Math.round(Math.min((modelData.width * 0.6 - (visibles - 1) * separacion) / visibles,
                                                            modelData.height * 0.38 * 9 / 16))
    readonly property int hueco: anchoTarjeta + separacion   // de una tarjeta a la siguiente
    readonly property int altoTarjeta: Math.round(anchoTarjeta * 16 / 9)
    readonly property real inclinacion: 0.16    // desplazamiento horizontal por px de alto

    property var fondos: []          // [{ruta, miniatura, nombre}]
    property string actual: ""
    property bool cargando: false

    // Borrar: el primer clic (o Supr) lo marca en rojo; el segundo, a la papelera
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
        interval: 3000
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
                    const [ruta, miniatura] = l.split("\t");
                    return {ruta, miniatura, nombre: ruta.split("/").pop().replace(/\.[^.]+$/, "")};
                });
                panel.cargando = false;
                const i = panel.fondos.findIndex(f => f.ruta === panel.actual);
                carrusel.positionViewAtIndex(Math.max(i, 0), PathView.Beginning);
                carrusel.currentIndex = Math.max(i, 0);
            }
        }
    }

    // ------------------------------------------------------------- Velo
    // Oscurece el escritorio; un clic en él cierra
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55 * panel.progreso)
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

        // ---------------------------------------------------- Carrusel
        // Como en Omarchy: la elegida es la primera (a la izquierda) y a su
        // derecha vienen las siguientes. Es una rueda: tras la última, la
        // primera otra vez. El camino es recto, con un puesto invisible a cada
        // lado de las cuatro: por el de la izquierda se va la que pasa
        // (desvaneciéndose) y por el de la derecha entra la nueva.
        //   [ sale ] [ elegida ] [ 2 ] [ 3 ] [ 4 ] [ entra ]
        PathView {
            id: carrusel
            readonly property int puestos: panel.visibles + 2
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            width: panel.visibles * panel.anchoTarjeta + (panel.visibles - 1) * panel.separacion
            height: panel.altoTarjeta + 40
            model: panel.fondos
            pathItemCount: puestos
            // La elegida, en el segundo puesto (el primero es el de salida)
            preferredHighlightBegin: 1 / puestos
            preferredHighlightEnd: 1 / puestos
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            highlightMoveDuration: Ajustes.animaciones ? 300 : 0
            // Las que van a entrar, ya hechas: crearlas a mitad de la
            // animación daba tirones
            cacheItemCount: 6
            focus: true

            // Un puesto cada «hueco» px; la presencia (opacidad) sube y baja en los extremos
            path: Path {
                startX: panel.anchoTarjeta / 2 - panel.hueco
                startY: carrusel.height / 2
                PathAttribute { name: "presencia"; value: 0 }
                PathLine { relativeX: panel.hueco; relativeY: 0 }
                PathAttribute { name: "presencia"; value: 1 }
                PathLine { relativeX: (panel.visibles - 1) * panel.hueco; relativeY: 0 }
                PathAttribute { name: "presencia"; value: 1 }
                PathLine { relativeX: panel.hueco; relativeY: 0 }
                PathAttribute { name: "presencia"; value: 0 }
                PathLine { relativeX: panel.hueco; relativeY: 0 }
                PathAttribute { name: "presencia"; value: 0 }
            }

            Keys.onLeftPressed: decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onReturnPressed: panel.poner(panel.fondos[currentIndex])
            Keys.onEnterPressed: panel.poner(panel.fondos[currentIndex])
            Keys.onEscapePressed: Paneles.cerrar()
            Keys.onDeletePressed: panel.borrar(panel.fondos[currentIndex])

            // La rueda pasa de una en una (sin esto, un giro salta varias)
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse
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
                readonly property bool enFila: opacity > 0.5
                readonly property real luz: elegida ? 1 : 0.7
                // Lo que se va a la derecha el borde de arriba (y a la izquierda el de abajo)
                readonly property real sesgo: panel.inclinacion * height / 2
                width: panel.anchoTarjeta
                height: panel.altoTarjeta
                // Las que se van a la izquierda (o aún no han llegado) no se ven
                opacity: PathView.presencia ?? 0

                // La forma: un paralelogramo (la tarjeta, inclinada).
                // La tarjeta se dibuja RECTA en una capa con 2 px de margen
                // transparente, y lo que se inclina es la capa entera:
                //  · al inclinarla, el filtrado de la textura (layer.smooth)
                //    alisa los bordes; inclinando la tarjeta tal cual, Qt la
                //    dibuja sin suavizado y salen en dientes de sierra
                //  · la capa se dibuja una vez: al moverse el carrusel solo se
                //    desplaza una imagen ya hecha (fluido a 240 Hz)
                Item {
                    id: forma
                    anchors.fill: parent
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -panel.inclinacion, 0, tarjeta.sesgo,
                                             0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1)
                    }

                    Item {
                        anchors { fill: parent; margins: -2 }
                        layer.enabled: true
                        layer.smooth: true

                        ClippingRectangle {
                            anchors { fill: parent; margins: 2 }
                            radius: 12
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
                        }

                        // Las que no son la elegida, algo apagadas: con una capa
                        // oscura encima, no transparentes (si no, se mezclan con
                        // lo que hay detrás)
                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            visible: !tarjeta.elegida
                            radius: 12
                            color: Qt.rgba(0, 0, 0, 1 - tarjeta.luz)
                        }

                        // Borde de la elegida (como el anillo de foco de niri)
                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            visible: tarjeta.elegida
                            radius: 12
                            color: "transparent"
                            border.width: 3
                            border.color: Tema.blanco
                        }
                    }
                }

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

                // Papelera (solo en la del centro), sobre la esquina de arriba,
                // que con la inclinación queda más a la derecha.
                // Primer clic: en rojo; segundo: se borra
                Rectangle {
                    readonly property bool marcado: panel.aBorrar === tarjeta.modelData.ruta
                    visible: tarjeta.elegida || marcado
                    anchors { right: parent.right; top: parent.top; topMargin: 14; rightMargin: 14 - tarjeta.sesgo * 0.8 }
                    width: marcado ? confirmar.width + 34 : 30
                    height: 30
                    radius: 15
                    color: marcado ? Tema.rojo : papelera.containsMouse ? Qt.alpha(Tema.rojo, 0.85) : Qt.alpha(Tema.oscuro, 0.75)
                    Behavior on width { NumberAnimation { duration: Tema.rapida } }
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Texto {
                            text: "󰩹"
                            font.pixelSize: 14
                            color: Tema.blanco
                        }
                        Texto {
                            id: confirmar
                            visible: parent.parent.marcado
                            text: "¿Borrar?"
                            font.pixelSize: 11
                            color: Tema.blanco
                        }
                    }

                    MouseArea {
                        id: papelera
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.borrar(tarjeta.modelData)
                    }
                }

                // El que está puesto ahora, en la esquina de abajo
                Rectangle {
                    visible: tarjeta.puesto
                    anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 14; rightMargin: 14 + tarjeta.sesgo * 0.8 }
                    width: 30; height: 30; radius: 15
                    color: Tema.blanco
                    Texto {
                        anchors.centerIn: parent
                        text: "󰄬"
                        font.pixelSize: 15
                        color: Tema.oscuro
                    }
                }
            }
        }

        // ------------------------------------- Nombre y lo que se puede hacer
        Column {
            visible: panel.fondos.length > 0
            anchors { top: carrusel.bottom; topMargin: 18; horizontalCenter: parent.horizontalCenter }
            spacing: 10

            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (panel.fondos[carrusel.currentIndex]?.nombre ?? "")
                    + (panel.fondos[carrusel.currentIndex]?.ruta === panel.actual ? "  ·  puesto ahora" : "")
                font.pixelSize: 15
                color: Tema.blanco
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${carrusel.currentIndex + 1} de ${panel.fondos.length}  ·  ← → elegir  ·  Enter lo pone  ·  Supr lo borra  ·  Esc cierra`
                font.pixelSize: 12
                font.bold: false
                color: Tema.texto
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: [
                        {id: "azar", icono: "󰒝", texto: "Uno al azar"},
                        {id: "descubrir", icono: "󰍉", texto: "Buscar más fondos"}
                    ]
                    Rectangle {
                        id: boton
                        required property var modelData
                        width: filaBoton.width + 28
                        height: 34
                        radius: 17
                        color: botonRaton.containsMouse ? Tema.claro(0.22) : Tema.claro(0.10)
                        border.width: 1
                        border.color: Tema.claro(0.15)
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }

                        Row {
                            id: filaBoton
                            anchors.centerIn: parent
                            spacing: 8
                            Texto { text: boton.modelData.icono; font.pixelSize: 14 }
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
