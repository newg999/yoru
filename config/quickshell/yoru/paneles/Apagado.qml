// ============================================================================
//  Apagado — menú de sesión en mitad de la pantalla (Mod+Shift+BackSpace)
//
//    ↑ ↓ para moverte · Enter para elegir · Esc para cerrar
//    o la letra subrayada: B bloquear, S suspender, C cerrar sesión,
//    R reiniciar, A apagar
//
//  Para añadir opciones: una línea en «opciones».
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "apagado"
    lado: "medio"
    ancho: 340

    readonly property var opciones: [
        {icono: "󰌾", titulo: "Bloquear", tecla: "b", orden: ["sh", "-c", "~/.config/niri/scripts/bloquear.sh"]},
        {icono: "󰤄", titulo: "Suspender", tecla: "s", orden: ["sh", "-c", "~/.config/niri/scripts/bloquear.sh && systemctl suspend"]},
        {icono: "󰍃", titulo: "Cerrar sesión", tecla: "c", orden: ["niri", "msg", "action", "quit", "--skip-confirmation"]},
        {icono: "󰜉", titulo: "Reiniciar", tecla: "r", orden: ["systemctl", "reboot"]},
        {icono: "󰐥", titulo: "Apagar", tecla: "a", orden: ["systemctl", "poweroff"]},
    ]

    property string encendido: ""     // "3 h 20 min", de /proc/uptime

    onAbiertoChanged: {
        if (abierto) {
            lista.currentIndex = 0;
            lista.forceActiveFocus();
            uptime.reload();
        }
    }

    function elegir(opcion) {
        if (!opcion)
            return;
        Paneles.cerrar();
        Quickshell.execDetached(opcion.orden);
    }

    FileView {
        id: uptime
        path: "/proc/uptime"
        onLoaded: {
            const min = Math.floor(parseFloat(text()) / 60);
            const h = Math.floor(min / 60);
            panel.encendido = (h > 0 ? h + " h " : "") + (min % 60) + " min";
        }
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
