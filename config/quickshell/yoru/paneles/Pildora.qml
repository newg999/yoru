// ============================================================================
//  Píldora — la barra en una sola píldora arriba en el centro (Ajustes ›
//  Barra y dock › Píldora). Al pulsarla, la propia píldora crece hasta ser
//  el panel y su fila pasa a ser la cabecera:
//
//      cerrada:    ( ━ • •  14:02 )                         sin nada más
//                  ( ━ • • ▌▍▌ Canción ⏯ 14:02  󰓓 󰑋 󰂚 )   con música (clic =
//                                                          Multimedia), bandeja
//                                                          y avisos
//      abierta:    ( ━ • •        14:02       󰃭 󰝚 󰖐 󰍛 󰏘 󰸉 )   (sin los avisos)
//                  │ página: control · temas · fondos │
//                  ╰──────────────────────────────────╯
//
//    calendario (PaginaCalendario.qml) el mes (clic en la hora, ya abierta)
//    multimedia (PestanaMultimedia.qml) lo que suena, en grande (clic en la canción)
//    clima    (PestanaClima.qml)  ahora, próximas horas, 7 días y el lugar
//    control  (PaginaControl.qml) wifi, bluetooth, no molestar, modo juego,
//             volumen, accesos rápidos, lo que suena y las notificaciones
//    sistema  (PaginaSistema.qml) cpu, ram, temperatura, clima, memorias USB
//             y actualizaciones
//    temas    (PaginaTemas.qml)   las paletas de «yoru tema»
//    fondos   (PaginaFondos.qml)  los fondos en fila
//
//  Clic en un punto = ese escritorio · en el resto = abrir o cerrar · en la
//  hora, ya abierta = calendario ·
//  󰝚 󰖐 󰍛 󰏘 󰸉 = esa página (otra vez: volver a control) · Esc o clic fuera = cerrar
//  Desde fuera:  qs -c yoru ipc call panel alternar pildora control  (o calendario, multimedia, clima…)
//
//  Con la píldora, la barra de islas (barra/Barra.qml) no se ve: lo que
//  mostraba está en las páginas, y sus avisos (grabando, modo juego, no
//  suspender, actualizaciones, USB, notificaciones nuevas, batería) salen en
//  la propia píldora mientras duran.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.comun
import qs.barra

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    screen: modelData

    readonly property bool abierta: Paneles.abierto === "pildora" && Paneles.pantalla === modelData
    readonly property string pagina: paginas.pagina
    function ir(p) { paginas.ir(p); }

    // 0 = píldora · 1 = panel. Mientras se cierra, la ventana sigue a
    // pantalla completa (para que la animación quepa)
    property real progreso: abierta ? 1 : 0
    Behavior on progreso {
        NumberAnimation { duration: Ajustes.animaciones ? 340 : 0; easing.type: Easing.OutQuint }
    }
    readonly property bool desplegada: abierta || progreso > 0
    // El contenido entra en la segunda mitad (si no, se ve aplastado)
    readonly property real dentro: Math.max(0, progreso * 2 - 1)

    visible: Ajustes.pildora
    anchors { top: true; left: true; right: true }
    implicitHeight: desplegada ? modelData.height : Tema.margenBarra + Tema.altoBarra
    exclusiveZone: Tema.zonaBarra
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: abierta ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Cerrada, solo la píldora coge clics (el resto de la franja, a las
    // ventanas); con el overview, nada
    mask: Niri.overview ? vacia : desplegada ? null : soloPildora
    Region { id: vacia }
    Region { id: soloPildora; item: caja }

    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : desenfoque
    Region { id: desenfoque; item: caja; radius: caja.radius }

    // «No suspender» (lo hace la barra de islas, que aquí no se ve)
    IdleInhibitor {
        window: ventana
        enabled: Despierto.activo
    }

    // Clic fuera = cerrar
    MouseArea {
        anchors.fill: parent
        enabled: ventana.abierta
        onClicked: Paneles.cerrar()
    }

    SystemClock {
        id: reloj
        precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Paneles.cerrar()

        Rectangle {
            id: caja

            // Medidas: cerrada, cada cosa a continuación de la anterior
            // (sin huecos); abierta, escritorios a la izquierda, hora en el
            // centro y páginas y avisos a la derecha. Al abrirse, cada cosa
            // se desliza de un sitio al otro (x = mezcla de los dos)
            readonly property int margen: 14
            readonly property int hueco: 12
            // La música se va 1,5 s después de cerrar el reproductor (al
            // cambiar de canción a veces desaparece un momento y daba
            // saltos), y mientras se va guarda el último título
            // También en pausa (para poder seguir con ⏯); se va al cerrar el reproductor
            readonly property bool suena: Reproductor.actual !== null
            property bool conMusica: suena
            property string tituloMusica: ""
            onSuenaChanged: {
                if (suena) {
                    quitarMusica.stop();
                    conMusica = true;
                } else {
                    quitarMusica.restart();
                }
            }
            Timer {
                id: quitarMusica
                interval: 1500
                onTriggered: caja.conMusica = false
            }
            Binding {
                target: caja
                property: "tituloMusica"
                value: Reproductor.titulo(Reproductor.actual) || Reproductor.nombre(Reproductor.actual)
                when: caja.suena
                restoreMode: Binding.RestoreNone
            }
            // Lo que ocupan la música y los avisos (con su hueco), suave al
            // aparecer o irse
            property real anchoMusica: conMusica ? musicaFila.implicitWidth + hueco : 0
            Behavior on anchoMusica { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
            property real anchoAvisos: avisos.implicitWidth > 0 ? avisos.implicitWidth + hueco : 0
            Behavior on anchoAvisos { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

            readonly property real xMusica: margen + puntos.width + hueco
            readonly property real xReloj: xMusica + anchoMusica
            readonly property real anchoCerradaSuave: xReloj + reloj_.implicitWidth + anchoAvisos + margen
            // Multimedia y Clima, más anchas (son las pestañas del panel
            // central, hechas para más sitio); al cambiar de página, suave
            property real anchoAbierta: paginas.anchoPedido
            Behavior on anchoAbierta {
                enabled: ventana.abierta
                NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
            }
            readonly property real altoAbierta: Tema.altoBarra + 8 + paginas.height + 14
            function mezcla(cerrada, abierta) { return Math.round(cerrada + (abierta - cerrada) * ventana.progreso); }

            width: mezcla(anchoCerradaSuave, anchoAbierta)
            height: Math.round(Tema.altoBarra + (altoAbierta - Tema.altoBarra) * ventana.progreso)
            x: Math.round((ventana.width - width) / 2)
            y: Tema.margenBarra
            radius: Tema.altoBarra / 2 + (Tema.radioPanel - Tema.altoBarra / 2) * ventana.progreso

            // De isla (más transparente) a panel
            color: Tema.sombra(Ajustes.opacidadIslas + (Ajustes.opacidadPaneles - Ajustes.opacidadIslas) * ventana.progreso
                + (cabeceraRaton.containsMouse && !ventana.abierta ? 0.1 : 0))
            border.width: Tema.borde(1)
            border.color: Tema.claro(0.12 + 0.5 * ventana.progreso)
            clip: true

            // Con el overview se va hacia arriba, como la barra
            opacity: Niri.overview ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            transform: Translate {
                y: Niri.overview ? -(Tema.altoBarra + Tema.margenBarra) : 0
                Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
            }

            // Los clics dentro no cierran
            MouseArea {
                anchors.fill: parent
            }

            // ------------------------------------------------------ Cabecera
            Item {
                id: cabecera
                width: parent.width
                height: Tema.altoBarra

                // Clic en la cabecera = abrir o cerrar
                MouseArea {
                    id: cabeceraRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ventana.abierta ? Paneles.cerrar() : Paneles.alternar("pildora", ventana.modelData, "control")
                }

                // Escritorios: el activo, alargado
                Row {
                    id: puntos
                    x: caja.margen
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Repeater {
                        model: Niri.escritoriosDe(ventana.modelData.name)
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

                // Lo que suena, en medio: barritas (cava) y la canción. Clic =
                // Multimedia. Abierta no hace falta (está en la página control)
                Item {
                    id: musica
                    x: caja.xMusica
                    width: Math.max(0, caja.anchoMusica - caja.hueco)
                    height: parent.height
                    clip: true
                    visible: width > 0 && ventana.progreso < 1
                    opacity: 1 - ventana.progreso * 2

                    Row {
                        id: musicaFila
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    required property int index
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 4 + 10 * (Cava.niveles[index + 1] ?? 0)
                                    radius: 1.5
                                    color: musicaRaton.containsMouse ? Tema.blanco : Tema.texto
                                    Behavior on height { NumberAnimation { duration: 80 } }
                                }
                            }
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 240)
                            elide: Text.ElideRight
                            text: caja.tituloMusica
                            color: musicaRaton.containsMouse ? Tema.blanco : Tema.texto
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        }
                        // Pausar / seguir sin abrir nada
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Reproductor.actual?.isPlaying ? "󰏤" : "󰐊"
                            font.pixelSize: Math.round(Tema.letra * 1.15)
                            color: pausaRaton.containsMouse ? Tema.blanco : Tema.gris
                            MouseArea {
                                id: pausaRaton
                                anchors { fill: parent; margins: -6 }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Reproductor.actual?.togglePlaying()
                            }
                        }
                    }
                    MouseArea {
                        id: musicaRaton
                        z: -1      // debajo del ⏯
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ventana.ir("multimedia")
                    }
                }

                Texto {
                    id: reloj_
                    x: caja.mezcla(caja.xReloj, (caja.anchoAbierta - implicitWidth) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(reloj.date, (Ajustes.reloj24 ? "HH:mm" : "h:mm AP") + (Ajustes.relojSegundos ? ":ss" : ""))
                    color: Tema.blanco
                    // Clic en la hora: cerrada, abre el panel (como el resto de
                    // la píldora); abierta, el calendario (otra vez: volver)
                    MouseArea {
                        anchors { fill: parent; margins: -6 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ventana.abierta ? ventana.ir("calendario")
                            : Paneles.alternar("pildora", ventana.modelData, "control")
                    }
                }

                // A la derecha: avisos y, al abrirse, las páginas
                // Avisos, solo cuando pasan: las islas de la barra, sin
                // su fondo (clic = su panel)
                Row {
                    id: avisos
                    // Cerrada, tras la hora. Al abrirse se desvanecen y dejan
                    // sitio a las páginas (lo que avisan está dentro:
                    // notificaciones en control, actualizaciones en sistema)
                    x: caja.xReloj + reloj_.implicitWidth + caja.hueco
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Math.max(0, 1 - ventana.progreso * 2)
                    visible: opacity > 0
                    spacing: 0
                    // Las apps de la bandeja (Steam, Discord...): clic = su
                    // app · clic derecho = su menú
                    Bandeja { ventana: ventana; color: "transparent"; border.width: 0 }
                    Grabando { color: "transparent"; border.width: 0 }
                    Jugando { color: "transparent"; border.width: 0 }
                    Cafe { color: "transparent"; border.width: 0 }
                    Novedades { pantalla: ventana.modelData; color: "transparent"; border.width: 0 }
                    Usb { pantalla: ventana.modelData; color: "transparent"; border.width: 0 }
                    // Solo si hay notificaciones (con el punto si alguna es nueva)
                    Campana {
                        cual: "notificaciones"
                        pantalla: ventana.modelData
                        oculta: Notificaciones.cuantas === 0
                        color: "transparent"
                        border.width: 0
                    }
                    Bateria { pantalla: ventana.modelData; color: "transparent"; border.width: 0 }
                }

                // Páginas: crecen al abrirse
                Row {
                    id: iconos
                    x: caja.anchoAbierta - caja.margen - width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: ventana.progreso > 0
                    opacity: ventana.dentro
                    Repeater {
                        model: [
                            {id: "multimedia", icono: "󰝚"},
                            {id: "clima", icono: "󰖐"},
                            {id: "sistema", icono: "󰍛"},
                            {id: "temas", icono: "󰏘"},
                            {id: "fondos", icono: "󰸉"}
                        ]
                        Rectangle {
                            id: icono
                            required property var modelData
                            readonly property bool elegida: ventana.pagina === modelData.id
                            width: 26; height: 22; radius: 11
                            color: elegida ? Tema.blanco : iconoRaton.containsMouse ? Tema.cajaHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            Texto {
                                anchors.centerIn: parent
                                text: icono.modelData.icono
                                font.pixelSize: 13
                                color: icono.elegida ? Tema.oscuro : Tema.texto
                            }
                            MouseArea {
                                id: iconoRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ventana.ir(icono.modelData.id)
                            }
                        }
                    }
                }

            }

            // ------------------------------------------------------- Páginas
            Paginas {
                id: paginas
                x: 14
                y: Tema.altoBarra + 8
                width: caja.anchoAbierta - 28
                pantalla: ventana.modelData
                abierta: ventana.abierta
                visible: ventana.progreso > 0
                opacity: ventana.dentro
            }
        }
    }
}
