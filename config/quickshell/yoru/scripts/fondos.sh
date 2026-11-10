#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  fondos.sh — Lista de fondos para el panel Fondos (paneles/Fondos.qml)
#
#  Escribe una línea por fondo: «ruta<TAB>tarjeta<TAB>vista<TAB>ancho×alto».
#  Antes crea lo que falte, en paralelo y solo para los fondos nuevos:
#    · la tarjeta: vertical, 9:16, recortada por el centro (el carrusel)
#      en ~/.cache/fondos-tarjetas
#    · la vista: apaisada y pequeña, para el fondo desenfocado de detrás,
#      y la resolución del original (en un .txt al lado)
#      en ~/.cache/fondos-vistas
# ----------------------------------------------------------------------------

DIR="$HOME/.local/share/wallpapers"
TARJETAS="$HOME/.cache/fondos-tarjetas"
VISTAS="$HOME/.cache/fondos-vistas"
mkdir -p "$TARJETAS" "$VISTAS"

mapfile -t FONDOS < <(find -L "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort)

faltan=()
for f in "${FONDOS[@]}"; do
    n="$(basename "${f%.*}")"
    [[ -f "$TARJETAS/$n.jpg" && -f "$VISTAS/$n.jpg" && -f "$VISTAS/$n.txt" ]] || faltan+=("$f")
done
if [[ ${#faltan[@]} -gt 0 ]] && command -v magick >/dev/null; then
    # Se lee el original una vez y salen las dos imágenes y la medida
    printf '%s\0' "${faltan[@]}" | xargs -0 -P "$(nproc)" -I{} sh -c '
        n="$(basename "${1%.*}")"
        magick "$1[0]" -format "%w×%h" -write info:"$3/$n.txt" \
            \( +clone -thumbnail 360x640^ -gravity center -extent 360x640 -quality 85 -write "$2/$n.jpg" +delete \) \
            -thumbnail 640x360^ -gravity center -extent 640x360 -quality 80 "$3/$n.jpg" 2>/dev/null
    ' _ {} "$TARJETAS" "$VISTAS"
fi

for f in "${FONDOS[@]}"; do
    n="$(basename "${f%.*}")"
    printf '%s\t%s\t%s\t%s\n' "$f" "$TARJETAS/$n.jpg" "$VISTAS/$n.jpg" "$(cat "$VISTAS/$n.txt" 2>/dev/null)"
done
