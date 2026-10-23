pragma Singleton

// ============================================================================
//  Despierto — «no suspender»: mientras está activo, ni se bloquea, ni se
//  apaga la pantalla, ni se suspende por inactividad
//
//  Lo hace un IdleInhibitor en cada barra (Barra.qml): swayidle lo respeta,
//  como cuando ves un vídeo a pantalla completa. Con el estilo Dock lo hace
//  el dock (yoru-dock): por eso el estado está en $XDG_RUNTIME_DIR/yoru-despierto
//  («1» o «0»), que leen y escriben los dos. Ese archivo se borra al cerrar
//  la sesión: al volver, apagado (así no se queda puesto sin querer).
//  Cerrar la tapa sí suspende igualmente.
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: despierto

    property bool activo: false
    onActivoChanged: if (archivo.leido !== activo) {
        archivo.leido = activo;
        archivo.setText(activo ? "1" : "0");
    }

    FileView {
        id: archivo
        property bool leido: false
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/yoru-despierto"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            leido = text().trim() === "1";
            despierto.activo = leido;
        }
    }
}
