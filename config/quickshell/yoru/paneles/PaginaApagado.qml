// ============================================================================
//  Página «apagado» de la píldora (Mod+Shift+Retroceso con la barra en
//  píldora): la píldora se hace el menú de sesión
//
//      Sesión de don · encendido hace 3 h 20 min
//      ( 󰌾 )   ( 󰤄 )   ( 󰍃 )   ( 󰜉 )   ( 󰐥 )
//     Bloquear Suspender Salir  Reiniciar Apagar
//
//  ← → para moverte · Enter elige · o la letra: B S C R A · Esc cierra.
//  Cerrar sesión, reiniciar y apagar piden confirmar (otra vez, en 4 s).
//  Las opciones: comun/Sesion.qml (las mismas que paneles/Apagado.qml)
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Column {
    id: pagina

    property bool activa: false
    spacing: 14

    property int elegida: 0
    property int confirmar: -1       // la peligrosa pulsada una vez

    onActivaChanged: {
        if (activa) {
            elegida = 0;
            confirmar = -1;
            botones.forceActiveFocus();
            Sesion.leerEncendido();
        }
    }

    function pulsar(i) {
        const o = Sesion.opciones[i];
        if (!o)
            return;
        elegida = i;
        if (o.peligrosa && confirmar !== i) {
            confirmar = i;
            olvidar.restart();
            return;
        }
        Sesion.elegir(o);
    }
    Timer {
        id: olvidar
        interval: 4000
        onTriggered: pagina.confirmar = -1
    }

    Texto {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: pagina.confirmar >= 0
            ? "<font color='" + Tema.rojo + "'>Pulsa otra vez para " + Sesion.opciones[pagina.confirmar].titulo.toLowerCase() + "</font>"
            : "Sesión de " + Quickshell.env("USER")
                + (Sesion.encendido ? "  <font color='" + Tema.gris + "'>· encendido hace " + Sesion.encendido + "</font>" : "")
        textFormat: Text.StyledText
        font.pixelSize: 12
    }

    Row {
        id: botones
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        focus: true

        Keys.onLeftPressed: pagina.elegida = (pagina.elegida + Sesion.opciones.length - 1) % Sesion.opciones.length
        Keys.onRightPressed: pagina.elegida = (pagina.elegida + 1) % Sesion.opciones.length
        Keys.onReturnPressed: pagina.pulsar(pagina.elegida)
        Keys.onEnterPressed: pagina.pulsar(pagina.elegida)
        Keys.onEscapePressed: Paneles.cerrar()
        Keys.onPressed: event => {
            const i = Sesion.opciones.findIndex(o => o.tecla === event.text.toLowerCase());
            if (i >= 0) {
                pagina.pulsar(i);
                event.accepted = true;
            }
        }

        Repeater {
            model: Sesion.opciones
            Item {
                id: boton
                required property var modelData
                required property int index
                readonly property bool elegido: pagina.elegida === index
                readonly property bool aviso: pagina.confirmar === index
                width: 68
                height: 86

                Rectangle {
                    id: circulo
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56; height: 56; radius: Tema.esquina(28)
                    color: boton.aviso ? Tema.rojo
                        : boton.elegido ? Tema.blanco
                        : Tema.caja
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    scale: botonRaton.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                    Texto {
                        anchors.centerIn: parent
                        text: boton.modelData.icono
                        font.pixelSize: 21
                        color: boton.aviso || boton.elegido ? Tema.oscuro : Tema.texto
                    }
                    MouseArea {
                        id: botonRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: pagina.elegida = boton.index
                        onClicked: pagina.pulsar(boton.index)
                    }
                }
                Texto {
                    anchors { top: circulo.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                    // La letra del atajo, subrayada
                    text: "<u>" + boton.modelData.titulo[0] + "</u>" + boton.modelData.titulo.slice(1)
                    textFormat: Text.StyledText
                    font.bold: false
                    font.pixelSize: 11
                    color: boton.elegido ? Tema.texto : Tema.gris
                }
            }
        }
    }
}
