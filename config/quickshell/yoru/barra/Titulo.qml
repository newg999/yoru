// Título de la ventana activa de esta pantalla (sin ventanas, la isla desaparece)
import QtQuick
import qs.comun

Isla {
    id: isla
    required property string salida
    property int maximo: 420       // píxeles; lo que no quepa se corta con "…"

    Texto {
        text: Niri.tituloEn(isla.salida)
        visible: text !== ""
        font.bold: false
        elide: Text.ElideRight
        width: Math.min(implicitWidth, isla.maximo)
        height: Tema.altoBarra
    }
}
