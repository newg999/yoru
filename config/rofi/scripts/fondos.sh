#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  fondos.sh — Elegir fondo de pantalla con miniaturas (rofi en cuadrícula)
#
#  Atajo: Mod+Alt+W   ·   Mod+Alt+Shift+W pasa al siguiente sin menú
#
#  La primera vez crea las miniaturas (cuadradas, recortadas por el centro;
#  tarda unos segundos). Se guardan en ~/.cache/fondos-miniaturas y solo se
#  hacen las de los fondos nuevos.
# ----------------------------------------------------------------------------

DIR="$HOME/.local/share/wallpapers"
CACHE="$HOME/.cache/fondos-miniaturas"
ACTUAL="$(cat "$HOME/.cache/wallpaper-actual" 2>/dev/null)"
mkdir -p "$CACHE"

mapfile -t FONDOS < <(find -L "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if [[ ${#FONDOS[@]} -eq 0 ]]; then
    notify-send -a Fondos "No hay fondos" "Echa imágenes en ~/dotfiles/wallpapers o ejecuta wallpapers/descargar.sh"
    exit 0
fi

# Miniaturas que faltan (en paralelo, una por núcleo)
faltan=()
for f in "${FONDOS[@]}"; do
    [[ -f "$CACHE/$(basename "${f%.*}").jpg" ]] || faltan+=("$f")
done
if [[ ${#faltan[@]} -gt 0 ]]; then
    notify-send -a Fondos "Preparando miniaturas" "${#faltan[@]} fondos, un momento..."
    printf '%s\0' "${faltan[@]}" | xargs -0 -P "$(nproc)" -I{} sh -c \
        'magick "$1[0]" -thumbnail 256x256^ -gravity center -extent 256x256 -quality 85 "$2/$(basename "${1%.*}").jpg"' _ {} "$CACHE"
fi

# Lista para rofi: "nombre\0icon\x1fminiatura"
fila=0
entradas=""
for i in "${!FONDOS[@]}"; do
    f="${FONDOS[$i]}"
    nombre="$(basename "${f%.*}")"
    [[ "$f" == "$ACTUAL" ]] && fila=$i
    entradas+="$nombre\0icon\x1f$CACHE/$nombre.jpg\n"
done

tema='
window   { width: 1140px; }
mainbox  { children: [ listview ]; }
listview { columns: 5; lines: 3; spacing: 10px; flow: horizontal; }
element  { orientation: vertical; padding: 6px; spacing: 0; border-radius: 12px; }
element-icon { size: 196px; horizontal-align: 0.5; }
element-text { enabled: false; }
'

eleccion=$(printf "$entradas" | rofi -dmenu -i -show-icons -no-custom -format i \
    -p "Fondo" -selected-row "$fila" -theme-str "$tema")

[[ -n "$eleccion" ]] && exec ~/.config/niri/scripts/wallpaper.sh "${FONDOS[$eleccion]}"
