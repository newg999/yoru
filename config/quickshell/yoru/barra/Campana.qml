// ============================================================================
//  Ajustes, portapapeles, notificaciones y apagado, al final de la barra
//    󰒓  = ajustes: tema, fondo, barra y aspecto (Mod+Alt+T)
//    󰅌  = historial del portapapeles (Mod+Alt+V)
//    󰂚  = panel de notificaciones (Mod+Alt+M), con un punto rojo si hay
//         clic derecho = no molestar (󰂛) · clic central = borrarlas todas
//    󰐥  = bloquear, suspender, cerrar sesión, reiniciar o apagar
//         (Mod+Shift+BackSpace)
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
        + "<br>" + Tema.suave("󰒓 Ajustes: tema, fondo, barra y aspecto  ·  Mod+Alt+T")
        + "<br>" + Tema.suave("󰐥 Apagar, reiniciar, cerrar sesión…  ·  Mod+Shift+BackSpace")

    Modulo {
        icono: "󰒓"
        resaltado: Paneles.esta("ajustes", isla.pantalla)
        onClic: Paneles.alternar("ajustes", isla.pantalla, "")
    }

    Modulo {
        icono: "󰅌"
        resaltado: Paneles.esta("portapapeles", isla.pantalla)
        onClic: Paneles.alternar("portapapeles", isla.pantalla, "")
    }

    Modulo {
        icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
        punto: Notificaciones.cuantas > 0 && !Notificaciones.noMolestar
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

    Modulo {
        icono: "󰐥"
        resaltado: Paneles.esta("apagado", isla.pantalla)
        onClic: Paneles.alternar("apagado", isla.pantalla, "")
    }
}
