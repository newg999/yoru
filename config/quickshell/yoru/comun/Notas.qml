pragma Singleton

// ============================================================================
//  Notas — las notas adhesivas del escritorio (barra/NotasEscritorio.qml)
//  Se guardan en ~/.local/state/yoru/notas.json (fuera del repo): su texto,
//  dónde están y en qué pantalla. Se escribe al momento, con un respiro de
//  medio segundo para no guardar en cada tecla.
//
//  Nota nueva: Mod+Alt+K, el lanzador («Nota nueva») o
//      qs -c yoru ipc call panel alternar nota ""
//  (abre el «panel» nota, que no existe: aquí se ve, se crea la nota y se cierra)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: notas

    property var lista: []      // [{id, texto, x, y, ancho, alto, pantalla}]
    property bool leida: false

    function nueva(pantalla) {
        const nombre = pantalla?.name ?? Quickshell.screens[0]?.name ?? "";
        // Cada una un poco más abajo y a la derecha que la anterior
        const n = lista.filter(t => t.pantalla === nombre).length;
        const id = Date.now().toString(36);
        lista = lista.concat([{id: id, texto: "", x: 80 + 28 * (n % 6), y: 80 + 28 * (n % 6), ancho: 230, alto: 210, pantalla: nombre}]);
        nuevaId = id;
        guardar();
    }
    property string nuevaId: ""     // la recién creada: se enfoca para escribir

    function cambiar(id, cambios) {
        lista = lista.map(t => t.id === id ? Object.assign({}, t, cambios) : t);
        espera.restart();
    }
    function borrar(id) {
        lista = lista.filter(t => t.id !== id);
        guardar();
    }

    function guardar() {
        espera.stop();
        archivo.setText(JSON.stringify(lista, null, 2) + "\n");
    }
    Timer {
        id: espera
        interval: 500
        onTriggered: notas.guardar()
    }

    FileView {
        id: archivo
        path: Quickshell.env("HOME") + "/.local/state/yoru/notas.json"
        printErrors: false
        onLoaded: {
            try {
                notas.lista = JSON.parse(text());
            } catch (e) {
                notas.lista = [];
            }
            notas.leida = true;
        }
        onLoadFailed: notas.leida = true
    }

    // El «panel» nota: crea una en esa pantalla y se cierra
    Connections {
        target: Paneles
        function onAbiertoChanged() {
            if (Paneles.abierto !== "nota")
                return;
            notas.nueva(Paneles.pantalla);
            Paneles.cerrar();
        }
    }
}
