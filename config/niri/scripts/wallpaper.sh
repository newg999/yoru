#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  wallpaper.sh — Pone el fondo de pantalla (lo pinta Yoru, con transición;
#  si la barra no está, swaybg)
#
#  Uso:
#    wallpaper.sh          -> pone el último fondo usado (o el primero)
#    wallpaper.sh next     -> pasa al siguiente fondo de la carpeta
#    wallpaper.sh <ruta>   -> pone esa imagen concreta
#
#  Los fondos se buscan en ~/.local/share/wallpapers (el instalador enlaza
#  ahí la carpeta wallpapers/ del repositorio).
#
#  El mismo fondo, desenfocado, se usa en la pantalla de bloqueo
#  (~/.cache/fondo-bloqueo-borroso.jpg; swaylock usa el enlace sin desenfocar
#  ~/.cache/fondo-bloqueo) y en la de inicio de sesión, si
#  install.sh te ha dado permiso sobre /usr/share/backgrounds/yoru/inicio.
# ----------------------------------------------------------------------------

DIR="$HOME/.local/share/wallpapers"
STATE="$HOME/.cache/wallpaper-actual"
BLOQUEO="$HOME/.cache/fondo-bloqueo"
BORROSO="$HOME/.cache/fondo-bloqueo-borroso.jpg"     # ya desenfocado: carga al instante
BORROSO_ORIGEN="$HOME/.cache/fondo-bloqueo-origen"
INICIO="/usr/share/backgrounds/yoru/inicio"
INICIO_ORIGEN="$HOME/.cache/fondo-inicio-origen"   # de qué fondo salió
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

# El fondo lo pinta Yoru (quickshell/yoru/barra/Fondo.qml, con transición):
# lee $STATE al cambiar. Si la barra no responde, swaybg, de reserva
con_yoru=false
[[ "$(timeout 1 qs -c yoru ipc call fondo listo 2>/dev/null)" == true ]] && con_yoru=true

$con_yoru || pkill -x swaybg

if [[ -n "$img" && -f "$img" ]]; then
    mkdir -p "$(dirname "$STATE")"
    echo "$img" > "$STATE"
    $con_yoru || setsid -f swaybg -m fill -i "$img" >/dev/null 2>&1
    ln -sfn "$(realpath "$img")" "$BLOQUEO"
    # Pantalla de bloqueo: el fondo ya desenfocado y pequeño. Desenfocarlo al
    # bloquear (con la imagen entera) tardaba y se veía aparecer de golpe
    if [[ "$(cat "$BORROSO_ORIGEN" 2>/dev/null)" != "$img" ]] && command -v magick >/dev/null; then
        setsid -f sh -c 'magick "$1" -resize 1920x1080^ -blur 0x24 -modulate 70,80 -quality 90 "jpg:$2.tmp" \
            && mv "$2.tmp" "$2" && echo "$1" > "$3"' _ "$img" "$BORROSO" "$BORROSO_ORIGEN" >/dev/null 2>&1
    fi
    # Pantalla de inicio: el fondo desenfocado y algo más oscuro. Solo si ha
    # cambiado (desenfocar tarda un poco) y en segundo plano
    if [[ -w "$INICIO" && "$(cat "$INICIO_ORIGEN" 2>/dev/null)" != "$img" ]]; then
        # (la carpeta es de root: se prepara en ~/.cache y se copia encima)
        setsid -f sh -c 'magick "$1" -resize 1920x1080^ -blur 0x24 -modulate 70,80 "jpg:$3.jpg" \
            && cat "$3.jpg" > "$2" && echo "$1" > "$3"; rm -f "$3.jpg"' \
            _ "$img" "$INICIO" "$INICIO_ORIGEN" >/dev/null 2>&1
    fi
else
    # Sin imágenes todavía: color sólido
    setsid -f swaybg -c "$FALLBACK_COLOR" >/dev/null 2>&1
fi

# Con «yoru tema fondo», los colores siguen al fondo: se recalculan con cada
# cambio (en segundo plano, para no retrasar el fondo)
modo_tema="$(cat "$HOME/.local/state/yoru/tema/modo" 2>/dev/null)"
if [[ "$modo_tema" == "fondo" || "$modo_tema" == "fondo-claro" ]]; then
    setsid -f python3 "$(dirname "$(realpath "$0")")/../../../tema/aplicar.py" "$modo_tema" >/dev/null 2>&1
fi
