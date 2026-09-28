// Brillo de una pantalla: 󰃠 ━━━━○── 80%  (con el nombre encima si hay varias)
import QtQuick
import qs.comun

Column {
    id: fila

    property var pantalla: null
    property bool conNombre: false

    spacing: 0

    Texto {
        visible: fila.conNombre
        leftPadding: 42
        text: fila.pantalla?.nombre ?? ""
        font.bold: false
        font.pixelSize: 11
        color: Tema.gris
    }

    Item {
        width: parent.width
        implicitHeight: 40

        Texto {
            id: icono
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 34
            horizontalAlignment: Text.AlignHCenter
            // Sol más o menos lleno según el brillo
            text: (fila.pantalla?.valor ?? 0) < 0.35 ? "󰃞" : (fila.pantalla?.valor ?? 0) < 0.7 ? "󰃟" : "󰃠"
            font.pixelSize: 15
        }

        Deslizador {
            anchors {
                left: icono.right; leftMargin: 8
                right: porcentaje.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            valor: fila.pantalla?.valor ?? 0
            onMovido: nuevo => Brillo.poner(fila.pantalla.id, nuevo)
        }

        // Alineado con el porcentaje del volumen (que lleva el botón 󰅀 a la derecha)
        Texto {
            id: porcentaje
            width: 40
            horizontalAlignment: Text.AlignRight
            text: Math.round((fila.pantalla?.valor ?? 0) * 100) + "%"
            font.pixelSize: 12
            anchors { right: parent.right; rightMargin: 34; verticalCenter: parent.verticalCenter }
        }
    }
}
