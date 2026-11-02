#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  xkill.sh — Ctrl+Alt+Esc: matar la ventana que pulses (como xkill)
#
#  xkill solo sirve para apps de X11; esto vale para todas: niri deja elegir
#  una ventana con el ratón (Esc cancela) y se mata su proceso de golpe
#  (kill -9), para las que se han colgado y no se cierran con Mod+Q.
# ----------------------------------------------------------------------------

notify-send -a Yoru -i process-stop -t 4000 "Matar una ventana" "Haz clic en la ventana colgada (Esc para cancelar)"

ventana=$(niri msg -j pick-window)
[[ -z "$ventana" || "$ventana" == null ]] && exit 0

pid=$(jq -r '.pid // empty' <<< "$ventana")
nombre=$(jq -r '.title // .app_id // "la ventana"' <<< "$ventana")
[[ -n "$pid" ]] || { notify-send -a Yoru -i dialog-error "No se pudo matar" "$nombre no tiene proceso conocido"; exit 1; }

if kill -9 "$pid" 2>/dev/null; then
    notify-send -a Yoru -i process-stop "Ventana matada" "$nombre"
else
    notify-send -a Yoru -i dialog-error "No se pudo matar" "$nombre (proceso $pid)"
fi
