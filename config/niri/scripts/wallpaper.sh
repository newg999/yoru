#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  wallpaper.sh — Pone el fondo de pantalla con swaybg
#
#  Uso:
#    wallpaper.sh          -> pone el último fondo usado (o el primero)
#    wallpaper.sh next     -> pasa al siguiente fondo de la carpeta
#    wallpaper.sh <ruta>   -> pone esa imagen concreta
#
#  Los fondos se buscan en ~/.local/share/wallpapers (el instalador enlaza
#  ahí la carpeta wallpapers/ del repositorio).
# ----------------------------------------------------------------------------

DIR="$HOME/.local/share/wallpapers"
STATE="$HOME/.cache/wallpaper-actual"
FALLBACK_COLOR="#2e3440"

mapfile -t FONDOS < <(find -L "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort)

actual="$(cat "$STATE" 2>/dev/null)"

case "${1:-}" in
    "")
        img="$actual"
        [[ -f "$img" ]] || img="${FONDOS[0]:-}"
        ;;
    next)
        img="${FONDOS[0]:-}"
        for i in "${!FONDOS[@]}"; do
            if [[ "${FONDOS[$i]}" == "$actual" ]]; then
                img="${FONDOS[$(( (i + 1) % ${#FONDOS[@]} ))]}"
                break
            fi
        done
        ;;
    *)
        img="$1"
        ;;
esac

pkill -x swaybg

if [[ -n "$img" && -f "$img" ]]; then
    mkdir -p "$(dirname "$STATE")"
    echo "$img" > "$STATE"
    setsid -f swaybg -m fill -i "$img" >/dev/null 2>&1
else
    # Sin imágenes todavía: color sólido
    setsid -f swaybg -c "$FALLBACK_COLOR" >/dev/null 2>&1
fi
