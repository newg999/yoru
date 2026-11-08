#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  megasync.sh — Arranca MEGAsync escondido en la bandeja
#  Si MEGAsync arranca antes que la barra (Quickshell, que es quien hace de
#  bandeja), cree que no hay bandeja y abre su ventana arriba a la derecha.
#  Así que esperamos a que la bandeja esté lista y luego lo lanzamos.
#  Su propio autostart (~/.config/autostart/megasync.desktop, que MEGAsync
#  reescribe a su gusto) lo arrancaría antes que la barra: se desactiva
#  el servicio que systemd genera con él, para que solo lo lance este script.
# ----------------------------------------------------------------------------

command -v megasync >/dev/null || exit 0
systemctl --user mask app-megasync@autostart.service >/dev/null 2>&1
pgrep -x megasync >/dev/null && exit 0

# Hasta 60 s esperando a la bandeja (StatusNotifierWatcher en el bus)
for _ in $(seq 120); do
    busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
    sleep 0.5
done
sleep 2   # que la barra termine de registrarse como bandeja

exec megasync
