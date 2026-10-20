pragma Singleton

// ============================================================================
//  Discos — memorias USB, tarjetas y discos externos (scripts/discos.py)
//
//  discos.py vigilar se queda escuchando: al conectar uno lo monta y avisa
//  con «Abrir» y «Expulsar» (eso lo hace el propio script). Aquí solo se
//  lleva la lista para la isla de la barra y su panel.
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: discos

    property var lista: []            // [{disco, path, nombre, modelo, tamano, montaje}]
    property string error: ""
    property string ocupado: ""       // disco que se está expulsando o montando
    readonly property string script: Quickshell.shellPath("scripts/discos.py")

    function leer() {
        lector.running = true;
    }
    function abrir(v) {
        if (v.montaje !== "") {
            Quickshell.execDetached(["xdg-open", v.montaje]);
            return;
        }
        ejecutar(["montar", v.path], v.disco, true, v);
    }
    function expulsar(v) {
        ejecutar(["expulsar", v.disco], v.disco, false, v);
    }

    property var _pendiente: null     // volumen a abrir al terminar de montarlo
    function ejecutar(args, disco, abrirAlAcabar, v) {
        if (ocupado !== "")
            return;
        error = "";
        ocupado = disco;
        _pendiente = abrirAlAcabar ? v : null;
        orden.command = [script, ...args];
        orden.running = true;
    }

    Process {
        id: lector
        command: [discos.script, "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    discos.lista = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: orden
        stdout: StdioCollector { id: salida }
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            discos.ocupado = "";
            if (codigo !== 0)
                discos.error = errores.text.trim() || "No se pudo";
            else if (discos._pendiente)
                Quickshell.execDetached(["xdg-open", salida.text.trim()]);
            discos.leer();
        }
    }

    Process {
        id: vigia
        running: true
        command: [discos.script, "vigilar"]
        stdout: SplitParser {
            onRead: discos.leer()
        }
        onExited: reinicio.start()
    }
    Timer {
        id: reinicio
        interval: 5000
        onTriggered: vigia.running = true
    }

    Component.onCompleted: leer()
}
