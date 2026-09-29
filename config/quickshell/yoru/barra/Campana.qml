// ============================================================================
//  Portapapeles y notificaciones, al final de la barra
//    󰅌  = historial del portapapeles (Mod+Alt+V)
//    󰂚  = panel de notificaciones (Mod+Alt+M), con cuántas hay
//         clic derecho = no molestar (󰂛) · clic central = borrarlas todas
// ============================================================================
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    relleno: 5

    ayuda: (Notificaciones.cuantas === 0 ? "Sin notificaciones"
            : `<b>${Notificaciones.cuantas}</b> notificaci${Notificaciones.cuantas === 1 ? "ón" : "ones"}`)
        + (Notificaciones.noMolestar ? "  ·  no molestar" : "")
        + "<br>" + Tema.suave("Campana: clic dcho no molestar · clic central borrar todas")

    Modulo {
        icono: "󰅌"
        resaltado: Paneles.esta("portapapeles", isla.pantalla)
        onClic: Paneles.alternar("portapapeles", isla.pantalla, "")
    }

    Modulo {
        icono: Notificaciones.noMolestar ? "󰂛" : Notificaciones.cuantas > 0 ? "󰂞" : "󰂚"
        texto: Notificaciones.cuantas > 0 ? String(Notificaciones.cuantas) : ""
        tamIcono: Tema.icono
        apagado: Notificaciones.noMolestar
        resaltado: Paneles.esta("notificaciones", isla.pantalla)
        onClic: boton => {
            if (boton === Qt.RightButton)
                Notificaciones.noMolestar = !Notificaciones.noMolestar;
            else if (boton === Qt.MiddleButton)
                Notificaciones.borrarTodas();
            else
                Paneles.alternar("notificaciones", isla.pantalla, "");
        }
    }
}
