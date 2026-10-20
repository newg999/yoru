#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  flotar.sh — Mod+V: la ventana pasa a flotante (o vuelve a su columna)
#
#  Al hacerla flotante se queda con el tamaño que tenía en la columna: una
#  terminal (que se abre a todo el ancho) flotaba igual de grande y justo
#  encima de las demás. Aquí se le da un tamaño manejable (60 % x 65 %),
#  centrada y, si ya hay otras flotantes en ese escritorio, desplazada un
#  poco por cada una para que no queden exactamente superpuestas.
#
#  Una vez flotante: Mod + arrastrar la mueve, Mod + clic derecho y
#  arrastrar la redimensiona (o Mod +/- el ancho y Mod+Shift +/- el alto).
# ----------------------------------------------------------------------------

niri msg action toggle-window-floating

ventana=$(niri msg -j focused-window)
[[ $(jq -r '.is_floating' <<< "$ventana") == true ]] || exit 0
id=$(jq -r '.id' <<< "$ventana")
escritorio=$(jq -r '.workspace_id' <<< "$ventana")

niri msg action set-window-width --id "$id" 60%
niri msg action set-window-height --id "$id" 65%
niri msg action center-window --id "$id"

# Las otras flotantes de este escritorio: 40 px más abajo y a la derecha por cada una
otras=$(niri msg -j windows | jq --argjson id "$id" --argjson ws "$escritorio" \
    '[.[] | select(.is_floating and .workspace_id == $ws and .id != $id)] | length')
if (( otras > 0 )); then
    paso=$(( (otras % 6) * 40 ))
    niri msg action move-floating-window --id "$id" -x "+$paso" -y "+$paso"
fi
