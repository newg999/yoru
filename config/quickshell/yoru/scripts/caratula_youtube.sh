#!/usr/bin/env bash
# ============================================================================
#  caratula_youtube.sh — la miniatura grande de un vídeo de YouTube
#
#    caratula_youtube.sh "<artista>" "<título>"
#
#  Brave (y Chrome) mandan por MPRIS una carátula de 150×83: en la isla se
#  ve borrosa. MPRIS no dice qué vídeo es, así que se busca por el título
#  (en la web de YouTube; si falla, con yt-dlp) y se baja su miniatura (maxresdefault, 1280×720; si no la
#  tiene, hqdefault). Escribe la ruta, o nada si no la encuentra. Se guarda
#  en ~/.cache/quickshell/caratulas: la segunda vez es al instante.
# ============================================================================
set -u
artista="${1:-}"
titulo="${2:-}"
[ -n "$titulo" ] || exit 0

cache="$HOME/.cache/quickshell/caratulas"
mkdir -p "$cache"
o="$cache/yt-$(printf '%s\n%s' "$artista" "$titulo" | md5sum | cut -c1-16).jpg"
if [ -s "$o" ]; then
    echo "$o"
    exit 0
fi

# El título suele llevar ya el artista («Nickzzy - COMEBACK»): no repetirlo
busca="$titulo"
case "$titulo" in *"$artista"*) ;; *) busca="$artista $titulo" ;; esac

# Primero la página de resultados con curl (lo más rápido: ~1 s, casi todo
# red); si YouTube cambia la página y no sale, con yt-dlp (más lento)
q=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$busca")
id=$(curl -fsL --compressed --max-time 8 -H "Accept-Language: es" \
        "https://www.youtube.com/results?search_query=$q" 2>/dev/null \
    | grep -o '"videoId":"[A-Za-z0-9_-]\{11\}"' | head -n1 | cut -d'"' -f4)
if [ -z "$id" ] && command -v yt-dlp >/dev/null; then
    id=$(timeout 15 yt-dlp --no-warnings --flat-playlist --print id "ytsearch1:$busca" 2>/dev/null | head -n1)
fi
[ -n "$id" ] || exit 0

for tam in maxresdefault hqdefault; do
    if curl -fsSL --max-time 10 -o "$o.tmp" "https://i.ytimg.com/vi/$id/$tam.jpg" && [ -s "$o.tmp" ]; then
        mv "$o.tmp" "$o"
        echo "$o"
        exit 0
    fi
done
rm -f "$o.tmp"
