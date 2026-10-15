pragma Singleton

// ============================================================================
//  Ajustes — lo que se cambia desde el panel de Ajustes (Mod+Alt+T)
//  Se guardan en ~/.local/state/yoru/ajustes.json: fuera del repo, como los
//  favoritos del dock. Si lo editas a mano, se aplica al guardar.
//  Lo que falte en el archivo se queda con el valor de aquí.
//  Los colores no van aquí: son cosa de «yoru tema» (ver comun/Tema.qml).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ajustes

    // ------------------------------------------------------- Barra y dock
    property alias barra: datos.barra                 // "arriba" · "izquierda"
    property alias dock: datos.dock                   // "overview" · "siempre" · "nunca"
    property alias islaTitulo: datos.islaTitulo
    property alias islaMusica: datos.islaMusica
    property alias islaClima: datos.islaClima
    property alias islaRecursos: datos.islaRecursos
    property alias islaBandeja: datos.islaBandeja

    // ------------------------------------------------------------ Aspecto
    property alias radio: datos.radio                 // esquinas de islas y paneles (px)
    property alias opacidadIslas: datos.opacidadIslas
    property alias opacidadPaneles: datos.opacidadPaneles
    property alias letra: datos.letra                 // texto de la barra (px)
    property alias desenfoque: datos.desenfoque       // fondo borroso tras las islas
    property alias animaciones: datos.animaciones

    readonly property bool vertical: barra === "izquierda"

    // Vuelve a dejar el aspecto (no la barra ni el dock) como al principio
    function restablecerAspecto() {
        datos.radio = 10;
        datos.opacidadIslas = 0.45;
        datos.opacidadPaneles = 0.90;
        datos.letra = 13;
        datos.desenfoque = true;
        datos.animaciones = true;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/yoru/ajustes.json"
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        // Cualquier cambio desde el panel se guarda al momento
        onAdapterUpdated: writeAdapter()
        // Primera vez: se crea con los valores de aquí
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: datos
            property string barra: "arriba"
            property string dock: "overview"
            property bool islaTitulo: true
            property bool islaMusica: true
            property bool islaClima: true
            property bool islaRecursos: true
            property bool islaBandeja: true

            property int radio: 10
            property real opacidadIslas: 0.45
            property real opacidadPaneles: 0.90
            property int letra: 13
            property bool desenfoque: true
            property bool animaciones: true
        }
    }
}
