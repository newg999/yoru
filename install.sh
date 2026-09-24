#!/usr/bin/env bash
# ============================================================================
#  install.sh — Instalador de mis dotfiles (Fedora + Niri)
# ----------------------------------------------------------------------------
#  Qué hace, en orden:
#    1. Comprueba que estás en Fedora y que no lo ejecutas como root
#    2. Instala los paquetes de packages.txt con dnf
#    3. Descarga la fuente JetBrainsMono Nerd Font (iconos de la barra)
#    4. Hace copia de seguridad de tus configs actuales
#    5. Enlaza (symlink) las carpetas de config/ en ~/.config/
#    6. Pone tema oscuro e iconos Papirus en las apps GTK
#    7. Valida la configuración de Niri
#
#  Como usa enlaces simbólicos, cualquier cambio que hagas en ~/.config/niri
#  se está haciendo en realidad dentro de este repositorio → git lo ve.
#
#  GNOME no se toca: seguirá disponible en la pantalla de inicio de sesión.
#
#  Opciones:
#    ./install.sh               instalación completa
#    ./install.sh --sin-paquetes   solo fuente + enlaces (no usa dnf)
#    ./install.sh --deshacer       quita los enlaces y restaura la última copia
#    ./install.sh --ayuda
# ============================================================================

set -euo pipefail

# Carpeta donde está este script (el repositorio), da igual desde dónde lo lances
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_ROOT="$HOME/.local/state/mis-dotfiles/backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"

