pragma Singleton

// ============================================================================
//  Juego — el modo juego: lo avisa gamemode (config/gamemode.ini) al abrir
//  el primer juego y al cerrar el último
//
//    activo   hay un juego con gamemode (el mando de la barra, barra/Jugando.qml)
//
//  Mientras dura: «No molestar» (solo salen los avisos urgentes). Al acabar
//  se deja como estaba. gamemode, por su parte, pone la CPU a tope.
//
//    qs -c yoru ipc call juego empezar     (lo llama gamemode)
//    qs -c yoru ipc call juego terminar
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: raiz

    property bool activo: false
    property bool _noMolestarAntes: false

    function empezar() {
        if (activo)
            return;
        _noMolestarAntes = Notificaciones.noMolestar;
        Notificaciones.noMolestar = true;
        activo = true;
    }
    function terminar() {
        if (!activo)
            return;
        Notificaciones.noMolestar = _noMolestarAntes;
        activo = false;
    }

    IpcHandler {
        target: "juego"
        function empezar(): void {
            raiz.empezar();
        }
        function terminar(): void {
            raiz.terminar();
        }
    }
}
