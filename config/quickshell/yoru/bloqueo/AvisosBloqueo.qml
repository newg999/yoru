// ============================================================================
//  AvisosBloqueo — las notificaciones en el bloqueo
//
//    ( 󰂚  3 notificaciones  ⌄ )            ← clic: se abren
//    ┌──────────────────────────────────┐
//    │ [icono] Firefox · hace 5 min     │
//    │         Descarga completada      │
//    │         archivo.zip              │
//    └──────────────────────────────────┘
//
//  Abiertas se quedan así hasta que haces clic fuera (en el fondo) o pulsas
//  Esc: Bloqueo.qml llama a cerrar() con la señal toque() de Cerradura.
//  Caben las que entran en altoMax; el resto, «y N más».
//  Sin notificaciones, no sale.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun

Column {
    id: avisos

    property real altoMax: 200
    property bool abiertas: false
    function cerrar() { abiertas = false; }

    readonly property var lista: Notificaciones.lista
    readonly property int cuantas: lista.length
    // Las que entran (si no entran todas, se deja sitio para «y N más»)
    readonly property int entran: Math.floor((altoMax - 36 - spacing) / (60 + spacing))
    readonly property int caben: Math.max(1, cuantas <= entran ? entran : Math.floor((altoMax - 36 - spacing - 22) / (60 + spacing)))
    readonly property var vistas: lista.slice(0, caben)
    onCuantasChanged: if (cuantas === 0) abiertas = false

    visible: cuantas > 0
    width: 380
    spacing: 8

    function limpio(t) {
        return String(t ?? "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    // ---------------------------------------------------------- El botón
    Item {
        width: parent.width
        height: boton.height
        Rectangle {
            id: boton
            anchors.horizontalCenter: parent.horizontalCenter
            width: botonFila.width + 30
            height: 36
            radius: height / 2
            color: Tema.claro(botonZona.containsMouse || avisos.abiertas ? 0.18 : 0.1)
            border.width: 1
            border.color: Tema.claro(0.12)
            scale: botonZona.pressed ? 0.97 : 1
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Row {
                id: botonFila
                anchors.centerIn: parent
                spacing: 9
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰂚"
                    color: Tema.texto
                    font.family: Tema.mono
                    font.pixelSize: 15
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: avisos.cuantas === 1 ? "1 notificación" : avisos.cuantas + " notificaciones"
                    color: Tema.texto
                    font.family: Tema.fuente
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅀"
                    color: Tema.gris
                    font.family: Tema.mono
                    font.pixelSize: 14
                    rotation: avisos.abiertas ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }
            MouseArea {
                id: botonZona
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: avisos.abiertas = !avisos.abiertas
            }
        }
        // Abiertas: «Borrar» a la derecha
        Text {
            anchors { right: parent.right; verticalCenter: boton.verticalCenter }
            opacity: avisos.abiertas ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            text: "Borrar"
            color: borrarZona.containsMouse ? Tema.blanco : Tema.gris
            font.family: Tema.fuente
            font.pixelSize: 12
            font.bold: true
            MouseArea {
                id: borrarZona
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notificaciones.borrarTodas()
            }
        }
    }

    // --------------------------------------------------------- La lista
    Repeater {
        model: avisos.abiertas ? avisos.vistas : []

        Rectangle {
            id: tarjeta
            required property var modelData
            required property int index
            readonly property var n: modelData.n
            readonly property string foto: Notificaciones.imagen(n)
            width: avisos.width
            height: 60
            radius: Tema.esquina(18)
            color: Tema.sombra(0.6)
            border.width: 1
            border.color: Tema.claro(0.1)

            // Entran una detrás de otra, cayendo un poco
            opacity: 0
            transform: Translate { id: caida; y: -6 }
            Component.onCompleted: llega.start()
            SequentialAnimation {
                id: llega
                PauseAnimation { duration: tarjeta.index * 70 }
                ParallelAnimation {
                    NumberAnimation { target: tarjeta; property: "opacity"; to: 1; duration: 360; easing.type: Easing.OutCubic }
                    NumberAnimation { target: caida; property: "y"; to: 0; duration: 420; easing.type: Easing.OutQuint }
                }
            }

            // Que el clic no llegue al fondo (que las cerraría)
            MouseArea { anchors.fill: parent }

            ClippingRectangle {
                id: icono
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                width: 34
                height: 34
                radius: Tema.esquina(10)
                color: Tema.claro(0.08)
                Text {
                    anchors.centerIn: parent
                    visible: imagenAviso.status !== Image.Ready
                    text: "󰂚"
                    color: Tema.gris
                    font.family: Tema.mono
                    font.pixelSize: 17
                }
                Image {
                    id: imagenAviso
                    anchors.fill: parent
                    source: tarjeta.foto
                    sourceSize: Qt.size(72, 72)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors {
                    left: icono.right; leftMargin: 12
                    right: parent.right; rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                spacing: 1
                Item {
                    width: parent.width
                    height: 14
                    Text {
                        anchors { left: parent.left; right: cuando.left; rightMargin: 8 }
                        text: (tarjeta.n?.appName || "Aviso").toUpperCase()
                        color: Tema.gris
                        font.family: Tema.fuente
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        id: cuando
                        anchors.right: parent.right
                        text: Notificaciones.hace(tarjeta.modelData.hora)
                        color: Tema.gris
                        font.family: Tema.fuente
                        font.pixelSize: 10
                    }
                }
                Text {
                    width: parent.width
                    text: avisos.limpio(tarjeta.n?.summary)
                    color: Tema.texto
                    font.family: Tema.fuente
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: avisos.limpio(tarjeta.n?.body)
                    color: Tema.texto
                    opacity: 0.7
                    font.family: Tema.fuente
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: avisos.abiertas && avisos.cuantas > avisos.caben
        text: "y " + (avisos.cuantas - avisos.caben) + " más"
        color: Tema.gris
        font.family: Tema.fuente
        font.pixelSize: 12
    }
}
