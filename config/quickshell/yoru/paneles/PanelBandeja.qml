// ============================================================================
//  Bandeja — el menú de clic derecho de un icono de la bandeja (Discord,
//  Steam, MEGA...), con el aspecto de Yoru y colgando de su isla como los
//  demás paneles (en vez del menú de Qt, que no pegaba con nada):
//
//    [icono] Steam
//    ─────────────────────────
//    Tienda
//    Biblioteca
//    Amigos                  ›     ← submenú: se entra en él (‹ para volver)
//    ✓ Modo Big Picture            ← casillas y opciones, con su marca
//    ─────────────────────────
//    Salir de Steam
//
//  Se abre con Paneles.alternar("bandeja", pantalla, id del icono)
//  (barra/Bandeja.qml). Las entradas son las de su menú (DBusMenu) a través
//  de QsMenuOpener; al elegir una se cierra.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.comun

Panel {
    id: panel
    nombre: "bandeja"
    lado: "derecha"
    ancho: 300

    // La app se guarda al abrir (o al pasar a otro icono con él abierto):
    // mientras se recoge sigue enseñando su menú
    property string idApp: ""
    Connections {
        target: Paneles
        function onSeccionChanged() {
            if (panel.abierto)
                panel.idApp = Paneles.seccion;
        }
    }
    readonly property var item: SystemTray.items.values.find(i => i.id === idApp) ?? null
    readonly property string nombreApp: {
        const t = (item?.tooltipTitle ?? "").split("\n")[0].trim();
        return t || item?.title || item?.id || "";
    }

    // Los submenús por los que se ha entrado (el último es el que se ve)
    property var ruta: []
    onAbiertoChanged: {
        if (abierto)
            idApp = Paneles.seccion;
        ruta = [];
    }
    onItemChanged: ruta = []
    readonly property var actual: ruta.length > 0 ? ruta[ruta.length - 1] : null

    QsMenuOpener {
        id: opener
        menu: panel.actual ?? panel.item?.menu ?? null
    }

    Column {
        width: parent.width
        spacing: 8

        // ------------------------------------------------------ Cabecera
        Item {
            width: parent.width
            height: 28

            // En un submenú, ‹ vuelve atrás; si no, el icono de la app
            Texto {
                id: atras
                visible: panel.ruta.length > 0
                width: 26; height: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "󰅁"
                font.pixelSize: 20
                color: atrasRaton.containsMouse ? Tema.blanco : Tema.texto
                scale: atrasRaton.pressed ? 0.85 : atrasRaton.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                MouseArea {
                    id: atrasRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.ruta = panel.ruta.slice(0, -1)
                }
            }
            IconImage {
                id: logo
                visible: panel.ruta.length === 0
                anchors.verticalCenter: parent.verticalCenter
                x: 4
                implicitSize: 20
                source: panel.item?.icon ?? ""
            }
            Texto {
                anchors {
                    left: panel.ruta.length > 0 ? atras.right : logo.right
                    leftMargin: 10
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: panel.actual ? panel.actual.text.replace(/&(?!&)/g, "") : panel.nombreApp
                textFormat: Text.PlainText
                font.pixelSize: 15
                color: Tema.blanco
                elide: Text.ElideRight
            }
        }

        // ------------------------------------------------------ Entradas
        Column {
            width: parent.width
            spacing: 2

            Texto {
                visible: (opener.children?.values.length ?? 0) === 0
                x: 6
                text: "Esta app no tiene menú"
                font.pixelSize: 12
                font.bold: false
                color: Tema.gris
            }

            Repeater {
                model: opener.children

                Item {
                    id: entrada
                    required property QsMenuEntry modelData
                    readonly property bool raya: modelData.isSeparator
                    width: parent.width
                    height: raya ? 11 : 36
                    // Las apps a veces mandan entradas ocultas sin texto
                    visible: raya || modelData.text !== ""

                    Rectangle {
                        visible: entrada.raya
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Tema.claro(0.08)
                    }

                    Rectangle {
                        visible: !entrada.raya
                        anchors.fill: parent
                        radius: Tema.esquina(10)
                        color: raton.containsMouse && entrada.modelData.enabled ? Tema.cajaHover : "transparent"
                        opacity: entrada.modelData.enabled ? 1 : 0.4
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }

                        // Marca de casilla u opción (o el hueco, para alinear)
                        readonly property bool conMarca: entrada.modelData.buttonType !== QsMenuButtonType.None
                        readonly property bool marcada: entrada.modelData.checkState === Qt.Checked
                        Texto {
                            id: marca
                            visible: parent.conMarca
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: entrada.modelData.buttonType === QsMenuButtonType.RadioButton
                                ? (parent.marcada ? "󰄯" : "󰄰")
                                : (parent.marcada ? "󰄲" : "󰄱")
                            font.pixelSize: 15
                            color: parent.marcada ? Tema.blanco : Tema.gris
                        }
                        IconImage {
                            id: icono
                            visible: !parent.conMarca && entrada.modelData.icon !== ""
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            implicitSize: 18
                            source: entrada.modelData.icon
                        }
                        Texto {
                            anchors {
                                left: marca.visible ? marca.right : icono.visible ? icono.right : parent.left
                                leftMargin: marca.visible || icono.visible ? 10 : 12
                                right: flecha.left
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            // Los «&» de los atajos de teclado de Qt fuera
                            text: entrada.modelData.text.replace(/&(?!&)/g, "")
                            textFormat: Text.PlainText
                            font.pixelSize: 13
                            font.bold: false
                            color: Tema.texto
                            elide: Text.ElideRight
                        }
                        Texto {
                            id: flecha
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            text: entrada.modelData.hasChildren ? "󰅂" : ""
                            font.pixelSize: 15
                            color: Tema.gris
                        }

                        MouseArea {
                            id: raton
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entrada.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const e = entrada.modelData;
                                if (e.hasChildren) {
                                    panel.ruta = panel.ruta.concat([e]);
                                } else {
                                    Paneles.cerrar();
                                    e.triggered();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
