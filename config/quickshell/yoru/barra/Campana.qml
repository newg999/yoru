// ============================================================================
//  Portapapeles, notificaciones y apagado, cada uno en su isla
//  (cual: "portapapeles" | "notificaciones" | "apagado")
//    󰅌  = historial del portapapeles (Mod+Alt+V)
//    󰂚  = panel de notificaciones (Mod+Alt+M), con un punto rojo si han
//         llegado nuevas desde la última vez que lo abriste
//         clic derecho = no molestar (󰂛) · clic central = borrarlas todas
//    󰐥  = bloquear, suspender, cerrar sesión, reiniciar o apagar
//         (Mod+Shift+BackSpace)
// ============================================================================
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    property string cual: "notificaciones"
    relleno: 3

    ayuda: cual === "portapapeles" ? "Portapapeles  ·  " + Tema.suave("Mod+Alt+V")
        : cual === "apagado" ? "Apagar, reiniciar, cerrar sesión…  ·  " + Tema.suave("Mod+Shift+BackSpace")
        : (Notificaciones.cuantas === 0 ? "Sin notificaciones"
            : `<b>${Notificaciones.cuantas}</b> notificaci${Notificaciones.cuantas === 1 ? "ón" : "ones"}`)
          + (Notificaciones.noMolestar ? "  ·  no molestar" : "")
          + "<br>" + Tema.suave("Clic dcho: no molestar · clic central: borrarlas todas")

    Modulo {
        visible: isla.cual === "portapapeles"
        icono: "󰅌"
        resaltado: Paneles.esta("portapapeles", isla.pantalla)
        onClic: Paneles.alternar("portapapeles", isla.pantalla, "")
    }

    Modulo {
        visible: isla.cual === "notificaciones"
        icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
        punto: Notificaciones.hayNuevas && !Notificaciones.noMolestar
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
        visible: isla.cual === "apagado"
        icono: "󰐥"
        resaltado: Paneles.esta("apagado", isla.pantalla)
        onClic: Paneles.alternar("apagado", isla.pantalla, "")
    }
}
