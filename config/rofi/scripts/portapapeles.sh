#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  portapapeles.sh — Historial del portapapeles (cliphist + rofi)
#  Atajo: Mod+Alt+V · Elige una entrada y queda copiada: pégala con Ctrl+V.
#  Alt+Supr borra la entrada seleccionada del historial.
# ----------------------------------------------------------------------------

if ! command -v cliphist >/dev/null; then
    notify-send "Portapapeles" "cliphist no está instalado"
    exit 1
fi

TEMA='columna { width: 640px; } listview { lines: 10; }'

while true; do
    # --display-columns 2 oculta el número interno que usa cliphist
    eleccion="$(cliphist list | rofi -dmenu -i -p $'' -display-columns 2 \
        -theme-str "$TEMA" -kb-custom-1 'Alt+Delete' \
        -mesg 'Enter: copiar  ·  Alt+Supr: borrar del historial')"
    codigo=$?

    [[ -z "$eleccion" ]] && exit 0
    if [[ $codigo -eq 10 ]]; then
        printf '%s' "$eleccion" | cliphist delete
        continue
    fi
    printf '%s' "$eleccion" | cliphist decode | wl-copy
    exit 0
done
