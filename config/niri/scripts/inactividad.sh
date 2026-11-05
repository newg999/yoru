#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  inactividad.sh — Bloqueo, pantalla y suspensión cuando no tocas nada
#
#  Lanza swayidle con los tiempos de Ajustes › Energía (los lee de
#  ~/.local/state/yoru/ajustes.json; 0 = nunca). Lo arranca niri al entrar
#  (config.kdl) y la barra cada vez que cambias un tiempo: cierra el swayidle
#  que hubiera y pone uno nuevo.
#  Sin el archivo, lo de siempre: bloquea a los 5 min, apaga la pantalla a
#  los 10 y suspende a los 15, solo si va con batería (suspender.sh).
#  Bloquea siempre antes de suspender (y con «loginctl lock-session»).
#  Los 15 s antes de bloquear, la pantalla se va oscureciendo (Bloqueo.qml);
#  si tocas algo, vuelve y vuelve a contar.
#  Un vídeo a pantalla completa (o una app que lo pida) lo detiene todo.
# ----------------------------------------------------------------------------

dir="$(dirname "$(readlink -f "$0")")"

read -r bloquear pantalla suspender siempre < <(python3 - <<'PY'
import json, os
try:
    with open(os.path.expanduser("~/.local/state/yoru/ajustes.json")) as f:
        a = json.load(f)
except Exception:
    a = {}
print(int(a.get("bloquearMin", 5)), int(a.get("pantallaMin", 10)),
      int(a.get("suspenderMin", 15)), int(bool(a.get("suspenderEnchufado", False))))
PY
)

# Con «No suspender» (la cafeína) puesto, nada de esto: ni oscurecer, ni
# bloquear, ni apagar la pantalla, ni suspender. La barra ya se lo pide a niri
# (IdleInhibitor), pero niri no le hace caso si la barra no se ve (una
# ventana a pantalla completa, el overview...): por eso se mira aquí también
# el archivo de la cafeína (comun/Despierto.qml)
despierto="[ \"\$(cat \"\$XDG_RUNTIME_DIR/yoru-despierto\" 2>/dev/null)\" = 1 ] ||"

args=(-w)
if (( bloquear > 0 )); then
    args+=(timeout $((bloquear * 60 - 15)) "$despierto qs -c yoru ipc call bloqueo atenuar"
           resume "qs -c yoru ipc call bloqueo despertar"
           timeout $((bloquear * 60)) "$despierto $dir/bloquear.sh")
fi
(( pantalla > 0 )) && args+=(timeout $((pantalla * 60)) "$despierto niri msg action power-off-monitors"
                             resume "niri msg action power-on-monitors")
if (( suspender > 0 )); then
    if (( siempre )); then
        args+=(timeout $((suspender * 60)) "$despierto $dir/suspender.sh --siempre")
    else
        args+=(timeout $((suspender * 60)) "$despierto $dir/suspender.sh")
    fi
fi
args+=(before-sleep "$dir/bloquear.sh" lock "$dir/bloquear.sh")

pkill -x swayidle
exec swayidle "${args[@]}"
