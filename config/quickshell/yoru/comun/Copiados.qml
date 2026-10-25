pragma Singleton

// ============================================================================
//  Copiados — el historial del portapapeles (cliphist)
//
//  Lo usan el panel del portapapeles (paneles/Portapapeles.qml) y la página
//  «portapapeles» de la píldora (paneles/PaginaPortapapeles.qml):
//      Copiados.leer()       al abrir (se vuelve a pedir a cliphist)
//      Copiados.copiar(e)    la vuelve a copiar (pega con Ctrl+V)
//      Copiados.borrar(e)    la quita del historial · borrarTodo()
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: copiados

    // Cada entrada: {linea: "id\ttexto" tal cual la da cliphist, texto, imagen}
    property var entradas: []
    property bool hayCliphist: true

    function leer() {
        lector.running = true;
    }

    function buscar(texto) {
        const q = (texto ?? "").trim().toLowerCase();
        return q === "" ? entradas : entradas.filter(e => e.texto.toLowerCase().includes(q));
    }

    function copiar(e) {
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", e.linea]);
        Paneles.cerrar();
    }

    function borrar(e) {
        if (!e)
            return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "_", e.linea]);
        entradas = entradas.filter(x => x !== e);
    }

    function borrarTodo() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entradas = [];
    }

    Process {
        id: lector
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 3; cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                copiados.entradas = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const texto = l.slice(l.indexOf("\t") + 1);
                    return {linea: l, texto: texto, imagen: texto.startsWith("[[ binary data")};
                });
            }
        }
        onExited: codigo => copiados.hayCliphist = codigo !== 3
    }
}
