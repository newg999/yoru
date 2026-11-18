#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  musica-mpv.sh — arranca el mpv de «Música de Yoru» (comun/Tocadiscos.qml)
#
#    musica-mpv.sh <socket>
#
#  Sin ventana y esperando órdenes por el socket. Va en su propia unidad de
#  systemd (yoru-musica), aparte de Quickshell: así la música sigue sonando
#  aunque la barra se recargue o se reinicie. Si ya está en marcha, no hace
#  nada. Sin la configuración de los vídeos (uosc, recordar por dónde
#  ibas...): --no-config, y el plugin de MPRIS a mano si está instalado
#  (dnf install mpv-mpris), para que la isla y las teclas multimedia lo vean.
# ----------------------------------------------------------------------------
sock="${1:-${XDG_RUNTIME_DIR:-/tmp}/yoru-musica.sock}"

systemctl --user -q is-active yoru-musica.service && exit 0
systemctl --user reset-failed yoru-musica.service 2>/dev/null

extra=()
for so in /usr/lib64/mpv/mpris.so /usr/lib/mpv/mpris.so /etc/mpv/scripts/mpris.so; do
    [[ -f "$so" ]] && { extra+=("--script=$so"); break; }
done

exec systemd-run --user --quiet --collect --unit=yoru-musica \
    --description="Música de Yoru (mpv)" \
    mpv --no-config --idle=yes --no-video --no-terminal \
        --input-ipc-server="$sock" \
        --gapless-audio=yes --volume-max=100 \
        "${extra[@]}"
