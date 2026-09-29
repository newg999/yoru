// ============================================================================
//  Panel de notificaciones — se abre con la campana de la barra (Mod+Alt+M)
//
//    ┌──────────────────────────────────┐
//    │ Notificaciones · 3     󰂛  󰆴     │  no molestar · borrar todas
//    │ ┌──────────────────────────────┐ │
//    │ │ notificación más nueva       │ │
//    │ └──────────────────────────────┘ │
//    │ ...                              │
//    └──────────────────────────────────┘
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Panel {
    id: panel
    nombre: "notificaciones"
    lado: "derecha"
    ancho: 400

    Column {
        width: parent.width
        spacing: 8

        Titular {
            width: parent.width
            texto: "Notificaciones" + (Notificaciones.cuantas > 0 ? " · " + Notificaciones.cuantas : "")

            BotonIcono {
                icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
                colorIcono: Notificaciones.noMolestar ? Tema.blanco : Tema.gris
                color: Notificaciones.noMolestar ? Tema.activo : "transparent"
                onClic: Notificaciones.noMolestar = !Notificaciones.noMolestar
            }
            BotonIcono {
                icono: "󰆴"
                colorIcono: Tema.gris
                visible: Notificaciones.cuantas > 0
                onClic: Notificaciones.borrarTodas()
            }
        }

        Texto {
            visible: Notificaciones.noMolestar
            leftPadding: 4
            text: "No molestar: se guardan sin avisar (salvo las urgentes)"
            font.bold: false
            font.pixelSize: 11
            color: Tema.gris
        }

        Lista {
            id: lista
            width: parent.width
            maximo: Math.round(panel.modelData.height * 0.7)
            height: Math.max(implicitHeight, 80)
            spacing: 6
            model: ScriptModel { values: Notificaciones.lista }

            Column {
                visible: Notificaciones.cuantas === 0
                anchors.centerIn: parent
                spacing: 6
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰂜"
                    font.pixelSize: 26
                    color: Tema.tenue
                }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No hay notificaciones"
                    font.bold: false
                    color: Tema.gris
                }
            }

            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Tema.rapida }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: Tema.normal; easing.type: Easing.OutCubic }
            }

            delegate: TarjetaAviso {
                required property var modelData
                entrada: modelData
                width: lista.width
            }
        }
    }
}
