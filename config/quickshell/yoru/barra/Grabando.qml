// Grabando la pantalla (comun/Grabacion.qml): un punto rojo y lo que lleva.
// Clic = parar y guardar (o Mod+Alt+R)
import QtQuick
import qs.comun

Isla {
    id: isla
    relleno: 3
    oculta: !Grabacion.grabando

    ayuda: "<b>Grabando la pantalla</b>" + "<br>" + Tema.suave("Clic o Mod+Alt+R: parar y guardar")

    Modulo {
        icono: "󰑋"
        texto: Grabacion.tiempo
        colorAviso: Tema.rojo
        onClic: Grabacion.alternar()

        // Late despacio mientras graba
        SequentialAnimation on opacity {
            running: Grabacion.grabando && Ajustes.animaciones
            loops: Animation.Infinite
            onRunningChanged: if (!running) parent.opacity = 1
            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
    }
}
