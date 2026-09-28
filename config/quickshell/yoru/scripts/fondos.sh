#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  fondos.sh — Lista de fondos para el panel Fondos (paneles/Fondos.qml)
#
#  Escribe una línea por fondo: «ruta<TAB>miniatura». Antes crea las
#  miniaturas que falten (cuadradas, recortadas por el centro, en paralelo).
#  Se guardan en ~/.cache/fondos-miniaturas y solo se hacen las nuevas.
# ----------------------------------------------------------------------------

DIR="$HOME/.local/share/wallpapers"
CACHE="$HOME/.cache/fondos-miniaturas"
mkdir -p "$CACHE"

mapfile -t FONDOS < <(find -L "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort)

faltan=()
for f in "${FONDOS[@]}"; do
    [[ -f "$CACHE/$(basename "${f%.*}").jpg" ]] || faltan+=("$f")
done
if [[ ${#faltan[@]} -gt 0 ]] && command -v magick >/dev/null; then
    printf '%s\0' "${faltan[@]}" | xargs -0 -P "$(nproc)" -I{} sh -c \
        'magick "$1[0]" -thumbnail 256x256^ -gravity center -extent 256x256 -quality 85 "$2/$(basename "${1%.*}").jpg"' _ {} "$CACHE"
fi

for f in "${FONDOS[@]}"; do
    printf '%s\t%s\n' "$f" "$CACHE/$(basename "${f%.*}").jpg"
done
