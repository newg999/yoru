// ============================================================================
//  Pestaña Notificaciones de Ajustes — cómo y cuándo avisan
//
//    Avisos: no molestar, cuánto duran en pantalla, dónde salen y si suenan
//    Apps:   las que han avisado alguna vez; apagando una, sus avisos ya no
//            salen ni suenan (se siguen guardando en el panel de la campana)
//
//  Se guarda en comun/Ajustes.qml; lo usan Notificaciones.qml y Avisos.qml.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun

Item {
    id: pestana

    implicitHeight: columnas.height

    function silenciar(app, si) {
        const lista = Ajustes.silenciadas.filter(a => a !== app);
        Ajustes.silenciadas = si ? lista.concat([app]) : lista;
    }

    function icono(app) {
        const entrada = DesktopEntries.heuristicLookup(app);
        return entrada ? Quickshell.iconPath(entrada.icon, true) : "";
    }

    Row {
        id: columnas
        width: parent.width
        spacing: 16
        readonly property real mitad: (width - spacing) / 2

        // ---------------------------------------------------------- Avisos
        Column {
            width: columnas.mitad
            spacing: 2

            Titular { texto: "Avisos"; width: parent.width }
            Interruptor {
                width: parent.width
                titulo: "No molestar"
                detalle: "Solo salen las urgentes; el resto se guarda en el panel"
                activo: Notificaciones.noMolestar
                onCambiar: v => Notificaciones.noMolestar = v
            }
            Interruptor {
                width: parent.width
                titulo: "Sonido al llegar"
                detalle: "Un aviso corto (no con «No molestar»)"
                activo: Ajustes.avisosSonido
                onCambiar: v => {
                    Ajustes.avisosSonido = v;
                    if (v)
                        Notificaciones.sonar();
                }
            }

            Item { width: 1; height: 8 }
            Texto {
                leftPadding: 12
                bottomPadding: 6
                text: "Tiempo en pantalla"
                font.pixelSize: 13
            }
            Opciones {
                width: parent.width
                opciones: [3, 5, 8, 12].map(s => ({id: String(s), texto: s + " s"}))
                valor: String(Ajustes.avisosSegundos)
                onElegir: id => Ajustes.avisosSegundos = Number(id)
            }

            Item { width: 1; height: 8 }
            Texto {
                leftPadding: 12
                bottomPadding: 6
                text: "Dónde salen"
                font.pixelSize: 13
            }
            Opciones {
                width: parent.width
                opciones: [
                    {id: "derecha", icono: "󰁜", texto: "Arriba a la derecha"},
                    {id: "centro", icono: "󰁝", texto: "Arriba en el centro"}
                ]
                valor: Ajustes.avisosLado
                onElegir: id => Ajustes.avisosLado = id
            }

            Item { width: 1; height: 12 }
            Opciones {
                width: parent.width
                opciones: [{id: "probar", icono: "󰂚", texto: "Enviar uno de prueba"}]
                onElegir: Quickshell.execDetached(["notify-send", "-a", "Yoru", "Notificación de prueba",
                    "Así se ven (y suenan) los avisos"])
            }
        }

        // ------------------------------------------------------------ Apps
        Column {
            width: columnas.mitad
            spacing: 2

            Titular { texto: "Apps"; width: parent.width }

            Texto {
                visible: Ajustes.appsAvisos.length === 0
                width: parent.width
                leftPadding: 12
                topPadding: 6
                text: "Aquí saldrán las apps según vayan avisando"
                font.pixelSize: 12
                font.bold: false
                color: Tema.gris
                wrapMode: Text.Wrap
            }

            Repeater {
                model: Ajustes.appsAvisos

                Item {
                    id: app
                    required property string modelData
                    readonly property string imagen: pestana.icono(modelData)
                    width: parent.width
                    height: 40

                    IconImage {
                        id: logo
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        implicitSize: 18
                        source: app.imagen
                        visible: app.imagen !== ""
                    }
                    Interruptor {
                        anchors {
                            left: logo.visible ? logo.right : parent.left
                            leftMargin: logo.visible ? 0 : 12
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        titulo: app.modelData
                        activo: !Ajustes.silenciadas.includes(app.modelData)
                        onCambiar: v => pestana.silenciar(app.modelData, !v)
                    }
                }
            }
        }
    }
}
