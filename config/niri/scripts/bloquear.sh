#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  bloquear.sh — Bloquea la pantalla (Mod+BackSpace, swayidle, suspender...)
#
#  Con swaylock (config/swaylock/config). -f: vuelve en cuanto la pantalla
#  está bloqueada, así al suspender el escritorio no llega a verse al despertar.
# ----------------------------------------------------------------------------

exec swaylock -f