# ---------------------------------------------------------------- Mensajes
AZUL='\033[1;34m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; ROJO='\033[1;31m'; NC='\033[0m'
paso()  { echo -e "\n${AZUL}==>${NC} $*"; }
ok()    { echo -e "  ${VERDE}✔${NC} $*"; }
aviso() { echo -e "  ${AMARILLO}!${NC} $*"; }
error() { echo -e "  ${ROJO}✘${NC} $*" >&2; }

# ------------------------------------------------------------- Comprobaciones
comprobar_sistema() {
    paso "Comprobando el sistema"
    if [[ $EUID -eq 0 ]]; then
        error "No ejecutes este script como root ni con sudo. Ya pedirá la contraseña cuando haga falta."
        exit 1
    fi
    if [[ ! -f /etc/fedora-release ]]; then
        error "Este script está pensado para Fedora."
        exit 1
    fi
    ok "$(cat /etc/fedora-release)"
}

# ------------------------------------------------------------------ Paquetes
instalar_paquetes() {
    paso "Instalando paquetes (packages.txt)"
    # Lee el archivo quitando comentarios y líneas vacías
    mapfile -t PAQUETES < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$REPO/packages.txt" | grep -v '^[[:space:]]*$' | awk '{print $1}')

    # Primero intenta todos de golpe (rápido). Si falla alguno,
    # los instala uno a uno para saber cuál es el problemático.
    if sudo dnf install -y "${PAQUETES[@]}"; then
        ok "Todos los paquetes instalados"
        return
    fi

    aviso "Algo falló. Instalando uno a uno..."
    local fallidos=()
    for p in "${PAQUETES[@]}"; do
        if sudo dnf install -y "$p" >/dev/null 2>&1; then
            ok "$p"
        else
            error "$p"
            fallidos+=("$p")
        fi
    done
    if (( ${#fallidos[@]} )); then
        aviso "No se pudieron instalar: ${fallidos[*]}"
        aviso "El resto de la instalación sigue. Revísalos luego a mano."
    fi
}

# -------------------------------------------------------------------- Fuente
instalar_fuente() {
    paso "Fuente JetBrainsMono Nerd Font"
    if fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" >/dev/null; then
        ok "Ya estaba instalada"
        return
    fi
    mkdir -p "$FONT_DIR"
    if curl -fL --progress-bar "$FONT_URL" | tar -xJ -C "$FONT_DIR"; then
        fc-cache -f >/dev/null
        ok "Instalada en $FONT_DIR"
    else
        aviso "No se pudo descargar. Los iconos de la barra saldrán como cuadrados."
        aviso "Descárgala a mano desde https://www.nerdfonts.com/font-downloads"
    fi
}

# ------------------------------------------------------------------- Enlaces
# enlazar <origen en el repo> <destino en el sistema>
enlazar() {
    local origen="$1" destino="$2"

    # Ya está enlazado a este repo: nada que hacer
    if [[ -L "$destino" && "$(readlink -f "$destino")" == "$(readlink -f "$origen")" ]]; then
        ok "$(basename "$destino") (ya enlazado)"
        return
    fi

    # Existe algo: se guarda en la copia de seguridad
    if [[ -e "$destino" || -L "$destino" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$destino" "$BACKUP_DIR/"
        aviso "$(basename "$destino") existente → copia en $BACKUP_DIR"
    fi

    mkdir -p "$(dirname "$destino")"
    ln -s "$origen" "$destino"
    ok "$destino → $origen"
}

enlazar_todo() {
    paso "Enlazando configuraciones en $CONFIG_DIR"
    for carpeta in "$REPO"/config/*/; do
        carpeta="${carpeta%/}"
        enlazar "$carpeta" "$CONFIG_DIR/$(basename "$carpeta")"
    done

    paso "Enlazando fondos de pantalla"
    enlazar "$REPO/wallpapers" "$HOME/.local/share/wallpapers"

    chmod +x "$REPO"/config/niri/scripts/*.sh
    mkdir -p "$HOME/Pictures/Screenshots"
}

# --------------------------------------------------------------- Apps GTK
# Tema oscuro e iconos Papirus para Nautilus, Calendario, etc.
# (son ajustes del sistema: también se notan si vuelves a GNOME)
ajustes_gtk() {
    paso "Tema oscuro para las apps GTK"
    if ! command -v gsettings >/dev/null; then
        aviso "gsettings no está disponible, me lo salto"
        return
    fi
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'   # GTK4 / libadwaita
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'     # GTK3
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    ok "Tema oscuro e iconos Papirus-Dark"
}

# ------------------------------------------------------------------ Validar
validar() {
    paso "Validando la configuración de Niri"
    if ! command -v niri >/dev/null; then
        aviso "niri no está instalado, me salto la validación"
        return
    fi
    if niri validate -c "$CONFIG_DIR/niri/config.kdl"; then
        ok "config.kdl correcta"
    else
        error "La config de Niri tiene errores (mira el mensaje de arriba)"
    fi
}

# ------------------------------------------------------------------ Deshacer
deshacer() {
    paso "Quitando enlaces que apuntan a $REPO"
    local destinos=("$HOME/.local/share/wallpapers")
    for carpeta in "$REPO"/config/*/; do
        destinos+=("$CONFIG_DIR/$(basename "${carpeta%/}")")
    done
    for d in "${destinos[@]}"; do
        if [[ -L "$d" && "$(readlink -f "$d")" == "$REPO"/* ]]; then
            rm "$d"
            ok "Quitado $d"
        fi
    done

    local ultima
    ultima="$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | tail -n1 || true)"
    if [[ -z "$ultima" ]]; then
        aviso "No hay copias de seguridad que restaurar"
        return
    fi
    paso "Restaurando copia $ultima"
    for item in "$ultima"*; do
        [[ -e "$item" ]] || continue
        local nombre destino
        nombre="$(basename "$item")"
        if [[ "$nombre" == "wallpapers" ]]; then
            destino="$HOME/.local/share/wallpapers"
        else
            destino="$CONFIG_DIR/$nombre"
        fi
        if [[ -e "$destino" ]]; then
            aviso "$destino ya existe, no lo sobrescribo"
        else
            mv "$item" "$destino"
            ok "Restaurado $destino"
        fi
    done
}

# ---------------------------------------------------------------------- Main
case "${1:-}" in
    --ayuda|-h|--help)
        sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
        exit 0 ;;
    --deshacer)
        deshacer
        exit 0 ;;
    --sin-paquetes)
        comprobar_sistema
        instalar_fuente
        enlazar_todo
        ajustes_gtk
        validar ;;
    "")
        comprobar_sistema
        instalar_paquetes
        instalar_fuente
        enlazar_todo
        ajustes_gtk
        validar ;;
    *)
        error "Opción desconocida: $1  (usa --ayuda)"
        exit 1 ;;
esac

echo -e "\n${VERDE}¡Listo!${NC}"
echo "  1. Cierra la sesión de GNOME."
echo "  2. En la pantalla de inicio, pulsa el engranaje ⚙ (abajo a la derecha) y elige «Niri»."
echo "  3. Entra. Pulsa Super+F1 para ver los atajos."
echo "  Para volver a GNOME, repite el paso 2 eligiendo «GNOME»."
