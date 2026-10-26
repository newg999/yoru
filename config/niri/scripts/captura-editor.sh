#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  captura-editor.sh — Captura de una zona y la abre en swappy para editarla
#
#  La pantalla se congela mientras eliges la zona (si no, lo que querías
#  capturar se seguía moviendo): se hace una foto de cada pantalla y Yoru la
#  pone encima de todo (ipc «congelar», en quickshell/yoru/shell.qml); luego
#  eliges la zona con slurp, que empieza siempre de cero (la captura de niri
#  también congela, pero se acuerda del último rectángulo). Esc cancela.
#  Swappy se abre con la imagen para dibujar flechas, texto, rectángulos o
#  difuminar.
#
#  Sustituye a Flameshot: en Niri con dos pantallas, Flameshot falla porque
#  pide la imagen al portal y Niri solo la da si hay una pantalla.
# ----------------------------------------------------------------------------

# Aquí van las fotos y la captura; al cerrar swappy se borra todo (lo que
# quieras guardar, lo guardas desde swappy)
dir=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/yoru-captura-XXXXXX") || exit 1
congelar() { qs -c yoru ipc call congelar "$@" >/dev/null 2>&1; }
trap 'congelar quitar; rm -rf "$dir"' EXIT

# Una foto por pantalla, con el nombre de la salida (DP-1.png...)
for salida in $(niri msg -j outputs | jq -r 'keys[]'); do
    grim -o "$salida" "$dir/$salida.png"
done

# Sin Yoru (o si no responde), se elige sin congelar
if congelar mostrar "$dir"; then
    sleep 0.15
fi

zona=$(slurp -d) || exit 0
# Lo que hay en pantalla es la foto: se captura la zona de ella
grim -g "$zona" "$dir/captura.png" || exit 1
congelar quitar
swappy -f "$dir/captura.png"
