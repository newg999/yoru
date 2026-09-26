// Reloj · Clic = calendario · Clic derecho = app Calendario (eventos)
import QtQuick
import Quickshell
import qs.comun

Isla {
    relleno: 7

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    Modulo {
        icono: "󰅐"
        texto: Qt.formatDateTime(reloj.date, "HH:mm")
        onClic: boton => {
            if (boton === Qt.RightButton)
                Quickshell.execDetached(["gnome-calendar"]);
            else
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rofi/scripts/calendario.py"]);
        }
    }
}
