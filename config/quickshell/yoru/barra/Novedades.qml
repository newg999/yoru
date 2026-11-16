// Actualizaciones: solo se ve si hay alguna. Clic = su página (Paginas.qml)
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
        resaltado: Paneles.esta("pildora", isla.pantalla, "actualizaciones")
        // (una página más del panel de las islas: se desliza desde la otra)
        onClic: Paneles.abrirPagina(isla.pantalla, "actualizaciones", "derecha")
    }
}
