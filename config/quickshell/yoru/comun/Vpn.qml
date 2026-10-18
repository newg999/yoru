// ============================================================================
//  Vpn — las VPN de NetworkManager (WireGuard, OpenVPN...) con scripts/vpn.py
//
//  «nmcli monitor» avisa de cualquier cambio de red y entonces se releen,
//  así que se ven también las que se conectan o desconectan por terminal.
//  La barra pone un candado mientras haya alguna conectada.
// ============================================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: vpn

    property var lista: []            // [{nombre, uuid, tipo, estado: "activa" | "activando" | ""}]
    readonly property var conectadas: lista.filter(v => v.estado === "activa")
    property string error: ""
    property string ocupada: ""       // uuid que se está conectando o desconectando

    readonly property string script: Quickshell.shellPath("scripts/vpn.py")

    function leer() {
        lector.running = true;
    }

    function alternar(v) {
        if (ocupada !== "")
            return;
        error = "";
        ocupada = v.uuid;
        orden.command = [script, v.estado === "" ? "conectar" : "desconectar", v.uuid];
        orden.running = true;
    }

    function borrar(v) {
        error = "";
        orden.command = [script, "borrar", v.uuid];
        orden.running = true;
    }

    Process {
        id: lector
        command: [vpn.script, "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    vpn.lista = JSON.parse(text);
                } catch (e) {
                    console.warn("vpn.py leer:", e);
                }
            }
        }
    }

    Process {
        id: orden
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            if (codigo !== 0)
                vpn.error = errores.text.trim() || "No se pudo";
            vpn.ocupada = "";
            vpn.leer();
        }
    }

    // Cada cambio de red saca varias líneas seguidas: se lee una vez al final
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: espera.restart()
        }
        onExited: reinicio.start()
    }
    Timer {
        id: espera
        interval: 300
        onTriggered: vpn.leer()
    }
    // Si NetworkManager se reinicia, «nmcli monitor» termina: se vuelve a lanzar
    Timer {
        id: reinicio
        interval: 3000
        onTriggered: monitor.running = true
    }

    Component.onCompleted: leer()
}
