#!/bin/sh
# ============================================================================
#  lanzar.sh — intermediario de rofi para abrir apps (config.rasi → run-command)
#
#  Si escribes algo en el lanzador que no coincide con ninguna app y pulsas
#  Enter, rofi intenta ejecutarlo como un comando. Si no existe, rofi enseña
#  una ventana de error que con nuestro tema queda invisible y deja el teclado
#  bloqueado. Aquí se comprueba antes: si el comando existe se ejecuta tal
#  cual; si no, un aviso y listo.
# ============================================================================

if command -v "$1" >/dev/null 2>&1; then
    exec "$@"
fi

notify-send -a Lanzador -c error "Lanzador" "No hay ninguna app ni comando llamado «$*»"
