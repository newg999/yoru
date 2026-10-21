// Pestaña de clima del panel central: ahora, próximas 12 horas y 7 días.
// Clic en el lugar (󰍎 Madrid) = buscar otro (o volver a adivinarlo por la IP)
import QtQuick
import qs.comun

Column {
    id: clima
    spacing: 10

    property bool buscando: false
    property var resultados: []
    property bool esperando: false
    property string buscado: ""

    function abrirBuscador() {
        buscando = true;
        resultados = [];
        buscado = "";
        campo.text = "";
        campo.forceActiveFocus();
    }
    function buscar() {
        const t = campo.text.trim();
        if (t.length < 2)
            return;
        esperando = true;
        buscado = t;
        Tiempo.buscar(t, r => {
            if (t !== clima.buscado)
                return;
            clima.resultados = r;
            clima.esperando = false;
        });
    }
    function elegirPrimero() {
        if (resultados.length > 0)
            elegir(resultados[0]);
    }
    function elegir(l) {
        Tiempo.elegir(l.nombre, l.latitud, l.longitud);
        buscando = false;
    }
    // Se escribe y busca solo al parar 400 ms
    Timer {
        id: pausa
        interval: 400
        onTriggered: clima.buscar()
    }

    readonly property var diasSemana: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    function nombreDia(fecha, i) {
        if (i === 0) return "hoy";
        if (i === 1) return "mañana";
        return diasSemana[new Date(fecha + "T12:00").getDay()];
    }

    // -------------------------------------------------- Cambiar lugar
    Tarjeta {
        visible: clima.buscando
        width: parent.width
        height: buscador.implicitHeight + 20

        Column {
            id: buscador
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 4

            Rectangle {
                width: parent.width
                height: 42
                radius: 10
                color: Tema.claro(0.04)
                border.width: 1
                border.color: campo.activeFocus ? Tema.claro(0.5) : Tema.claro(0.1)

                Texto {
                    id: lupa
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    font.pixelSize: 17
                    color: Tema.gris
                }
                TextInput {
                    id: campo
                    anchors { left: lupa.right; leftMargin: 12; right: cerrar.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    color: Tema.texto
                    selectionColor: Tema.claro(0.3)
                    font.family: Tema.fuente
                    font.pixelSize: 14
                    clip: true
                    onTextChanged: pausa.restart()
                    Keys.onReturnPressed: clima.elegirPrimero()
                    Keys.onEnterPressed: clima.elegirPrimero()
                    Keys.onEscapePressed: clima.buscando = false

                    Texto {
                        visible: campo.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar tu ciudad…"
                        font.bold: false
                        font.pixelSize: 14
                        color: Tema.gris
                    }
                }
                Texto {
                    id: cerrar
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "󰅖"
                    font.pixelSize: 16
                    color: cerrarRaton.containsMouse ? Tema.blanco : Tema.gris
                    MouseArea {
                        id: cerrarRaton
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clima.buscando = false
                    }
                }
            }

            Texto {
                visible: clima.buscado !== "" && !clima.esperando && clima.resultados.length === 0
                width: parent.width
                height: 36
                leftPadding: 14
                verticalAlignment: Text.AlignVCenter
                text: "No encuentro «" + clima.buscado + "»"
                font.bold: false
                font.pixelSize: 13
                color: Tema.gris
            }

            Repeater {
                model: clima.resultados
                FilaLugar {
                    required property var modelData
                    required property int index
                    icono: "󰍎"
                    texto: modelData.nombre
                    detalle: modelData.zona
                    resaltada: index === 0
                    onClic: clima.elegir(modelData)
                }
            }

            FilaLugar {
                icono: "󰆤"
                texto: "Usar mi ubicación"
                detalle: "Se adivina por tu conexión a internet"
                marcada: Tiempo.automatico
                onClic: {
                    Tiempo.porIp();
                    clima.buscando = false;
                }
            }
        }
    }

    component FilaLugar: Rectangle {
        id: fila
        property string icono: ""
        property string texto: ""
        property string detalle: ""
        property bool resaltada: false   // la que se elige con Enter
        property bool marcada: false
        signal clic()

        width: buscador.width
        height: 36
        radius: 8
        color: filaRaton.containsMouse || resaltada ? Tema.cajaHover : "transparent"
        Behavior on color { ColorAnimation { duration: Tema.rapida } }

        Row {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 12
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: fila.icono
                font.pixelSize: 15
                color: Tema.gris
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: fila.texto
                font.pixelSize: 13
                color: Tema.blanco
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: fila.detalle
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
        }
        Texto {
            visible: fila.marcada
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            text: "󰄬"
            font.pixelSize: 15
            color: Tema.blanco
        }
        MouseArea {
            id: filaRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fila.clic()
        }
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
                    text: Tiempo.descripcion
                    font.bold: false
                    font.pixelSize: 13
                    color: Tema.gris
                }
                // El lugar: clic para cambiarlo
                Item { width: 1; height: 6 }
                Rectangle {
                    width: lugarFila.implicitWidth + 20
                    height: 26
                    radius: 8
                    color: lugarRaton.containsMouse || clima.buscando ? Tema.cajaHover : Tema.claro(0.06)
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    Row {
                        id: lugarFila
                        anchors.centerIn: parent
                        spacing: 6
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍎"
                            font.pixelSize: 13
                            color: Tema.gris
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tiempo.lugar || "Elegir lugar"
                            font.pixelSize: 12
                            color: Tema.texto
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰏫"
                            font.pixelSize: 12
                            color: Tema.gris
                        }
                    }
                    MouseArea {
                        id: lugarRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clima.buscando ? clima.buscando = false : clima.abrirBuscador()
                    }
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
                        text: fila.modelData.max + "°  " + "<font color='" + Tema.gris + "'>" + fila.modelData.min + "°</font>"
                        textFormat: Text.StyledText
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
