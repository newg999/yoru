#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  polkit.sh — Arranca un agente de autenticación
#  Es la ventanita que pide tu contraseña cuando una app necesita permisos
#  de administrador. GNOME lo trae integrado; en Niri hay que lanzarlo.
# ----------------------------------------------------------------------------

for agente in \
    /usr/libexec/polkit-mate-authentication-agent-1 \
    /usr/libexec/polkit-gnome-authentication-agent-1 \
    /usr/bin/lxqt-policykit-agent; do
    if [[ -x "$agente" ]]; then
        exec "$agente"
    fi
done

notify-send "Polkit" "No se encontró ningún agente de autenticación"
