// Memorias USB y discos externos: solo se ve con alguno conectado.
// Clic = su panel (abrir o expulsar)
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 3
    oculta: Discos.lista.length === 0

    ayuda: Discos.lista.map(v => `<b>${Tema.html(v.nombre)}</b>  ${v.tamano}`).join("<br>")
        + "<br>" + Tema.suave("Clic: abrir o expulsar")

    // Cuántas memorias (no particiones) hay conectadas
    readonly property int cuantos: new Set(Discos.lista.map(v => v.disco)).size

    Modulo {
        icono: "󰕓"
        texto: isla.cuantos > 1 ? String(isla.cuantos) : ""
        resaltado: Paneles.esta("discos", isla.pantalla)
        onClic: Paneles.alternar("discos", isla.pantalla, "")
    }
}
