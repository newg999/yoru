// «No suspender» activo (comun/Despierto.qml): un aviso para no olvidarlo.
// Clic = quitarlo
import QtQuick
import qs.comun

Isla {
    id: isla
    relleno: 3
    oculta: !Despierto.activo

    ayuda: "<b>No suspender</b>: ni se bloquea ni se apaga la pantalla sola"
        + "<br>" + Tema.suave("Clic: quitarlo")

    Modulo {
        icono: "󰅶"
        colorAviso: Tema.amarillo
        onClic: Despierto.activo = false
    }
}
