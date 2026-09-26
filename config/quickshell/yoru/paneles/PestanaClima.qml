// Pestaña de clima del panel central: ahora, próximas 12 horas y 7 días
import QtQuick
import qs.comun

Column {
    id: clima
    spacing: 10

    readonly property var diasSemana: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    function nombreDia(fecha, i) {
        if (i === 0) return "hoy";
        if (i === 1) return "mañana";
        return diasSemana[new Date(fecha + "T12:00").getDay()];
    }

    Texto {
        visible: !Tiempo.listo
        width: parent.width
        height: 120
        horizontalAlignment: Text.AlignHCenter
        text: "Cargando el tiempo…"
        font.bold: false
        color: Tema.gris
    }

    // ----------------------------------------------------------- Ahora
    Tarjeta {
        visible: Tiempo.listo
        width: parent.width
        height: 130

        Row {
            anchors { left: parent.left; leftMargin: 26; verticalCenter: parent.verticalCenter }
            spacing: 22
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: Tiempo.icono
                font.pixelSize: 64
                color: Tema.blanco
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Texto {
                    text: Tiempo.temperatura + "°C"
                    font.pixelSize: 38
                    color: Tema.blanco
                }
                Texto {
                    text: Tiempo.descripcion + " · " + Tiempo.lugar
                    font.bold: false
                    font.pixelSize: 13
                    color: Tema.gris
                }
            }
        }

        // Detalles a la derecha
        Grid {
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            columns: 2
            columnSpacing: 28
            rowSpacing: 10
            Repeater {
                model: [
                    {icono: "󰔏", texto: "Sensación " + Tiempo.sensacion + "°"},
                    {icono: "󰖎", texto: "Humedad " + Tiempo.humedad + "%"},
                    {icono: "󰖝", texto: "Viento " + Tiempo.viento + " km/h"},
                    {icono: "󰖜", texto: "Sale " + Tiempo.amanecer},
                    {icono: "󰖛", texto: "Se pone " + Tiempo.atardecer}
                ]
                Row {
                    required property var modelData
                    spacing: 8
                    Texto {
                        text: parent.modelData.icono
                        font.pixelSize: 15
                        color: Tema.texto
                    }
                    Texto {
                        text: parent.modelData.texto
                        font.bold: false
                        font.pixelSize: 12
                        color: Tema.texto
                    }
                }
            }
        }
    }

    // ------------------------------------------------ Próximas horas
    Tarjeta {
        visible: Tiempo.listo
        width: parent.width
        height: 104

        Row {
            anchors.centerIn: parent
            Repeater {
                model: Tiempo.horas
                Column {
                    required property var modelData
                    required property int index
                    width: (clima.width - 24) / 12
                    spacing: 6
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.index === 0 ? "ahora" : parent.modelData.hora
                        font.bold: false
                        font.pixelSize: 11
                        color: Tema.gris
                    }
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Tiempo.iconoDe(parent.modelData.codigo, parent.modelData.dia)
                        font.pixelSize: 22
                        color: Tema.blanco
                    }
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.temp + "°"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    // ------------------------------------------------------ 7 días
    Tarjeta {
        visible: Tiempo.listo
        width: parent.width
        height: dias.implicitHeight + 16

        Column {
            id: dias
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }

            Repeater {
                model: Tiempo.dias
                Item {
                    id: fila
                    required property var modelData
                    required property int index
                    width: dias.width
                    height: 36

                    Texto {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 120
                        text: clima.nombreDia(fila.modelData.fecha, fila.index)
                        font.pixelSize: 13
                        color: fila.index === 0 ? Tema.blanco : Tema.texto
                    }
                    Texto {
                        x: 160
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.iconoDe(fila.modelData.codigo, true)
                        font.pixelSize: 18
                        color: Tema.blanco
                    }
                    Texto {
                        x: 200
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.descripcionDe(fila.modelData.codigo)
                        font.bold: false
                        font.pixelSize: 12
                        color: Tema.gris
                    }
                    Texto {
                        x: 420
                        anchors.verticalCenter: parent.verticalCenter
                        visible: fila.modelData.lluvia > 0
                        text: "󰖌 " + fila.modelData.lluvia + "%"
                        font.bold: false
                        font.pixelSize: 12
                        color: Tema.gris
                    }
                    Texto {
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        text: fila.modelData.max + "°  " + "<font color='#8a8f98'>" + fila.modelData.min + "°</font>"
                        textFormat: Text.StyledText
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
