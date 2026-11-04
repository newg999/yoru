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
//
//  Recuerda si lo dejaste encendido o apagado (lo cambie quien lo cambie: la
//  barra, el dock, Blueman...) en ~/.local/state/yoru/bluetooth («1» o «0»).
//  Al arrancar, BlueZ y Blueman lo encienden solos: durante los primeros
//  segundos se vuelve a dejar como estaba, sin guardar nada.
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Singleton {
    id: raiz

    readonly property var adaptador: Bluetooth.defaultAdapter

    // ------------------------------------------------- recordar el estado
    property string recuerdo: ""        // "1", "0" o "" (nunca guardado)
    readonly property bool vigilando: arranque.running

    FileView {
        id: memoria
        path: Quickshell.env("HOME") + "/.local/state/yoru/bluetooth"
        printErrors: false
        onLoaded: {
            raiz.recuerdo = text().trim();
            raiz.restaurar();
        }
    }
    // Los primeros segundos: lo que lo encienda al arrancar no cuenta
    Timer {
        id: arranque
        interval: 20000
        running: true
        onRunningChanged: if (!running) raiz.guardar()
    }
    onAdaptadorChanged: restaurar()

    function restaurar() {
        if (!adaptador || recuerdo === "")
            return;
        const quiero = recuerdo === "1";
        const st = adaptador.state;
        const va = st === BluetoothAdapterState.Enabled || st === BluetoothAdapterState.Enabling;
        if (va !== quiero)
            bluetooth(quiero);
    }
    function cambio() {
        if (vigilando)
            restaurar();
        else
            guardar();
    }
    function guardar() {
        // Según el estado, no «enabled»: al apagarse, el estado ya dice
        // «apagado» cuando «enabled» aún dice que no
        const st = adaptador?.state;
        if (!adaptador || st === BluetoothAdapterState.Enabling || st === BluetoothAdapterState.Disabling)
            return;
        const ahora = st === BluetoothAdapterState.Enabled ? "1" : "0";
        if (ahora !== recuerdo) {
            recuerdo = ahora;
            memoria.setText(ahora);
        }
    }
    Connections {
        target: raiz.adaptador
        // «enabled» llega después que el estado: hasta entonces, apagarlo
        // no hace nada. Por eso se mira a los dos
        function onStateChanged() {
            raiz.cambio();
        }
        function onEnabledChanged() {
            raiz.cambio();
        }
    }

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
