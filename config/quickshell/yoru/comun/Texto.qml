// Texto con la fuente de Yoru (JetBrainsMono Nerd Font, en negrita como la barra)
import QtQuick

Text {
    color: Tema.texto
    font.family: Tema.fuente
    font.pixelSize: Tema.letra
    font.bold: true
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
