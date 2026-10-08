pragma Singleton

// ============================================================================
//  Favoritos — apps fijadas en el dock, en orden
//  Se guardan en ~/.local/state/yoru/favoritos.json (ids de su .desktop,
//  p. ej. "brave-browser"). Clic derecho en el dock → Fijar / Quitar.
//  Si el archivo no existe, se empieza con navegador, terminal y archivos.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: favoritos

    readonly property var porDefecto: ["brave-browser", "kitty", "org.gnome.Nautilus"]
    property var ids: []

    function contiene(id) {
        return ids.includes(id);
    }

    function alternar(id) {
        ids = contiene(id) ? ids.filter(i => i !== id) : [...ids, id];
        archivo.setText(JSON.stringify(ids, null, 2) + "\n");
    }

    FileView {
        id: archivo
        path: Quickshell.env("HOME") + "/.local/state/yoru/favoritos.json"
        atomicWrites: true
        onLoaded: {
            try {
                favoritos.ids = JSON.parse(text()).filter(i => typeof i === "string");
            } catch (e) {
                console.warn("favoritos.json no es válido:", e);
            }
        }
        // Primera vez: los de por defecto (el dock se salta los que no estén
        // instalados; aquí aún no se sabe: la lista de apps carga después)
        onLoadFailed: favoritos.ids = favoritos.porDefecto
    }
}
