// ============================================================================
//  Escritorio — widgets sobre el fondo de pantalla, con cualquier estilo de
//  barra. Van por debajo de las ventanas: se ven en los escritorios vacíos.
//
//  En una columna a la derecha, a media pantalla:
//    la hora grande
//    cuatro tarjetas (disco, temperatura, memoria y CPU) que se llenan de
//    agua según el uso (comun/Agua.qml: se mece solo con el escritorio a la vista)
//    lo que suena, con anterior · play · siguiente (sin nada sonando, no sale)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.comun

Scope {
    id: escritorio
    required property ShellScreen modelData

    readonly property int margen: 18
    // Un poco más grande en pantallas grandes
    readonly property real escala: modelData.height >= 1000 ? 1.25 : 1

    // Disco: el de la raíz (/), cada minuto
    property real discoTotal: 0     // bytes
    property real discoUsado: 0
    Process {
        id: df
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (n.length === 2 && n[0] > 0) {
                    escritorio.discoTotal = n[0];
                    escritorio.discoUsado = n[1];
                }
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }
    function gigas(b) { return (b / 1073741824).toFixed(1) + "G"; }

    component Mono: Text {
        color: Tema.texto
        font.family: Tema.mono
        font.pixelSize: Math.round(11 * escritorio.escala)
        font.bold: true
    }

    // Tarjeta: icono arriba a la izquierda, nombre arriba a la derecha, y el
    // color subiendo desde abajo hasta «uso» (de 0 a 1)
    // Sin ventanas en esta pantalla: los widgets se ven (y el agua se mueve)
    readonly property bool aLaVista: Niri.ventanaEn(modelData.name) === null

    component Tarjeta: Rectangle {
        id: tarjeta
        property string icono: ""
        property string nombre: ""
        property string valor: ""
        property string detalle: ""
        property real uso: 0
        // El texto de abajo sobre el color: oscuro
        readonly property bool tapado: uso > 0.32

        width: Math.round(118 * escritorio.escala)
        height: Math.round(76 * escritorio.escala)
        radius: Math.round(14 * escritorio.escala)
        color: Tema.sombra(Math.max(0.75, Ajustes.opacidadIslas))

        // El uso, como agua que sube desde abajo (y ondea con el
        // escritorio a la vista)
        ClippingRectangle {
            anchors.fill: parent
            radius: tarjeta.radius
            color: "transparent"
            Agua {
                anchors.fill: parent
                nivel: tarjeta.uso
                color: Tema.blanco
                inclinacion: 2.5 * escritorio.escala
                moviendo: escritorio.aLaVista
            }
        }

        Text {
            x: Math.round(10 * escritorio.escala); y: Math.round(8 * escritorio.escala)
            text: tarjeta.icono
            font.family: Tema.mono
            font.pixelSize: Math.round(12 * escritorio.escala)
            color: tarjeta.uso > 0.82 ? Tema.oscuro : Tema.gris
        }
        Mono {
            anchors { right: parent.right; rightMargin: Math.round(10 * escritorio.escala) }
            y: Math.round(8 * escritorio.escala)
            text: tarjeta.nombre
            font.pixelSize: Math.round(9 * escritorio.escala)
            color: tarjeta.uso > 0.82 ? Tema.oscuro : Tema.gris
        }
        Mono {
            anchors { left: parent.left; leftMargin: Math.round(10 * escritorio.escala); bottom: parent.bottom; bottomMargin: Math.round(10 * escritorio.escala) }
            text: tarjeta.detalle
            font.pixelSize: Math.round(9 * escritorio.escala)
            color: tarjeta.tapado ? Tema.sombra(0.75) : Tema.gris
        }
        Mono {
            anchors { right: parent.right; rightMargin: Math.round(10 * escritorio.escala); bottom: parent.bottom; bottomMargin: Math.round(7 * escritorio.escala) }
            text: tarjeta.valor
            font.pixelSize: Math.round(17 * escritorio.escala)
            color: tarjeta.tapado ? Tema.oscuro : Tema.texto
        }
    }

    // Todo en una columna a la derecha (solo anclada a la derecha: la capa
    // queda centrada en alto)
    PanelWindow {
        screen: escritorio.modelData
        anchors { right: true }
        margins { right: escritorio.margen }
        implicitWidth: rejilla.width
        implicitHeight: columna.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "yoru-escritorio"
        WlrLayershell.layer: WlrLayer.Bottom

        SystemClock {
            id: reloj
            precision: SystemClock.Seconds
        }

        Column {
            id: columna
            spacing: Math.round(14 * escritorio.escala)

            Mono {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(reloj.date, Ajustes.reloj24 ? "HH:mm:ss" : "h:mm:ss")
                font.pixelSize: Math.round(26 * escritorio.escala)
                font.bold: false
                style: Text.Raised
                styleColor: Tema.sombra(0.4)
            }

            Grid {
                id: rejilla
                columns: 2
                spacing: Math.round(8 * escritorio.escala)

                Tarjeta {
                    icono: "󰋊"
                    nombre: escritorio.discoTotal > 0 ? escritorio.gigas(escritorio.discoTotal) : "Disco"
                    detalle: escritorio.discoTotal > 0 ? escritorio.gigas(escritorio.discoUsado) : ""
                    valor: escritorio.discoTotal > 0 ? Math.round(100 * escritorio.discoUsado / escritorio.discoTotal) + "%" : "–"
                    uso: escritorio.discoTotal > 0 ? escritorio.discoUsado / escritorio.discoTotal : 0
                }
                Tarjeta {
                    icono: "󰔏"
                    nombre: "Temp"
                    valor: Sistema.temperatura > 0 ? Sistema.temperatura + "°" : "–"
                    uso: Sistema.temperatura / 100
                }
                Tarjeta {
                    icono: "󰍛"
                    nombre: "RAM"
                    detalle: Sistema.memoria + "%"
                    valor: Sistema.memUsada.toFixed(1) + "G"
                    uso: Sistema.memoria / 100
                }
                Tarjeta {
                    icono: "󰘚"
                    nombre: "CPU"
                    valor: Sistema.cpu + "%"
                    uso: Sistema.cpu / 100
                }
            }

            // ---------------------------------------------------- Música
            // Solo con algo sonando (o en pausa)
            Item {
                id: musica
                visible: Ajustes.islaMusica && reproductor !== null
                width: tarjetaMusica.width
                height: tarjetaMusica.height
                readonly property var reproductor: Reproductor.actual
                readonly property string caratula: Reproductor.caratula(reproductor)

                Rectangle {
                    id: tarjetaMusica
                    readonly property int lado: Math.round(56 * escritorio.escala)
                    width: rejilla.width
                    height: lado + 2 * Math.round(12 * escritorio.escala)
                    radius: Math.round(16 * escritorio.escala)
                    color: Tema.sombra(Math.max(0.75, Ajustes.opacidadIslas))

                    // Carátula, o una nota
                    ClippingRectangle {
                        id: caja
                        x: Math.round(12 * escritorio.escala)
                        anchors.verticalCenter: parent.verticalCenter
                        width: tarjetaMusica.lado; height: tarjetaMusica.lado
                        radius: Math.round(10 * escritorio.escala)
                        color: Tema.claro(0.07)
                        Text {
                            anchors.centerIn: parent
                            visible: musica.caratula === ""
                            text: "󰝚"
                            font.family: Tema.mono
                            font.pixelSize: Math.round(22 * escritorio.escala)
                            color: Tema.texto
                        }
                        Image {
                            anchors.fill: parent
                            visible: musica.caratula !== ""
                            source: musica.caratula
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(width * 2, height * 2)
                            asynchronous: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Paneles.abrirPagina(escritorio.modelData, "multimedia", "centro")
                        }
                    }

                    Column {
                        anchors { left: caja.right; leftMargin: Math.round(12 * escritorio.escala); right: parent.right; rightMargin: Math.round(12 * escritorio.escala) }
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(8 * escritorio.escala)

                        Column {
                            width: parent.width
                            Mono {
                                width: parent.width
                                elide: Text.ElideRight
                                text: musica.reproductor ? (Reproductor.titulo(musica.reproductor) || Reproductor.nombre(musica.reproductor)) : "Nada sonando"
                            }
                            Mono {
                                width: parent.width
                                visible: text !== ""
                                elide: Text.ElideRight
                                text: musica.reproductor?.trackArtist ?? ""
                                font.bold: false
                                font.pixelSize: Math.round(9 * escritorio.escala)
                                color: Tema.gris
                            }
                        }

                        Row {
                            spacing: Math.round(6 * escritorio.escala)
                            Repeater {
                                model: [
                                    {icono: "󰒮", accion: "previous"},
                                    {icono: "", accion: "togglePlaying"},
                                    {icono: "󰒭", accion: "next"}
                                ]
                                Rectangle {
                                    id: boton
                                    required property var modelData
                                    width: Math.round(22 * escritorio.escala); height: width
                                    radius: Math.round(6 * escritorio.escala)
                                    color: botonRaton.containsMouse && musica.reproductor ? Tema.claro(0.14) : Tema.claro(0.07)
                                    Text {
                                        anchors.centerIn: parent
                                        text: boton.modelData.icono || (musica.reproductor?.isPlaying ? "󰏤" : "󰐊")
                                        font.family: Tema.mono
                                        font.pixelSize: Math.round(11 * escritorio.escala)
                                        color: musica.reproductor ? Tema.texto : Tema.tenue
                                    }
                                    MouseArea {
                                        id: botonRaton
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: musica.reproductor !== null
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: musica.reproductor[boton.modelData.accion]()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
