// ============================================================================
//  Pestaña Sonido de Ajustes — por dónde suena y por dónde te oyen
//
//    Salida:    volumen y el dispositivo (altavoces, auriculares, HDMI...)
//    Micrófono: volumen, el dispositivo y una barra que se mueve al hablar
//    Apps:      el volumen de cada app que está sonando ahora
//    Al grabar la pantalla: con el sonido de las apps o con el micrófono
//
//  Todo va directo a PipeWire (Quickshell.Services.Pipewire): no se guarda
//  nada aparte, WirePlumber recuerda lo elegido.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.comun

Item {
    id: pestana

    property bool activa: false

    // Las apps que están sacando sonido (no las que graban, como cava o el
    // medidor del micrófono de aquí abajo: esas son Stream/Input/Audio)
    readonly property var apps: Pipewire.nodes.values.filter(n => n.audio && n.isStream
        && n.properties?.["media.class"] === "Stream/Output/Audio")

    implicitHeight: columnas.height

    function nombreApp(n) {
        const p = n.properties ?? {};
        return p["application.name"] || p["media.name"] || n.description || n.name;
    }

    PwObjectTracker { objects: pestana.apps }

    Row {
        id: columnas
        width: parent.width
        spacing: 16
        readonly property real mitad: (width - spacing) / 2

        // ---------------------------------------------- Salida y micrófono
        Column {
            width: columnas.mitad
            spacing: 2

            SeccionAudio {
                width: parent.width
                volumen: true
            }

            Item { width: 1; height: 10 }
            SeccionAudio {
                width: parent.width
                entrada: true
                volumen: true
            }

            // Nivel del micrófono: habla y se mueve
            Item {
                width: parent.width
                height: 34

                PwNodePeakMonitor {
                    id: nivel
                    node: Pipewire.defaultAudioSource
                    enabled: pestana.activa
                }

                Texto {
                    id: etiquetaNivel
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "Nivel"
                    font.pixelSize: 12
                    color: Tema.gris
                }
                Rectangle {
                    anchors {
                        left: etiquetaNivel.right; leftMargin: 14
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    height: 6
                    radius: 3
                    color: Tema.claro(0.08)

                    Rectangle {
                        height: parent.height
                        radius: 3
                        // Raíz cuadrada: así la voz normal llega a media barra
                        width: parent.width * Math.min(1, Math.sqrt(nivel.peak))
                        color: nivel.peak > 0.8 ? Tema.amarillo : Tema.blanco
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                }
            }

            // Al grabar la pantalla (Mod+Alt+R): wf-recorder graba una sola
            // fuente, así que es o lo que suena o el micrófono
            Item { width: 1; height: 10 }
            Titular { texto: "Al grabar la pantalla"; width: parent.width }
            Interruptor {
                width: parent.width
                titulo: "Grabar lo que suena"
                detalle: "El sonido de las apps (vídeos, juegos...)"
                activo: Ajustes.grabarSonido
                onCambiar: v => {
                    Ajustes.grabarSonido = v;
                    if (v)
                        Ajustes.grabarMicro = false;
                }
            }
            Interruptor {
                width: parent.width
                titulo: "Grabar el micrófono"
                detalle: "Tu voz, en lugar del sonido de las apps"
                activo: Ajustes.grabarMicro
                onCambiar: v => {
                    Ajustes.grabarMicro = v;
                    if (v)
                        Ajustes.grabarSonido = false;
                }
            }
        }

        // ------------------------------------------------------------ Apps
        Column {
            width: columnas.mitad
            spacing: 2

            Titular { texto: "Apps"; width: parent.width }

            Texto {
                visible: pestana.apps.length === 0
                width: parent.width
                leftPadding: 12
                topPadding: 6
                text: "Ahora mismo no suena ninguna app"
                font.pixelSize: 12
                font.bold: false
                color: Tema.gris
            }

            Repeater {
                model: pestana.apps

                Column {
                    id: app
                    required property var modelData
                    readonly property string icono: modelData.properties?.["application.icon-name"] ?? ""
                    width: parent.width
                    spacing: 0
                    topPadding: 4

                    Row {
                        leftPadding: 12
                        spacing: 8
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: app.icono !== ""
                            implicitSize: 16
                            source: app.icono !== "" ? Quickshell.iconPath(app.icono, true) : ""
                        }
                        Texto {
                            text: pestana.nombreApp(app.modelData)
                            font.pixelSize: 13
                        }
                    }
                    FilaVolumen {
                        width: parent.width
                        conElegir: false
                        nodo: app.modelData
                    }
                }
            }
        }
    }
}
