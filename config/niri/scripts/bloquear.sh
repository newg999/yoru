#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  bloquear.sh — Bloquea la pantalla (Mod+BackSpace, swayidle, suspender...)
#
#  Con la pantalla de bloqueo de Yoru (quickshell/yoru/bloqueo/Bloqueo.qml).
#  No termina hasta que niri confirma el bloqueo: así, al suspender, el
#  escritorio no llega a verse al despertar. Si la barra no responde, se usa
#  swaylock (config/swaylock/config) para no quedarse nunca sin bloquear.
# ----------------------------------------------------------------------------

# Si responde bien no dice nada; si no («Not ready...», no está), sí
if [[ -z "$(timeout 2 qs -c yoru ipc call bloqueo bloquear 2>&1)" ]]; then
    for _ in $(seq 30); do
        [[ "$(timeout 1 qs -c yoru ipc call bloqueo bloqueada 2>/dev/null)" == true ]] && exit 0
        sleep 0.1
    done
fi

# La barra no está o no ha podido bloquear: swaylock
pgrep -x swaylock >/dev/null || exec swaylock -f
