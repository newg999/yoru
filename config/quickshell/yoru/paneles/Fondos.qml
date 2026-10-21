// ============================================================================
//  Fondos — elegir fondo de pantalla, al estilo de Omarchy
//  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin abrir esto
//
//  Sin recuadro: sobre el escritorio, con un velo oscuro, una fila de
//  tarjetas inclinadas (paralelogramos). La elegida, en el centro, grande y
//  con el borde de Yoru; las demás, más pequeñas y apagadas cuanto más lejos.
//
//    ← → (o la rueda, o arrastrando) para moverte · Enter (o clic en la del
//    centro) para ponerlo · clic en otra la trae al centro · Esc o clic fuera
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
    // Tamaño de la tarjeta del centro (9:16) y cuánto se inclinan
    readonly property int altoTarjeta: Math.round(Math.min(640, modelData.height * 0.5))
    readonly property int anchoTarjeta: Math.round(altoTarjeta * 9 / 16)
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
                carrusel.positionViewAtIndex(Math.max(i, 0), PathView.Center);
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
        PathView {
            id: carrusel
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            width: parent.width
            height: panel.altoTarjeta + 40
            model: panel.fondos
            // Las que se ven a la vez (impar: una en el centro)
            pathItemCount: Math.min(7, panel.fondos.length % 2 === 0 ? panel.fondos.length - 1 : panel.fondos.length)
            cacheItemCount: 4
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            highlightMoveDuration: Ajustes.animaciones ? 320 : 0
            focus: true

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

            // Recto de lado a lado; en el centro, tamaño y luz completos
            path: Path {
                startX: 0
                startY: carrusel.height / 2
                PathAttribute { name: "escala"; value: 0.55 }
                PathAttribute { name: "luz"; value: 0.3 }
                PathAttribute { name: "capa"; value: 0 }
                PathLine { x: carrusel.width / 2; y: carrusel.height / 2 }
                PathAttribute { name: "escala"; value: 1 }
                PathAttribute { name: "luz"; value: 1 }
                PathAttribute { name: "capa"; value: 10 }
                PathLine { x: carrusel.width; y: carrusel.height / 2 }
                PathAttribute { name: "escala"; value: 0.55 }
                PathAttribute { name: "luz"; value: 0.3 }
                PathAttribute { name: "capa"; value: 0 }
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
                readonly property real escala: PathView.escala ?? 0.55
                readonly property real luz: PathView.luz ?? 0.3
                // Lo que se va a la derecha el borde de arriba (y a la izquierda el de abajo)
                readonly property real sesgo: panel.inclinacion * height / 2
                width: panel.anchoTarjeta
                height: panel.altoTarjeta
                scale: escala
                z: PathView.capa ?? 0

                // La forma: un paralelogramo (la tarjeta, inclinada)
                Item {
                    id: forma
                    anchors.fill: parent
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -panel.inclinacion, 0, tarjeta.sesgo,
                                             0, 1, 0, 0,
                                             0, 0, 1, 0,
                                             0, 0, 0, 1)
                    }

                    // Sombra
                    Rectangle {
                        anchors { fill: parent; topMargin: 14; bottomMargin: -18; leftMargin: -6; rightMargin: -6 }
                        radius: 16
                        color: Qt.rgba(0, 0, 0, 0.4 * tarjeta.luz)
                    }

                    ClippingRectangle {
                        anchors.fill: parent
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
                            opacity: tarjeta.luz
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, panel.inclinacion, 0, -tarjeta.sesgo,
                                                     0, 1, 0, 0,
                                                     0, 0, 1, 0,
                                                     0, 0, 0, 1)
                            }
                        }
                    }

                    // Borde de la elegida (como el anillo de foco de niri)
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "transparent"
                        border.width: 3
                        border.color: Tema.blanco
                        opacity: tarjeta.elegida ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
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
