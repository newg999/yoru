// ============================================================================
//  Actualizaciones — se abre con su isla de la barra (o buscando «actualizar»)
//
//    󰚰  84 actualizaciones
//       81 del sistema (20 de seguridad) · 3 apps
//    Telegram, brave-browser, kernel… y 76 más
//    [ 󰚰 Actualizar ahora ]  [ 󰑓 Volver a mirar ]
//
//  «Actualizar ahora» abre una terminal con dnf y flatpak (pide la
//  contraseña ahí). Datos: comun/Actualizaciones.qml
// ============================================================================
import QtQuick
import qs.comun

Panel {
    id: panel
    nombre: "actualizaciones"
    lado: "derecha"
    ancho: 400

    // Si hace más de una hora que no se mira, se mira al abrir
    onAbiertoChanged: if (abierto && Date.now() - Actualizaciones.ultima.getTime() > 3600 * 1000) Actualizaciones.comprobar()

    readonly property int resto: Actualizaciones.cuantas - Actualizaciones.nombres.length

    Column {
        width: parent.width
        spacing: 12

        Row {
            spacing: 14
            leftPadding: 4
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰚰"
                font.pixelSize: 28
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Texto {
                    text: Actualizaciones.mirando && Actualizaciones.cuantas === 0 ? "Mirando…"
                        : Actualizaciones.cuantas === 0 ? "Todo al día"
                        : Actualizaciones.cuantas + (Actualizaciones.cuantas === 1 ? " actualización" : " actualizaciones")
                    font.pixelSize: 17
                }
                Texto {
                    visible: Actualizaciones.cuantas > 0
                    text: [
                        Actualizaciones.sistema > 0 ? Actualizaciones.sistema + " del sistema" : "",
                        Actualizaciones.apps > 0 ? Actualizaciones.apps + (Actualizaciones.apps === 1 ? " app" : " apps") : ""
                    ].filter(t => t).join("  ·  ")
                    font.pixelSize: 12
                    font.bold: false
                    color: Tema.gris
                }
            }
        }

        Texto {
            visible: Actualizaciones.seguridad > 0
            width: parent.width
            leftPadding: 4
            text: "󰒃  " + Actualizaciones.seguridad + (Actualizaciones.seguridad === 1 ? " es de seguridad: conviene no dejarla para mucho"
                                                                                  : " son de seguridad: conviene no dejarlas para mucho")
            font.pixelSize: 12
            color: Tema.amarillo
            wrapMode: Text.Wrap
        }

        Tarjeta {
            visible: Actualizaciones.nombres.length > 0
            width: parent.width
            height: nombres.height + 24
            Texto {
                id: nombres
                x: 14; y: 12
                width: parent.width - 28
                text: Actualizaciones.nombres.join(", ") + (panel.resto > 0 ? "… y " + panel.resto + " más" : "")
                textFormat: Text.PlainText
                font.pixelSize: 12
                font.bold: false
                wrapMode: Text.Wrap
            }
        }

        Opciones {
            width: parent.width
            opciones: [
                {id: "actualizar", icono: "󰚰", texto: "Actualizar ahora"},
                {id: "mirar", icono: Actualizaciones.mirando ? "󰔟" : "󰑓", texto: "Volver a mirar"}
            ]
            onElegir: id => {
                if (id === "actualizar") {
                    Actualizaciones.actualizar();
                    Paneles.cerrar();
                } else {
                    Actualizaciones.comprobar();
                }
            }
        }

        Texto {
            width: parent.width
            leftPadding: 4
            text: "Se abre una terminal: te pedirá tu contraseña y verás cómo avanza. Si actualiza el kernel, reinicia al acabar."
            font.pixelSize: 11
            font.bold: false
            color: Tema.gris
            wrapMode: Text.Wrap
        }
    }
}
