// Modo juego (comun/Juego.qml): un mando mientras hay un juego con gamemode.
// Clic = salir del modo juego (vuelven los avisos; la CPU sigue a tope hasta
// que cierres el juego)
import QtQuick
import qs.comun

Isla {
    id: isla
    relleno: 3
    oculta: !Juego.activo

    ayuda: "<b>Modo juego</b>: CPU a tope y sin avisos (salvo los urgentes)"
        + "<br>" + Tema.suave("Clic: volver a ver los avisos")

    Modulo {
        icono: "󰊴"
        colorAviso: Tema.blanco
        onClic: Juego.terminar()
    }
}
