// ============================================================================
//  Barra minimalista — una franja fina de lado a lado (Ajustes › Barra y
//  dock › Minimalista). Lo mismo que la píldora, sin transformarse:
//
//    ━ • •  Ventana     ( ♪ Canción ⏮⏯⏭ )  14:02  󰖐 16°     󰘚 4% 󰍛 21% 󰔏 50°  󰅌 󰓓 󰂚  󰕾 󰖩 󰂯
//
//  Clic en un punto = ese escritorio · en la canción = Multimedia (⏮⏯⏭ =
//  cambiar o pausar sin abrir nada) · 󰅌 = lo copiado · en la
//  hora = calendario · en el tiempo = clima · en la CPU o la RAM = monitor ·
//  audio/red/bluetooth = el centro de control (un hueco libre cierra lo abierto)
//  Se abre debajo de lo pulsado: la hora y la canción en el centro; la conexión y los
//  avisos, a la derecha (paneles/PanelPaginas.qml, con las páginas de la píldora).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: barra

    required property ShellScreen modelData
    screen: modelData

    readonly property int alto: Tema.altoBarra + 2
    readonly property bool abierta: Paneles.abierto === "pildora" && Paneles.pantalla === modelData
    // El panel sale bajo lo que se pulsó: en el centro o a la derecha
    function abrir(pagina, lado) {
        Paneles.abrirPagina(modelData, pagina, lado);
    }

    visible: Ajustes.minimalista
    anchors { top: true; left: true; right: true }
    implicitHeight: alto
    // Con la minimalista, niri no deja huecos (Ajustes.niriVentanas): las
    // ventanas empiezan justo debajo
    exclusiveZone: alto
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : todo
    Region { id: todo; item: franja }

    IdleInhibitor {
        window: barra
        enabled: Despierto.activo
    }

    SystemClock {
        id: reloj
        precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes
    }

    Rectangle {
        id: franja
        width: parent.width
        height: barra.alto
        // El mismo fondo que los paneles: se abren pegados a ella (Panel.qml)
        color: Tema.panel

        opacity: Niri.overview ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }
        transform: Translate {
            y: Niri.overview ? -barra.alto : 0
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }

        // Clic en un hueco libre: cierra el panel que haya abierto (no abre nada)
        MouseArea {
            anchors.fill: parent
            onClicked: Paneles.cerrar()
        }


        // ------------------------------------------------- Izquierda
        Row {
            anchors { left: parent.left; leftMargin: Tema.margenLados; verticalCenter: parent.verticalCenter }
            spacing: 14

            Row {
                id: puntos
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: Niri.escritoriosDe(barra.modelData.name)
                    Rectangle {
                        id: punto
                        required property var modelData
                        readonly property bool activo: modelData.is_active
                        width: activo ? 20 : 8
                        height: 8
                        radius: 4
                        color: modelData.is_urgent ? Tema.rojo
                            : activo || puntoRaton.containsMouse ? Tema.blanco
                            : modelData.active_window_id !== null ? Tema.claro(0.5) : Tema.claro(0.25)
                        Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        MouseArea {
                            id: puntoRaton
                            anchors { fill: parent; margins: -4 }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Niri.irA(punto.modelData)
                            onWheel: e => Niri.accion(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
                        }
                    }
                }
            }

            // La ventana activa, en gris
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, barra.width / 2 - centro.width / 2 - puntos.width - 60)
                elide: Text.ElideRight
                text: Niri.ventanaEn(barra.modelData.name)?.title ?? ""
                font.bold: false
                color: Tema.gris
            }
        }

        // --------------------------------------------------- Centro
        // La hora y el tiempo, juntos en el centro; lo que suena, en su
        // cápsula a la izquierda (solo si hay un reproductor, también en pausa)
        Row {
            id: centro
            anchors.centerIn: parent
            spacing: 14

            Texto {
                id: horaTexto
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(reloj.date, (Ajustes.reloj24 ? "HH:mm" : "h:mm AP") + (Ajustes.relojSegundos ? ":ss" : ""))
                color: horaRaton.containsMouse ? Tema.blanco : Tema.texto
                MouseArea {
                    id: horaRaton
                    anchors { fill: parent; margins: -8 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barra.abrir("calendario", "centro")
                }
            }

            // El tiempo (clic = clima)
            Item {
                id: tiempo
                visible: Tiempo.listo
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: tiempoFila.implicitWidth
                implicitHeight: barra.alto
                Row {
                    id: tiempoFila
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.icono
                        font.pixelSize: Math.round(Tema.letra * 1.2)
                        color: tiempoRaton.containsMouse ? Tema.blanco : Tema.texto
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Tiempo.temperatura + "°"
                        color: tiempoRaton.containsMouse ? Tema.blanco : Tema.texto
                    }
                }
                MouseArea {
                    id: tiempoRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: barra.abrir("clima", "centro")
                }
            }
        }

        // La cápsula de la música: carátula, canción y ⏮⏯⏭ (clic = Multimedia)
        Rectangle {
            id: musica
            visible: Reproductor.actual !== null
            anchors { right: centro.left; rightMargin: 18; verticalCenter: parent.verticalCenter }
            width: musicaFila.implicitWidth + 2 * 5 + 6
            height: barra.alto - 8
            radius: height / 2
            color: musicaRaton.containsMouse ? Tema.claro(0.14) : Tema.claro(0.07)
            Behavior on color { ColorAnimation { duration: Tema.rapida } }

            MouseArea {
                id: musicaRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: barra.abrir("multimedia", "centro")
            }

            Row {
                id: musicaFila
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Carátula redonda (o una nota si el reproductor no manda)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: musica.height - 6
                    height: width
                    radius: width / 2
                    color: Tema.claro(0.10)
                    clip: true
                    Texto {
                        visible: caratula.status !== Image.Ready
                        anchors.centerIn: parent
                        text: "󰝚"
                        font.pixelSize: 11
                    }
                    Image {
                        id: caratula
                        anchors.fill: parent
                        source: Reproductor.caratula(Reproductor.actual)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(48, 48)
                    }
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 220)
                    elide: Text.ElideRight
                    text: Reproductor.titulo(Reproductor.actual) || Reproductor.nombre(Reproductor.actual)
                    color: musicaRaton.containsMouse ? Tema.blanco : Tema.texto
                }
                // Anterior · pausar / seguir · siguiente, sin abrir nada
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    BotonMusica {
                        icono: "󰒮"
                        onPulsado: Reproductor.actual?.previous()
                    }
                    BotonMusica {
                        icono: Reproductor.actual?.isPlaying ? "󰏤" : "󰐊"
                        onPulsado: Reproductor.actual?.togglePlaying()
                    }
                    BotonMusica {
                        icono: "󰒭"
                        onPulsado: Reproductor.actual?.next()
                    }
                }
            }
        }

        // -------------------------------------------------- Derecha
        Row {
            anchors { right: parent.right; rightMargin: Tema.margenLados - 6; verticalCenter: parent.verticalCenter }
            spacing: 0

            // Uso: CPU, RAM y temperatura (clic en CPU o RAM = monitor)
            Row {
                id: uso
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 10
                spacing: 12
                Repeater {
                    model: [
                        {icono: "󰘚", valor: Sistema.cpu + "%", alto: Sistema.cpu > 90, seccion: "rendimiento"},
                        {icono: "󰍛", valor: Sistema.memoria + "%", alto: Sistema.memoria > 90, seccion: "procesos"},
                        {icono: "󰔏", valor: Sistema.temperatura + "°", alto: Sistema.temperatura > 85, seccion: ""}
                    ]
                    Item {
                        id: dato
                        required property var modelData
                        readonly property color tinta: modelData.alto ? Tema.rojo : datoRaton.containsMouse ? Tema.blanco : Tema.texto
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: datoFila.implicitWidth
                        implicitHeight: barra.alto

                        Row {
                            id: datoFila
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Texto {
                                text: dato.modelData.icono
                                color: dato.tinta
                            }
                            Texto {
                                text: dato.modelData.valor
                                color: dato.tinta
                            }
                        }
                        // CPU y RAM: clic = monitor; la temperatura, solo se ve
                        MouseArea {
                            id: datoRaton
                            anchors.fill: parent
                            enabled: dato.modelData.seccion !== ""
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Paneles.alternar("monitor", barra.modelData, dato.modelData.seccion)
                        }
                    }
                }
            }

            // Portapapeles (lo copiado)
            Campana { cual: "portapapeles"; pantalla: barra.modelData; color: "transparent"; border.width: 0 }
            Bandeja { ventana: barra; color: "transparent"; border.width: 0 }
            Grabando { color: "transparent"; border.width: 0 }
            Jugando { color: "transparent"; border.width: 0 }
            Cafe { color: "transparent"; border.width: 0 }
            Novedades { pantalla: barra.modelData; color: "transparent"; border.width: 0 }
            Usb { pantalla: barra.modelData; color: "transparent"; border.width: 0 }
            // Solo si hay notificaciones sin leer (al abrir el panel se va) o con
            // «No molestar» puesto (la campana tachada, para no olvidarlo)
            Campana {
                cual: "notificaciones"
                pantalla: barra.modelData
                oculta: !Notificaciones.hayNuevas && !Notificaciones.noMolestar
                color: "transparent"
                border.width: 0
            }
            Bateria { pantalla: barra.modelData; color: "transparent"; border.width: 0 }

            // Audio, red y Bluetooth (solo lo activo): clic = el centro de
            // control, rueda = volumen
            Conexion {
                pantalla: barra.modelData
                soloActivo: true
                color: "transparent"
                border.width: 0
            }
        }
    }

    component BotonMusica: Texto {
        id: boton
        property string icono: ""
        signal pulsado()
        anchors.verticalCenter: parent.verticalCenter
        text: icono
        font.pixelSize: Math.round(Tema.letra * 1.15)
        color: botonRaton.containsMouse ? Tema.blanco : Tema.gris
        MouseArea {
            id: botonRaton
            anchors { fill: parent; margins: -4 }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
    }
}
