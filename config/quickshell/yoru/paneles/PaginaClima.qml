// ============================================================================
//  Página «clima» de las islas (el tiempo), con el aspecto del panel del
//  tiempo del dock (el antiguo estilo Dock). Los datos: comun/Tiempo.qml
//
//    ‹ Clima                                  ⟳
//    ┌──────────────────────────────────────┐
//    │ (☁)  19°  22° / 12°                  │
//    │      Nublado                          │     clic en el lugar = elegir
//    │      󰍎 Madrid  󰏫                      │     otro (buscar o por la IP)
//    └──────────────────────────────────────┘
//    [Sensación] [Humedad] [Viento] [Sol]
//    PRÓXIMAS HORAS   (se desliza de lado)
//    7 DÍAS           con la barra de la mínima a la máxima
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

FocusScope {
    id: pagina

    property bool activa: false
    property int altoMax: 700
    property bool eligiendo: false          // buscando otro lugar
    property var resultados: []
    onActivaChanged: {
        eligiendo = false;
        if (activa)
            forceActiveFocus();
    }
    Keys.onEscapePressed: e => {
        if (eligiendo) eligiendo = false;
        else Paneles.atras();
    }

    readonly property color acento: Tema.blanco
    function tinte(a) { return Tema.conAlfa(acento, a); }

    function nombreDia(i, fecha) {
        if (i === 0) return "Hoy";
        if (i === 1) return "Mañana";
        const d = new Date(fecha + "T12:00:00");
        const n = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"][d.getDay()];
        return isNaN(d) ? fecha : n;
    }

    implicitHeight: columna.implicitHeight

    // Un recuadro de los del dock
    component Caja: Rectangle {
        radius: Tema.esquina(16)
        color: Tema.caja
        border.width: 1
        border.color: Tema.claro(0.08)
    }
    component Titulo: Texto {
        x: 2
        font.pixelSize: 11
        font.letterSpacing: 1.6
        color: Tema.gris
    }

    Column {
        id: columna
        width: parent.width
        spacing: 12

        // ------------------------------------------------------ Cabecera
        Item {
            width: parent.width
            height: 26
            Texto {
                id: atras
                width: 26; height: 26
                horizontalAlignment: Text.AlignHCenter
                text: "󰅁"
                font.pixelSize: 20
                color: atrasRaton.containsMouse ? pagina.acento : Tema.texto
                scale: atrasRaton.pressed ? 0.85 : atrasRaton.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
                MouseArea {
                    id: atrasRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pagina.eligiendo ? pagina.eligiendo = false : Paneles.atras()
                }
            }
            Texto {
                anchors { left: atras.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: pagina.eligiendo ? "Elegir lugar" : "Clima"
                font.pixelSize: 16
                color: Tema.blanco
            }
            Texto {
                id: refrescar
                anchors.right: parent.right
                width: 26; height: 26
                horizontalAlignment: Text.AlignHCenter
                text: "󰑐"
                font.pixelSize: 18
                color: refrescarRaton.containsMouse ? pagina.acento : Tema.gris
                RotationAnimation on rotation { id: giro; running: false; from: 0; to: 360; duration: 900 }
                MouseArea {
                    id: refrescarRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        giro.restart();
                        Tiempo.actualizar();
                    }
                }
            }
        }

        // ================================================== El tiempo
        Column {
            visible: !pagina.eligiendo
            width: parent.width
            spacing: 12

            Texto {
                visible: !Tiempo.listo
                width: parent.width
                height: 60
                horizontalAlignment: Text.AlignHCenter
                text: "Mirando el tiempo…"
                font.bold: false
                color: Tema.gris
            }

            // ---------------------------- Ahora: icono, temperatura, lugar
            Rectangle {
                visible: Tiempo.listo
                width: parent.width
                height: 92
                radius: Tema.esquina(18)
                color: pagina.tinte(0.13)
                border.width: 1
                border.color: pagina.tinte(0.35)
                Rectangle {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52; height: 52; radius: 26
                    color: pagina.acento
                    Texto {
                        anchors.centerIn: parent
                        text: Tiempo.icono
                        font.family: Tema.mono
                        font.pixelSize: 28
                        color: Tema.oscuro
                    }
                }
                Column {
                    x: 80
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 80 - 14
                    spacing: 1
                    Row {
                        spacing: 8
                        Texto {
                            id: grados
                            text: Tiempo.temperatura + "°"
                            font.pixelSize: 30
                            color: Tema.blanco
                        }
                        Texto {
                            anchors.baseline: grados.baseline
                            text: Tiempo.dias.length ? Tiempo.dias[0].max + "° / " + Tiempo.dias[0].min + "°" : ""
                            font.bold: false
                            font.pixelSize: 11
                            color: Tema.texto
                        }
                    }
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Tiempo.descripcion
                        font.pixelSize: 12
                        color: Tema.texto
                    }
                    // El lugar: clic = elegir otro
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "󰍎 " + (Tiempo.lugar || "—") + "  󰏫"
                        font.bold: false
                        font.pixelSize: 11
                        color: lugarRaton.containsMouse ? pagina.acento : Tema.texto
                        MouseArea {
                            id: lugarRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pagina.eligiendo = true
                        }
                    }
                }
            }

            // ------------------------ Sensación, humedad, viento y el sol
            Row {
                visible: Tiempo.listo
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        {icono: "󰔏", valor: Tiempo.sensacion + "°", nombre: "Sensación"},
                        {icono: "󰖎", valor: Tiempo.humedad + "%", nombre: "Humedad"},
                        {icono: "󰖝", valor: Tiempo.viento + " km/h", nombre: "Viento"},
                        {icono: Tiempo.deDia ? "󰖛" : "󰖜", valor: Tiempo.deDia ? Tiempo.atardecer : Tiempo.amanecer,
                         nombre: Tiempo.deDia ? "Se pone" : "Sale"}
                    ]
                    Caja {
                        required property var modelData
                        width: (columna.width - 24) / 4
                        height: 62
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.icono
                                font.pixelSize: 14
                                color: pagina.acento
                            }
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.valor
                                font.pixelSize: 12
                                color: Tema.blanco
                            }
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData.nombre
                                font.bold: false
                                font.pixelSize: 9
                                color: Tema.gris
                            }
                        }
                    }
                }
            }

            // ------------------------------------------ Próximas horas
            Titulo {
                visible: Tiempo.listo && Tiempo.horas.length > 0
                text: "PRÓXIMAS HORAS"
            }
            Caja {
                visible: Tiempo.listo && Tiempo.horas.length > 0
                width: parent.width
                height: 84
                ListView {
                    anchors { fill: parent; margins: 6 }
                    orientation: ListView.Horizontal
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Tiempo.horas
                    delegate: Item {
                        id: hora
                        required property var modelData
                        required property int index
                        width: 50
                        height: 72
                        Rectangle {
                            anchors.fill: parent
                            radius: Tema.esquina(12)
                            visible: hora.index === 0
                            color: pagina.tinte(0.16)
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hora.index === 0 ? "Ahora" : hora.modelData.hora
                                font.bold: false
                                font.pixelSize: 10
                                color: hora.index === 0 ? pagina.acento : Tema.gris
                            }
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Tiempo.iconoDe(hora.modelData.codigo, hora.modelData.dia)
                                font.family: Tema.mono
                                font.pixelSize: 18
                                color: Tema.texto
                            }
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hora.modelData.temp + "°"
                                font.pixelSize: 12
                                color: Tema.blanco
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------ Siete días
            Titulo {
                visible: Tiempo.listo && Tiempo.dias.length > 0
                text: "7 DÍAS"
            }
            Column {
                id: semana
                visible: Tiempo.listo
                width: parent.width
                readonly property int tMin: Tiempo.dias.length ? Math.min(...Tiempo.dias.map(d => d.min)) : 0
                readonly property int tMax: Tiempo.dias.length ? Math.max(...Tiempo.dias.map(d => d.max)) : 1
                Repeater {
                    model: Tiempo.dias
                    Rectangle {
                        id: dia
                        required property var modelData
                        required property int index
                        width: semana.width
                        height: 36
                        radius: Tema.esquina(12)
                        color: index === 0 ? pagina.tinte(0.10) : diaRaton.containsMouse ? Tema.caja : "transparent"
                        MouseArea { id: diaRaton; anchors.fill: parent; hoverEnabled: true }
                        Texto {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 80
                            elide: Text.ElideRight
                            text: pagina.nombreDia(dia.index, dia.modelData.fecha)
                            font.pixelSize: 12
                            color: dia.index === 0 ? pagina.acento : Tema.texto
                        }
                        Texto {
                            x: 94
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tiempo.iconoDe(dia.modelData.codigo, true)
                            font.family: Tema.mono
                            font.pixelSize: 17
                            color: Tema.texto
                        }
                        Texto {
                            x: 120
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            text: dia.modelData.lluvia >= 10 ? dia.modelData.lluvia + "%" : ""
                            font.bold: false
                            font.pixelSize: 10
                            color: Tema.gris
                        }
                        Texto {
                            x: 156
                            width: 28
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                            text: dia.modelData.min + "°"
                            font.bold: false
                            font.pixelSize: 11
                            color: Tema.gris
                        }
                        // La barra de la semana: de la más fría a la más cálida
                        Rectangle {
                            id: pista
                            x: 192
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 192 - 44
                            height: 5
                            radius: 2.5
                            color: Tema.claro(0.08)
                            readonly property real k: width / Math.max(1, semana.tMax - semana.tMin)
                            Rectangle {
                                x: (dia.modelData.min - semana.tMin) * pista.k
                                width: Math.max(6, (dia.modelData.max - dia.modelData.min) * pista.k)
                                height: parent.height
                                radius: 2.5
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: pagina.tinte(0.45) }
                                    GradientStop { position: 1; color: pagina.acento }
                                }
                            }
                        }
                        Texto {
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: dia.modelData.max + "°"
                            font.pixelSize: 12
                            color: Tema.blanco
                        }
                    }
                }
            }
        }

        // ============================================ Elegir el lugar
        Column {
            visible: pagina.eligiendo
            width: parent.width
            spacing: 10
            onVisibleChanged: {
                if (visible) {
                    busqueda.text = "";
                    pagina.resultados = [];
                    busqueda.forceActiveFocus();
                }
            }

            Rectangle {
                width: parent.width
                height: 40
                radius: Tema.esquina(14)
                color: Tema.sombra(0.5)
                border.width: 1
                border.color: busqueda.activeFocus ? pagina.tinte(0.6) : Tema.claro(0.12)
                Texto {
                    id: lupa
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    font.pixelSize: 16
                    color: pagina.acento
                }
                TextInput {
                    id: busqueda
                    anchors { left: lupa.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    color: Tema.blanco
                    selectionColor: Tema.claro(0.3)
                    font.family: Tema.fuente
                    font.pixelSize: 13
                    clip: true
                    // Se busca al dejar de escribir un momento
                    onTextChanged: espera.restart()
                    Timer {
                        id: espera
                        interval: 350
                        onTriggered: {
                            const t = busqueda.text.trim();
                            if (t.length < 2)
                                pagina.resultados = [];
                            else
                                Tiempo.buscar(t, r => pagina.resultados = r);
                        }
                    }
                    function elegir(l) {
                        Tiempo.elegir(l.nombre, l.latitud, l.longitud);
                        pagina.eligiendo = false;
                    }
                    Keys.onReturnPressed: if (pagina.resultados.length) elegir(pagina.resultados[0])
                    Keys.onEnterPressed: if (pagina.resultados.length) elegir(pagina.resultados[0])
                    Keys.onEscapePressed: pagina.eligiendo = false
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: busqueda.text.length === 0
                        text: "Busca tu ciudad…"
                        font.bold: false
                        font.pixelSize: 13
                        color: Tema.gris
                    }
                }
            }

            // Usar la conexión a internet
            Rectangle {
                width: parent.width
                height: 50
                radius: Tema.esquina(14)
                color: Tiempo.automatico ? pagina.tinte(0.13) : ipRaton.containsMouse ? Tema.cajaHover : Tema.caja
                border.width: 1
                border.color: Tiempo.automatico ? pagina.tinte(0.35) : Tema.claro(0.08)
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
                Texto {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰆤"
                    font.pixelSize: 17
                    color: pagina.acento
                }
                Column {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Texto {
                        text: "Usar mi ubicación"
                        font.pixelSize: 12
                        color: Tema.blanco
                    }
                    Texto {
                        text: Tiempo.automatico ? "Ahora mismo: " + Tiempo.lugar : "Se adivina por tu conexión"
                        font.bold: false
                        font.pixelSize: 10
                        color: Tema.gris
                    }
                }
                MouseArea {
                    id: ipRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Tiempo.porIp();
                        pagina.eligiendo = false;
                    }
                }
            }

            Titulo {
                visible: pagina.resultados.length > 0
                text: "RESULTADOS"
            }
            Texto {
                visible: pagina.resultados.length === 0 && busqueda.text.trim().length >= 2 && !espera.running
                text: "No encuentro ningún sitio así"
                font.bold: false
                font.pixelSize: 11
                color: Tema.gris
            }
            Repeater {
                model: pagina.resultados
                Rectangle {
                    id: sitio
                    required property var modelData
                    width: columna.width
                    height: 46
                    radius: Tema.esquina(14)
                    color: sitioRaton.containsMouse ? Tema.caja : "transparent"
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    Texto {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍎"
                        font.pixelSize: 16
                        color: pagina.acento
                    }
                    Column {
                        x: 40
                        width: parent.width - 52
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Texto {
                            width: parent.width
                            elide: Text.ElideRight
                            text: sitio.modelData.nombre
                            textFormat: Text.PlainText
                            font.pixelSize: 13
                            color: Tema.blanco
                        }
                        Texto {
                            width: parent.width
                            elide: Text.ElideRight
                            text: sitio.modelData.zona
                            textFormat: Text.PlainText
                            font.bold: false
                            font.pixelSize: 10
                            color: Tema.gris
                        }
                    }
                    MouseArea {
                        id: sitioRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: busqueda.elegir(sitio.modelData)
                    }
                }
            }
        }
    }
}
