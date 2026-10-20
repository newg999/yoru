// Actualizaciones: solo se ve si hay alguna. Clic = su panel
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 3
    oculta: Actualizaciones.cuantas === 0

    ayuda: `<b>${Actualizaciones.cuantas}</b> actualizaciones`
        + (Actualizaciones.seguridad > 0 ? `  ·  ${Actualizaciones.seguridad} de seguridad` : "")
        + "<br>" + Tema.suave("Clic: ver y actualizar")

    Modulo {
        icono: "󰚰"
        texto: String(Actualizaciones.cuantas)
        resaltado: Paneles.esta("actualizaciones", isla.pantalla)
        onClic: Paneles.alternar("actualizaciones", isla.pantalla, "")
    }
}
