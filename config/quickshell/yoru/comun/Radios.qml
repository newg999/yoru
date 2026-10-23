pragma Singleton

// ============================================================================
//  Radios — encender y apagar el Bluetooth
//
//  Al apagarlo, Blueman lo bloquea también con rfkill; luego BlueZ no deja
//  encenderlo («off-blocked») hasta quitar ese bloqueo. Al encender, se
//  quita primero (rfkill unblock: la sesión tiene permiso, sin contraseña)
//  y después se enciende el adaptador.
//
//    Radios.bluetooth(true)     Radios.alternarBluetooth()
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Singleton {
    id: raiz

    readonly property var adaptador: Bluetooth.defaultAdapter

    function bluetooth(encender) {
        if (!adaptador)
            return;
        if (!encender) {
            adaptador.enabled = false;
            return;
        }
        desbloquear.running = true;
    }
    function alternarBluetooth() {
        bluetooth(!(adaptador?.enabled ?? false));
    }

    Process {
        id: desbloquear
        command: ["rfkill", "unblock", "bluetooth"]
        // Ya sin bloqueo, BlueZ suele encenderlo solo; por si acaso, se pide
        onExited: encender.restart()
    }
    Timer {
        id: encender
        interval: 400
        onTriggered: if (raiz.adaptador && !raiz.adaptador.enabled) raiz.adaptador.enabled = true
    }
}
