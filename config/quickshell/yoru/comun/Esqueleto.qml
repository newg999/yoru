// ============================================================================
//  Esqueleto — mientras algo carga: la forma de lo que va a salir, en gris,
//  latiendo despacio (cada pieza un poco después de la anterior, como una
//  ola). Mejor que un «Cargando…» en medio de un hueco.
//
//    Filas (columnas: 1)           Baldosas (columnas: 3)
//    [■] ▬▬▬▬▬▬▬▬▬     ▬▬          [■] ▬▬▬▬   [■] ▬▬▬▬   [■] ▬▬▬▬
//    [■] ▬▬▬▬▬▬           ▬▬           ▬▬         ▬▬         ▬▬
//
//      Esqueleto { width: lista.width; filas: 8; alto: 40 }
//      Esqueleto { width: rejilla.width; filas: 6; columnas: 3; alto: 88 }
// ============================================================================
import QtQuick

Grid {
    id: esqueleto
    property int filas: 6
    property int columnas: 1
    property int alto: 44
    property bool icono: true
    columns: columnas
    columnSpacing: 8
    rowSpacing: columnas > 1 ? 8 : 2

    Repeater {
        model: esqueleto.filas * esqueleto.columnas
        Rectangle {
            id: pieza
            required property int index
            // Largos distintos, siempre los mismos para cada pieza
            readonly property real largo: 0.45 + 0.4 * Math.abs(Math.sin(index * 2.3 + 1))
            width: (esqueleto.width - (esqueleto.columnas - 1) * esqueleto.columnSpacing) / esqueleto.columnas
            height: esqueleto.alto
            radius: Tema.esquina(10)
            color: esqueleto.columnas > 1 ? Tema.caja : "transparent"

            // Late; cada pieza un poco después que la anterior
            opacity: 0.5
            SequentialAnimation on opacity {
                running: esqueleto.visible && Ajustes.animaciones
                loops: Animation.Infinite
                PauseAnimation { duration: (pieza.index % 8) * 90 }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.5; duration: 700; easing.type: Easing.InOutSine }
                PauseAnimation { duration: (7 - pieza.index % 8) * 90 }
            }

            Rectangle {
                id: cuadro
                visible: esqueleto.icono
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: Math.min(34, pieza.height - 12); height: width
                radius: Tema.esquina(8)
                color: Tema.claro(0.08)
            }
            Column {
                anchors {
                    left: esqueleto.icono ? cuadro.right : parent.left; leftMargin: 12
                    right: parent.right; rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 7
                Rectangle {
                    width: parent.width * pieza.largo
                    height: 9; radius: 4.5
                    color: Tema.claro(0.1)
                }
                Rectangle {
                    width: parent.width * pieza.largo * 0.6
                    height: 7; radius: 3.5
                    color: Tema.claro(0.06)
                }
            }
        }
    }
}
