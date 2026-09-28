#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  bloquear.sh — Bloquea la pantalla (Mod+BackSpace, swayidle, suspender...)
#
#  Usa la pantalla de bloqueo de Yoru (Quickshell, paneles/Bloqueo.qml). Si
#  Quickshell no contesta, swaylock: la pantalla se bloquea siempre.
#
#  No termina hasta que niri confirma el bloqueo (máx. 3 s): así, al
#  suspender, el escritorio no llega a verse un instante al despertar.
# ----------------------------------------------------------------------------

if qs -c yoru ipc call bloqueo bloquear >/dev/null 2>&1; then
    for _ in $(seq 30); do
        [[ "$(qs -c yoru ipc call bloqueo bloqueada 2>/dev/null)" == "true" ]] && exit 0
        sleep 0.1
    done
fi

# Quickshell no está o no ha podido bloquear
exec swaylock -f
