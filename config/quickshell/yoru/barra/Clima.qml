// Clima de donde vives (ver comun/Tiempo.qml) · Clic = previsión
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 7

    ayuda: !Tiempo.listo ? "" : `<b>${Tema.html(Tiempo.descripcion)}</b>  ${Tiempo.temperatura}°C`
        + `<br>Sensación ${Tiempo.sensacion}°C  ·  humedad ${Tiempo.humedad}%  ·  viento ${Tiempo.viento} km/h`
        + (Tiempo.dias.length ? `<br>Hoy ${Math.round(Tiempo.dias[0].max)}° / ${Math.round(Tiempo.dias[0].min)}°` : "")
        + `<br>` + Tema.suave(`${Tema.html(Tiempo.lugar)}  ·  ☀ ${Tiempo.amanecer} – ${Tiempo.atardecer}`)

    Modulo {
        visible: Tiempo.listo
        icono: Tiempo.icono
        texto: Tiempo.temperatura + "°C"
        resaltado: Paneles.esta("centro", isla.pantalla, "clima")
        onClic: Paneles.alternar("centro", isla.pantalla, "clima")
    }
}
