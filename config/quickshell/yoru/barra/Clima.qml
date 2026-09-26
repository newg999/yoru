// Clima de donde vives (ver comun/Tiempo.qml) · Clic = previsión
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 7

    Modulo {
        visible: Tiempo.listo
        icono: Tiempo.icono
        texto: Tiempo.temperatura + "°C"
        onClic: Paneles.alternar("centro", isla.pantalla, "clima")
    }
}
