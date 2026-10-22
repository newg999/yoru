#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  descargar.sh — Baja los fondos listados en wallhaven.txt
#
#  Las imágenes son de sus autores (ver wallhaven.cc/w/<id>), así que no se
#  guardan en git: este script las descarga en esta misma carpeta.
#  Las que ya estén bajadas se saltan.
#
#    descargar.sh       baja todas las de la lista
#    descargar.sh 6     solo hasta que haya 6 fondos en la carpeta (lo usa
#                       install.sh, para no bajar decenas sin preguntar)
#
#  Para añadir uno: búscalo en Ajustes › Fondo › Descubrir, que
#  lo baja y lo apunta aquí solo. A mano: copia su id y la URL de la imagen
#  ("https://w.wallhaven.cc/full/...") y añade una línea "id url" a la lista.
# ----------------------------------------------------------------------------

cd "$(dirname "$(realpath "$0")")" || exit 1

maximo="${1:-0}"   # 0 = sin límite
cuantos() { compgen -G "*.@(jpg|jpeg|png|webp)" 2>/dev/null | wc -l; }
shopt -s extglob nocaseglob

while read -r id url; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    (( maximo > 0 && $(cuantos) >= maximo )) && break
    # Los antiguos se llaman anime-<id>; los nuevos, wallhaven-<id>
    compgen -G "*-$id.*" >/dev/null && continue
    destino="wallhaven-$id.${url##*.}"
    echo "Bajando $destino"
    curl -sfL -o "$destino" "$url" || { echo "  falló $id"; rm -f "$destino"; }
done < wallhaven.txt
