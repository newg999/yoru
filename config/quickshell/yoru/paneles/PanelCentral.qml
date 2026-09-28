// ============================================================================
//  Panel central — se abre al pulsar la música, el reloj o el clima
//
//  Pestañas: Multimedia · Resumen · Clima
//
//    Resumen:  ┌──────┬──────────────┬──────────────┐
//              │ hora │ clima        │ usuario      │
//              ├──────┼──────────────┴──┬───────────┤
//              │ cpu  │ calendario      │ música    │
//              │ temp │                 │           │
//              │ ram  │                 │           │
//              └──────┴─────────────────┴───────────┘
//    Multimedia: lo que suena, en grande (reproductor, salida, volumen)
//    Clima:      ahora, próximas horas y los 7 días
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Panel {
    id: panel
    nombre: "centro"
    lado: "centro"
    ancho: 780

    readonly property string pestana: ["multimedia", "clima"].includes(Paneles.seccion) ? Paneles.seccion : "resumen"
    onAbiertoChanged: {
        if (abierto) {
            calendario.volverAHoy();
            calendario.forceActiveFocus();
        }
    }

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
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
                    {id: "multimedia", icono: "󰝚", texto: "Multimedia"},
                    {id: "resumen", icono: "󰕮", texto: "Resumen"},
                    {id: "clima", icono: "󰖐", texto: "Clima"}
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
                        onClicked: Paneles.seccion = pestana.modelData.id
                    }
                }
            }
        }

        // ------------------------------------------------------- Resumen
        Column {
            id: resumen
            visible: panel.pestana === "resumen"
            width: parent.width
            spacing: 10

            readonly property int lateral: 130

            Row {
                width: parent.width
                height: 110
                spacing: 10

                // Hora grande
                Tarjeta {
                    width: resumen.lateral
                    height: parent.height
                    Column {
                        anchors.centerIn: parent
                        spacing: -6
                        Texto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(reloj.date, "HH")
                            font.pixelSize: 40
                            color: Tema.blanco
                        }
                        Texto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(reloj.date, "mm")
                            font.pixelSize: 40
                            color: Tema.blanco
                        }
                    }
                }

                // Clima
                Tarjeta {
                    width: (parent.width - resumen.lateral - 20) / 2
                    height: parent.height
                    color: climaRaton.containsMouse ? Tema.cajaHover : Tema.caja
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }

                    MouseArea {
                        id: climaRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Paneles.seccion = "clima"
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                        spacing: 18
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tiempo.listo ? Tiempo.icono : "󰖐"
                            font.pixelSize: 44
                            color: Tema.blanco
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Texto {
                                text: Tiempo.listo ? Tiempo.temperatura + "°C" : "—"
                                font.pixelSize: 26
                                color: Tema.blanco
                            }
                            Texto {
                                text: Tiempo.listo ? Tiempo.descripcion : "Cargando el tiempo…"
                                font.bold: false
                                font.pixelSize: 12
                                color: Tema.gris
                            }
                            Texto {
                                text: Tiempo.lugar
                                font.bold: false
                                font.pixelSize: 11
                                color: Tema.gris
                            }
                        }
                    }
                }

                // Usuario y tiempo encendido
                Tarjeta {
                    width: (parent.width - resumen.lateral - 20) / 2
                    height: parent.height
                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 16

                        Rectangle {
                            width: 64; height: 64; radius: 32
                            color: Tema.claro(0.10)
                            border.width: 2
                            border.color: Tema.claro(0.5)
                            Texto {
                                anchors.centerIn: parent
                                text: panel.usuario.charAt(0).toUpperCase()
                                font.pixelSize: 26
                                color: Tema.blanco
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Texto {
                                text: panel.usuario
                                font.pixelSize: 15
                                color: Tema.blanco
                            }
                            Texto {
                                text: "󰣛  Yoru · niri"
                                font.bold: false
                                font.pixelSize: 11
                                color: Tema.gris
                            }
                            Texto {
                                text: "󰔟  encendido " + panel.duracion(Sistema.encendido)
                                font.bold: false
                                font.pixelSize: 11
                                color: Tema.gris
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 300
                spacing: 10

                // CPU, temperatura y memoria en barras verticales
                Tarjeta {
                    width: resumen.lateral
                    height: parent.height
                    Row {
                        anchors.centerIn: parent
                        spacing: 18
                        Repeater {
                            model: [
                                {icono: "󰘚", valor: Sistema.cpu / 100, texto: Sistema.cpu + "%"},
                                {icono: "󰔏", valor: Math.min(1, Sistema.temperatura / 100), texto: Sistema.temperatura + "°"},
                                {icono: "󰍛", valor: Sistema.memoria / 100, texto: Sistema.memoria + "%"}
                            ]
                            Column {
                                id: medidor
                                required property var modelData
                                spacing: 8
                                Texto {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: medidor.modelData.texto
                                    font.pixelSize: 10
                                    color: Tema.gris
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 8; height: 200; radius: 4
                                    color: Tema.claro(0.12)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(parent.width, parent.height * medidor.modelData.valor)
                                        radius: parent.radius
                                        color: medidor.modelData.valor > 0.9 ? Tema.rojo : Tema.blanco
                                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    }
                                }
                                Texto {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: medidor.modelData.icono
                                    font.pixelSize: 16
                                }
                            }
                        }
                    }
                }

                Tarjeta {
                    width: parent.width - resumen.lateral - 250 - 20
                    height: parent.height
                    Calendario {
                        id: calendario
                        anchors { fill: parent; margins: 10 }
                    }
                }

                TarjetaMusica {
                    width: 250
                    height: parent.height
                    activa: panel.abierto && panel.pestana === "resumen"
                    onAmpliar: Paneles.seccion = "multimedia"
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

    // Nombre del usuario de la sesión
    readonly property string usuario: Quickshell.env("USER") ?? ""

    function duracion(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
}
