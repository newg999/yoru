#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  pantallas.sh — Apaga la pantalla del portátil si hay un monitor externo
#
#  No se pone "off" fijo en local.kdl porque, si desconectas el monitor,
#  te quedarías sin ninguna pantalla encendida. Este script solo la apaga
#  cuando detecta otra salida conectada.
#
#  Uso:  pantallas.sh [salida-del-portátil]   (por defecto eDP-1)
#  Volver a encenderla a mano: Mod+Alt+P
# ----------------------------------------------------------------------------

INTERNA="${1:-eDP-1}"

# niri msg outputs solo lista las salidas conectadas. Líneas como:
#   Output "Lenovo Group Limited L24q-35 ..." (HDMI-A-1)
externas="$(niri msg outputs | grep '^Output' | grep -v "($INTERNA)")"

if [[ -n "$externas" ]]; then
    niri msg output "$INTERNA" off
fi
