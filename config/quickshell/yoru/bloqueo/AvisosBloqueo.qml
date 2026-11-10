// ============================================================================
//  AvisosBloqueo — las notificaciones en el bloqueo: que las hay, no lo que
//  dicen (eso, al entrar, en la barra)
//
//    ( [kitty][firefox]  5 notificaciones )
//
//  Los iconos son los de las apps que han avisado (hasta 4, sin repetir y
//  sin las imágenes de las notificaciones, que pueden ser fotos o caras),
//  de la más reciente a la más antigua. Sin notificaciones, no sale.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.comun

Item {
    id: avisos

    property real altoMax: 200      // lo que deja Cerradura (aquí sobra)
    function cerrar() {}            // nada que cerrar: no se abren

    readonly property var lista: Notificaciones.lista
    readonly property int cuantas: lista.length

    // Una por app: [{app, icono}]
    readonly property var apps: {
        const vistas = [];
        for (const e of lista) {
            const n = e.n;
            const app = n?.appName || "Aviso";
            if (!vistas.some(v => v.app === app))
                vistas.push({app: app, icono: iconoApp(n)});
        }
        return vistas;
    }
    function iconoApp(n) {
        if (!n)
            return "";
        if (n.appIcon)
            return n.appIcon.includes("/") ? "file://" + n.appIcon.replace(/^file:\/\//, "") : Quickshell.iconPath(n.appIcon, true);
        const entrada = n.desktopEntry ? DesktopEntries.heuristicLookup(n.desktopEntry) : null;
        return entrada ? Quickshell.iconPath(entrada.icon, true) : "";
    }

    visible: cuantas > 0
    width: pastilla.width
    height: pastilla.height

    Rectangle {
        id: pastilla
        width: fila.width + 28
        height: 38
        radius: height / 2
        color: Tema.sombra(0.45)
        border.width: 1
        border.color: Tema.claro(0.12)

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 10

            // Los iconos, montados un poco uno sobre otro
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -6
                Repeater {
                    model: avisos.apps.slice(0, 4)
                    ClippingRectangle {
                        id: chapa
                        required property var modelData
                        width: 24
                        height: 24
                        radius: width / 2
                        color: Tema.oscuro
                        border.width: 2
                        border.color: Tema.sombra(0.9)
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 18
                            visible: chapa.modelData.icono !== "" && status !== Image.Error
                            source: chapa.modelData.icono
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: chapa.modelData.icono === ""
                            text: "󰂚"
                            color: Tema.gris
                            font.family: Tema.mono
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: avisos.cuantas === 1 ? "1 notificación" : avisos.cuantas + " notificaciones"
                color: Tema.texto
                font.family: Tema.fuente
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }
    }
}
