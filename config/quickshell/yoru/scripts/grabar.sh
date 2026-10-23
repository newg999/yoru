#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  grabar.sh — Graba la pantalla para comun/Grabacion.qml
#
#    grabar.sh [sonido] [micro]
#
#  Primero eliges qué grabar con slurp: arrastrar = una zona, un clic = la
#  pantalla entera (Esc cancela: sale sin escribir nada). Luego escribe la ruta del
#  vídeo en una línea y se convierte en wf-recorder, que graba hasta recibir
#  SIGINT (así cierra bien el .mp4).
#
#    sonido  graba también lo que suena (el monitor de la salida por defecto)
#    micro   graba el micrófono (si van los dos, solo el micrófono: wf-recorder
#            solo admite una fuente)
# ----------------------------------------------------------------------------

if ! command -v wf-recorder >/dev/null; then
    notify-send -a Grabación -u critical "Falta wf-recorder" "Instálalo con: sudo dnf install wf-recorder"
    exit 1
fi

# -o: un clic dentro de una pantalla la elige entera (arrastrar sigue
# eligiendo una zona). </dev/null: si la entrada no es una terminal, slurp lee
# de ella más zonas, y la barra la deja abierta: se quedaba esperando sin verse
zona="$(slurp -o -b '#1a1b1e80' -c '#e5e9f0ff' -s '#ffffff14' -w 2 </dev/null)" || exit 1

carpeta="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Grabaciones"
mkdir -p "$carpeta"
archivo="$carpeta/Grabación $(date +%Y-%m-%d\ %H.%M.%S).mp4"

audio=()
for opcion in "$@"; do
    case "$opcion" in
        sonido) audio=(--audio="$(pactl get-default-sink).monitor") ;;
        micro)  audio=(--audio="$(pactl get-default-source)") ;;
    esac
done

# H.264 (lo abre cualquier móvil o reproductor). Fedora no trae libx264: con
# NVIDIA lo hace la gráfica (NVENC); si no, OpenH264 por CPU
if [[ -e /proc/driver/nvidia ]]; then
    video=(-c h264_nvenc)
else
    video=(-c libopenh264 -p b=8M)
fi

echo "$archivo"
# A 60 fps (con un monitor de 240 Hz saldrían archivos enormes) y el sonido
# en AAC (el Opus por defecto no lo abren todos en .mp4)
exec wf-recorder -y -g "$zona" -r 60 "${video[@]}" "${audio[@]}" -C aac -f "$archivo"
