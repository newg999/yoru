// ============================================================================
//  Apagado — menú de sesión bajo su botón de la barra (Mod+Shift+BackSpace)
//
//    ↑ ↓ para moverte · Enter para elegir · Esc para cerrar
//    o la letra subrayada: B bloquear, S suspender, C cerrar sesión,
//    R reiniciar, A apagar
//
//  Para añadir opciones: una línea en «opciones» de comun/Sesion.qml.
//  (con la barra en píldora es una página de la píldora: PaginaApagado.qml)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "apagado"
    lado: "derecha"
    ancho: 340

    // Las opciones: comun/Sesion.qml (las comparte con la píldora)
    readonly property var opciones: Sesion.opciones
    readonly property string encendido: Sesion.encendido

    onAbiertoChanged: {
        if (abierto) {
            lista.currentIndex = 0;
            lista.forceActiveFocus();
            Sesion.leerEncendido();
        }
    }

    function elegir(opcion) {
        Sesion.elegir(opcion);
    }

    Column {
        width: parent.width
        spacing: 10

        Texto {
            leftPadding: 4
            text: "Sesión de " + Quickshell.env("USER")
                + (panel.encendido ? "  <font color='" + Tema.gris + "'>· encendido hace " + panel.encendido + "</font>" : "")
            textFormat: Text.StyledText
            font.pixelSize: 12
        }

        ListView {
            id: lista
            width: parent.width
            implicitHeight: contentHeight
            height: contentHeight
            spacing: 2
            interactive: false
            model: panel.opciones
            highlightMoveDuration: 0
            keyNavigationWraps: true

            Keys.onReturnPressed: panel.elegir(panel.opciones[currentIndex])
            Keys.onEnterPressed: panel.elegir(panel.opciones[currentIndex])
            Keys.onEscapePressed: Paneles.cerrar()
            Keys.onPressed: event => {
                const o = panel.opciones.find(o => o.tecla === event.text.toLowerCase());
                if (o) {
                    panel.elegir(o);
                    event.accepted = true;
                }
            }

            delegate: Fila {
                required property var modelData
                required property int index
                width: lista.width
                icono: modelData.icono
                // La letra del atajo, subrayada
                titulo: "<u>" + modelData.titulo[0] + "</u>" + modelData.titulo.slice(1)
                seleccionada: ListView.isCurrentItem
                onHoverChanged: if (hover) lista.currentIndex = index
                onClic: panel.elegir(modelData)
            }
        }
    }
}
