// ============================================================================
//  AvisosBloqueo — las notificaciones en el bloqueo
//
//    ( 󰂚  3 notificaciones  ⌄ )            ← clic: se abren
//    ┌──────────────────────────────────┐
//    │ ┌──────────────────────────────┐ │   las mismas tarjetas que los
//    │ │ [img] Firefox · hace 5 min ✕ │ │   avisos de la barra (TarjetaAviso),
//    │ │       Descarga completada    │ │   en un recuadro de panel; aquí no
//    │ └──────────────────────────────┘ │   abren la app ni tienen botones
//    └──────────────────────────────────┘
//
//  Abiertas se quedan así hasta que haces clic fuera (en el fondo) o pulsas
//  Esc: Bloqueo.qml llama a cerrar() con la señal toque() de Cerradura.
//  Si no caben en altoMax, la lista se desplaza con la rueda.
//  Sin notificaciones, no sale.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun
import qs.paneles

Column {
    id: avisos

    property real altoMax: 200
    property bool abiertas: false
    function cerrar() { abiertas = false; }

    readonly property var lista: Notificaciones.lista
    readonly property int cuantas: lista.length
    onCuantasChanged: if (cuantas === 0) abiertas = false

    visible: cuantas > 0
    width: 380
    spacing: 8

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
    // Igual que los avisos de la barra: un recuadro de panel con las mismas
    // tarjetas (TarjetaAviso). Si no caben, se desplaza con la rueda
    Rectangle {
        id: recuadro
        visible: avisos.abiertas
        width: avisos.width
        height: pila.height + 2 * relleno
        readonly property int relleno: 8
        radius: Tema.radioPanel
        color: Tema.panel
        border.width: Tema.borde(2)
        border.color: Tema.panelBorde

        opacity: 0
        transform: Translate { id: caida; y: -6 }
        onVisibleChanged: if (visible) llega.restart()
        Component.onCompleted: if (visible) llega.restart()
        ParallelAnimation {
            id: llega
            NumberAnimation { target: recuadro; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: caida; property: "y"; from: -6; to: 0; duration: 380; easing.type: Easing.OutQuint }
        }

        // Que el clic no llegue al fondo (que las cerraría)
        MouseArea { anchors.fill: parent }

        ListView {
            id: pila
            x: recuadro.relleno
            y: recuadro.relleno
            width: recuadro.width - 2 * recuadro.relleno
            height: Math.min(contentHeight, avisos.altoMax - boton.height - avisos.spacing - 2 * recuadro.relleno)
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: avisos.lista }
            delegate: TarjetaAviso {
                required property var modelData
                entrada: modelData
                width: pila.width
                lineas: 2
                bloqueada: true
                color: hover ? Tema.cajaHover : Tema.caja
                border.color: urgente ? Tema.rojo : Tema.claro(0.06)
                border.width: urgente ? 2 : 1
                radius: 12
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Tema.normal; easing.type: Easing.OutCubic }
            }
        }
    }
}
