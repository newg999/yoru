#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  suspender.sh — Suspende el equipo, pero solo si va con batería
#
#  Lo llama swayidle tras un rato sin tocar nada (inactividad.sh). Enchufado no
#  hace nada: así un PC o un portátil en la mesa no se duermen solos, pero
#  uno que te dejas abierto con batería no la gasta entera.
#  Al suspender, swayidle bloquea antes (before-sleep).
#  Con --siempre (Ajustes › Energía › «También enchufado») suspende siempre.
# ----------------------------------------------------------------------------

[[ ${1:-} == --siempre ]] && exec systemctl suspend

hay_bateria=false
for fuente in /sys/class/power_supply/*; do
    tipo=$(cat "$fuente/type" 2>/dev/null)
    # Las pilas de un ratón, un mando o unos cascos inalámbricos (scope
    # Device) no cuentan: si no, un PC con ratón inalámbrico se suspendería
    [[ $(cat "$fuente/scope" 2>/dev/null) == Device ]] && continue
    # Cargador conectado (normal o por USB-C): no se suspende
    if [[ $tipo != Battery && $(cat "$fuente/online" 2>/dev/null) == 1 ]]; then
        exit 0
    fi
    [[ $tipo == Battery ]] && hay_bateria=true
done

$hay_bateria && exec systemctl suspend
