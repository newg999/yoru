pragma Singleton

// ============================================================================
//  Despierto — «no suspender»: mientras está activo, ni se bloquea, ni se
//  apaga la pantalla, ni se suspende por inactividad
//
//  Lo hace un IdleInhibitor en cada barra (Barra.qml): swayidle lo respeta,
//  como cuando ves un vídeo a pantalla completa. No se guarda: al reiniciar
//  la sesión vuelve a estar apagado (así no se queda puesto sin querer).
//  Cerrar la tapa sí suspende igualmente.
// ============================================================================

import QtQuick
import Quickshell

Singleton {
    property bool activo: false
}
