#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  descargar.sh — Baja los fondos listados en wallhaven.txt
#
#  Las imágenes son de sus autores (ver wallhaven.cc/w/<id>), así que no se
#  guardan en git: este script las descarga en esta misma carpeta.
#  Las que ya estén bajadas se saltan.
#
#  Para añadir uno: búscalo en el panel de fondos (Mod+Alt+W → Descubrir), que
#  lo baja y lo apunta aquí solo. A mano: copia su id y la URL de la imagen
#  ("https://w.wallhaven.cc/full/...") y añade una línea "id url" a la lista.
# ----------------------------------------------------------------------------

cd "$(dirname "$(realpath "$0")")" || exit 1

while read -r id url; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    # Los antiguos se llaman anime-<id>; los nuevos, wallhaven-<id>
    compgen -G "*-$id.*" >/dev/null && continue
    destino="wallhaven-$id.${url##*.}"
    echo "Bajando $destino"
    curl -sfL -o "$destino" "$url" || { echo "  falló $id"; rm -f "$destino"; }
done < wallhaven.txt
