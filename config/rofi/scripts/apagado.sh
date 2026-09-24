#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  apagado.sh — Menú de apagado con rofi
#  Atajo: Mod+Shift+BackSpace
#  Para añadir opciones: añade una línea a OPCIONES y un caso en el `case`.
# ----------------------------------------------------------------------------

OPCIONES=$'  Bloquear\n  Suspender\n  Cerrar sesión\n  Reiniciar\n  Apagar'
OPCIONES="$(printf '%b' "$OPCIONES")"

TEMA='window { width: 320px; } listview { lines: 5; } inputbar { enabled: false; }'

eleccion="$(printf '%s\n' "$OPCIONES" | rofi -dmenu -i -no-custom -p '' \
    -mesg "Sesión de <b>$(whoami)</b>" \
    -theme-str "$TEMA" -u 4)"

case "$eleccion" in
    *Bloquear*)        swaylock ;;
    *Suspender*)       swaylock -f && systemctl suspend ;;
    *"Cerrar sesión"*) niri msg action quit --skip-confirmation ;;
    *Reiniciar*)       systemctl reboot ;;
    *Apagar*)          systemctl poweroff ;;
esac
