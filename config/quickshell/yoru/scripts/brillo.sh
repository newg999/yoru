#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  brillo.sh — Brillo de las pantallas para comun/Brillo.qml
#
#    brillo.sh leer              una línea por pantalla: «id<TAB>nombre<TAB>%»
#    brillo.sh poner <id> <%>    cambia el brillo de esa pantalla
#
#  id: «bl:<dispositivo>» para la pantalla del portátil (brightnessctl) o
#  «ddc:<bus i2c>» para monitores externos por DDC/CI (ddcutil). ddcutil es
#  lento (~1 s por orden): Brillo.qml agrupa los cambios.
# ----------------------------------------------------------------------------

leer() {
    # Portátil: «intel_backlight,backlight,120,50%,240»
    if command -v brightnessctl >/dev/null; then
        brightnessctl -m -c backlight -l 2>/dev/null | while IFS=, read -r disp _ _ pct _; do
            printf 'bl:%s\tPantalla del portátil\t%s\n' "$disp" "${pct%\%}"
        done
    fi
    # Monitores externos
    if command -v ddcutil >/dev/null; then
        ddcutil detect --brief 2>/dev/null | awk '
            /^Display/            { bus = ""; nombre = "" }
            /I2C bus:/            { sub(/.*i2c-/, ""); bus = $0 }
            /Monitor:/            { sub(/.*Monitor: */, ""); split($0, m, ":"); nombre = m[1] " " m[2]; print bus "\t" nombre }
        ' | while IFS=$'\t' read -r bus nombre; do
            # «VCP 10 C 80 100» → actual y máximo
            read -r _ _ _ actual max < <(ddcutil --bus "$bus" getvcp 10 --brief 2>/dev/null)
            [[ -n "$max" && "$max" -gt 0 ]] || continue
            printf 'ddc:%s\t%s\t%s\n' "$bus" "$nombre" "$(( actual * 100 / max ))"
        done
    fi
}

poner() {
    local id="$1" pct="$2"
    case "$id" in
        bl:*)  brightnessctl -q -d "${id#bl:}" set "${pct}%" ;;
        # --noverify: no releer después de escribir (la mitad de tiempo)
        ddc:*) ddcutil --bus "${id#ddc:}" --noverify setvcp 10 "$pct" ;;
    esac
}

case "$1" in
    leer)  leer ;;
    poner) poner "$2" "$3" ;;
    *)     echo "Uso: brillo.sh leer | poner <id> <porcentaje>" >&2; exit 2 ;;
esac
