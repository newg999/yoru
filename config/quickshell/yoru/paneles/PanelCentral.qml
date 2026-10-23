// ============================================================================
//  Panel central — se abre al pulsar la música, el reloj o el clima
//
//  Pestañas: Resumen · Multimedia · Clima · Ajustes
//
//    Resumen:  ┌────────────┐               ┌────────────┐
//              │ calendario │   ╭╌ 15:00 ╌╮  │ ‹  HOY  ›  │
//              │            │   12:45:06    │   18°C     │
//              │            │   ╰╌ 03:00 ╌╯  │ viento ... │
//              └────────────┘               └────────────┘
//              (RelojOrbita: la hora y el tiempo de las próximas 24 h;
//               ClimaDias: el tiempo de hoy y de los 6 días siguientes)
//    Multimedia: lo que suena, en grande (reproductor, salida, volumen)
//    Clima:      ahora, próximas horas y los 7 días
//    Ajustes:    no es una pestaña: abre la ventana de Ajustes
//                (VentanaAjustes.qml) y cierra el panel
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Panel {
    id: panel
    nombre: "centro"
    lado: "centro"
    ancho: pestana === "resumen" ? 1100 : 780

    readonly property string pestana: ["multimedia", "clima"].includes(Paneles.seccion) ? Paneles.seccion : "resumen"
    onAbiertoChanged: {
        if (abierto) {
            calendario.volverAHoy();
            calendario.forceActiveFocus();
            climaDias.volverAHoy();
        }
    }

    Column {
        width: parent.width
        spacing: 14

        // ------------------------------------------------------ Pestañas
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: [
                    {id: "resumen", icono: "󰕮", texto: "Resumen"},
                    {id: "multimedia", icono: "󰝚", texto: "Multimedia"},
                    {id: "clima", icono: "󰖐", texto: "Clima"},
                    {id: "ajustes", icono: "󰒓", texto: "Ajustes"}
                ]
                Rectangle {
                    id: pestana
                    required property var modelData
                    readonly property bool elegida: panel.pestana === modelData.id
                    width: 150; height: 36; radius: 10
                    color: elegida ? Tema.claro(0.90) : pestanaRaton.containsMouse ? Tema.cajaHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Texto {
                            text: pestana.modelData.icono
                            font.pixelSize: 16
                            color: pestana.elegida ? Tema.oscuro : Tema.texto
                        }
                        Texto {
                            text: pestana.modelData.texto
                            font.pixelSize: 13
                            color: pestana.elegida ? Tema.oscuro : Tema.texto
                        }
                    }
                    MouseArea {
                        id: pestanaRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pestana.modelData.id === "ajustes")
                                Paneles.alternar("ajustes", panel.modelData, "");
                            else
                                Paneles.seccion = pestana.modelData.id;
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------- Resumen
        Row {
            visible: panel.pestana === "resumen"
            width: parent.width
            height: 360
            spacing: 10

            Tarjeta {
                width: 300
                height: parent.height
                Calendario {
                    id: calendario
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
                    height: 272
                }
            }

            RelojOrbita {
                width: parent.width - 300 - 290 - 20
                height: parent.height
                activo: panel.abierto && panel.pestana === "resumen"
            }

            Tarjeta {
                width: 290
                height: parent.height
                ClimaDias {
                    id: climaDias
                    anchors { fill: parent; margins: 14 }
                }
            }
        }

        // ---------------------------------------------------- Multimedia
        PestanaMultimedia {
            visible: panel.pestana === "multimedia"
            activa: panel.abierto && visible
            width: parent.width
        }

        // --------------------------------------------------------- Clima
        PestanaClima {
            visible: panel.pestana === "clima"
            width: parent.width
        }
    }
}
