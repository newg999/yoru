#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  portapapeles.sh — Vigila que el portapapeles conteste
#
#    wl-paste --watch ~/.config/niri/scripts/portapapeles.sh   (al arrancar)
#
#  Algunas apps (HyprFM al copiar archivos, p. ej.) anuncian que tienen texto
#  pero nunca lo entregan. Qt lee el portapapeles al enfocar un campo de texto
#  y espera ~1 s por cada tipo, así que Quickshell se congela (el lanzador de
#  Mod+Space no sale, la barra va a tirones). Cuando pasa eso, este script se
#  queda con el portapapeles: guarda la lista de archivos si la app la da, y si
#  no, lo vacía. Si la app contesta bien, no toca nada.
# ----------------------------------------------------------------------------

exec </dev/null          # lo que manda wl-paste --watch no hace falta

tipos=$(timeout 1 wl-paste --list-types 2>/dev/null) || exit 0
grep -qE '^text/plain(;charset=utf-8)?$' <<<"$tipos" || exit 0

timeout 1 wl-paste --no-newline --type text/plain >/dev/null 2>&1
[ $? -eq 124 ] || exit 0         # contesta (o no hay nada): todo bien

# La app no contesta: rescatar los archivos copiados, si se puede
if grep -qx 'text/uri-list' <<<"$tipos" &&
   uris=$(timeout 1 wl-paste --no-newline --type text/uri-list 2>/dev/null) &&
   [ -n "$uris" ]; then
    printf '%s' "$uris" | wl-copy --type text/uri-list
else
    wl-copy --clear
fi
