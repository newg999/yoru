#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  musica.sh — Botones de música para la barra (anterior · play/pausa · siguiente)
#
#  Uso:  musica.sh anterior | playpausa | siguiente
#
#  Se queda escuchando a playerctl y escribe el icono cada vez que cambia el
#  estado. Si no suena nada, escribe una línea vacía y Waybar oculta el botón.
# ----------------------------------------------------------------------------

ANTERIOR="󰒮"
PLAY="󰐊"
PAUSA="󰏤"
SIGUIENTE="󰒭"

playerctl --follow status 2>/dev/null | while read -r estado; do
    case "$estado" in
        Playing|Paused)
            case "$1" in
                anterior)  echo "$ANTERIOR" ;;
                siguiente) echo "$SIGUIENTE" ;;
                playpausa) [[ "$estado" == Playing ]] && echo "$PAUSA" || echo "$PLAY" ;;
            esac
            ;;
        *)
            echo ""
            ;;
    esac
done
