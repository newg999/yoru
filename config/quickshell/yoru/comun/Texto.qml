// Texto con la fuente de Yoru (la de Ajustes › Aspecto, en negrita como la barra)
import QtQuick

Text {
    color: Tema.texto
    font.family: Tema.fuente
    font.pixelSize: Tema.letra
    font.bold: true
    // Cifras del mismo ancho: así «27%» no baila al pasar a «31%»
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
