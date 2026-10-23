// ============================================================================
//  Página «sistema» de la píldora (Pildora.qml): lo que en la barra de islas
//  está siempre a la vista
//
//    [ CPU 12% ━━── ] [ RAM 40% ━━━━─ ] [ 52° ━━━── ]   clic = monitor
//    [ 󰖐 14°C Nublado · Madrid                        ]   clic = página Clima
//    [ 󰕓 Memorias USB ]  [ 󰚰 3 actualizaciones ]          si los hay
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Column {
    id: pagina

    required property var pantalla
    property bool activa: false
    spacing: 8

    // ------------------------------------------------------------- Uso
    Row {
        width: parent.width
        spacing: 8
        Repeater {
            model: [
                {icono: "󰘚", texto: "CPU", valor: Sistema.cpu / 100, cifra: Sistema.cpu + "%", seccion: "rendimiento"},
                {icono: "󰍛", texto: "RAM", valor: Sistema.memoria / 100, cifra: Sistema.memoria + "%", seccion: "procesos"},
                {icono: "󰔏", texto: "Temp.", valor: Math.min(1, Sistema.temperatura / 100), cifra: Sistema.temperatura + "°", seccion: "rendimiento"}
            ]
            Rectangle {
                id: medidor
                required property var modelData
                width: (pagina.width - 16) / 3
                height: 62
                radius: 12
                color: medidorRaton.containsMouse ? Tema.cajaHover : Tema.caja
                Behavior on color { ColorAnimation { duration: Tema.rapida } }

                Texto {
                    anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 10 }
                    text: medidor.modelData.icono + "  " + medidor.modelData.texto
                    font.pixelSize: 11
                    color: Tema.gris
                }
                Texto {
                    anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 9 }
                    text: medidor.modelData.cifra
                    font.pixelSize: 13
                    color: medidor.modelData.valor > 0.9 ? Tema.rojo : Tema.blanco
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                    height: 6
                    radius: 3
                    color: Tema.claro(0.10)
                    Rectangle {
                        width: Math.max(parent.height, parent.width * medidor.modelData.valor)
                        height: parent.height
                        radius: 3
                        color: medidor.modelData.valor > 0.9 ? Tema.rojo : Tema.blanco
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
                MouseArea {
                    id: medidorRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Paneles.alternar("monitor", pagina.pantalla, medidor.modelData.seccion)
                }
            }
        }
    }

    // ------------------------------------------------------------ Clima
    Rectangle {
        width: parent.width
        height: 54
        radius: 12
        color: climaRaton.containsMouse ? Tema.cajaHover : Tema.caja
        Behavior on color { ColorAnimation { duration: Tema.rapida } }

        Row {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 14
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: Tiempo.listo ? Tiempo.icono : "󰖐"
                font.pixelSize: 26
                color: Tema.blanco
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Texto {
                    text: Tiempo.listo ? Tiempo.temperatura + "°C  ·  " + Tiempo.descripcion : "Cargando el tiempo…"
                    font.pixelSize: 13
                    color: Tema.blanco
                }
                Texto {
                    text: Tiempo.lugar + (Tiempo.dias.length ? "  ·  hoy " + Tiempo.dias[0].max + "° / " + Tiempo.dias[0].min + "°" : "")
                    font.bold: false
                    font.pixelSize: 11
                    color: Tema.gris
                }
            }
        }
        MouseArea {
            id: climaRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Paneles.alternar("pildora", pagina.pantalla, "clima")
        }
    }

    // ---------------------------------------- USB y actualizaciones
    Row {
        width: parent.width
        spacing: 8

        Acceso {
            visible: Discos.lista.length > 0
            icono: "󰕓"
            texto: Discos.lista.length === 1 ? "Memoria USB" : Discos.lista.length + " memorias USB"
            onClic: Paneles.alternar("discos", pagina.pantalla, "")
        }
        Acceso {
            icono: Actualizaciones.cuantas > 0 ? "󰚰" : "󰄬"
            texto: Actualizaciones.cuantas > 0
                ? Actualizaciones.cuantas + (Actualizaciones.cuantas === 1 ? " actualización" : " actualizaciones")
                : "Sistema al día"
            onClic: Paneles.alternar("actualizaciones", pagina.pantalla, "")
        }
    }

    component Acceso: Rectangle {
        id: fila
        property string icono: ""
        property string texto: ""
        signal clic()
        width: (pagina.width - 8) / 2
        height: 40
        radius: 12
        color: filaRaton.containsMouse ? Tema.cajaHover : Tema.caja
        Behavior on color { ColorAnimation { duration: Tema.rapida } }
        Row {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 10
            Texto {
                text: fila.icono
                font.pixelSize: 15
                color: Tema.texto
            }
            Texto {
                text: fila.texto
                font.pixelSize: 12
                color: Tema.texto
            }
        }
        MouseArea {
            id: filaRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fila.clic()
        }
    }
}
