#!/usr/bin/env bash
# ============================================================================
#  install.sh — Instalador de mis dotfiles (Fedora + Niri)
# ----------------------------------------------------------------------------
#  Qué hace, en orden:
#    1. Comprueba que estás en Fedora y que no lo ejecutas como root
#    2. Añade el repositorio de Brave e instala los paquetes de packages.txt
#    3. Descarga la fuente JetBrainsMono Nerd Font (iconos de la barra)
#    4. Hace copia de seguridad de tus configs actuales
#    5. Enlaza (symlink) las carpetas de config/ en ~/.config/
#    6. Activa servicios (bluetooth, energía) y, si no tienes ninguna,
#       la pantalla de inicio de sesión (greetd + tuigreet)
#    7. Pone tema oscuro e iconos Papirus en las apps GTK
#    8. Valida la configuración de Niri
#
#  Funciona tanto en una Fedora MÍNIMA (sin escritorio) como en una con
#  GNOME. Si ya tienes GNOME, se respeta su pantalla de inicio (GDM).
#
#  Como usa enlaces simbólicos, cualquier cambio que hagas en ~/.config/niri
#  se está haciendo en realidad dentro de este repositorio → git lo ve.
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
BRAVE_REPO="https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo"

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
# Brave no está en los repositorios de Fedora: se añade el suyo oficial
repo_brave() {
    paso "Repositorio de Brave"
    if [[ -f /etc/yum.repos.d/brave-browser.repo ]]; then
        ok "Ya estaba añadido"
        return
    fi
    if sudo curl -fsSL -o /etc/yum.repos.d/brave-browser.repo "$BRAVE_REPO"; then
        ok "Añadido"
    else
        aviso "No se pudo añadir. Brave no se instalará (el resto sí)."
    fi
}

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

# ------------------------------------------------------------------ Sistema
configurar_sistema() {
    paso "Servicios del sistema"
    # --now: los arranca ya, sin esperar a reiniciar. Si ya estaban, no pasa nada.
    for servicio in bluetooth tuned-ppd; do
        if sudo systemctl enable --now "$servicio" >/dev/null 2>&1; then
            ok "$servicio"
        else
            aviso "$servicio no se pudo activar (¿no está instalado?)"
        fi
    done

    # Carpetas personales (Descargas, Imágenes...), según el idioma del sistema
    xdg-user-dirs-update 2>/dev/null && ok "Carpetas personales"

    pantalla_login
}

# Pantalla de inicio de sesión: solo si el sistema no tiene ya una.
# En una Fedora con GNOME ya existe GDM y no se toca.
pantalla_login() {
    paso "Pantalla de inicio de sesión"
    if [[ -e /etc/systemd/system/display-manager.service ]]; then
        local actual
        actual="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
        if [[ "$actual" != "greetd" ]]; then
            ok "Ya tienes una ($actual). No la cambio."
            return
        fi
    fi
    if ! command -v tuigreet >/dev/null; then
        aviso "tuigreet no está instalado, me lo salto"
        return
    fi

    # La config pertenece a root: se copia (guardando la original una vez)
    if [[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.original ]]; then
        sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.original
    fi
    sudo install -m 644 "$REPO/system/greetd/config.toml" /etc/greetd/config.toml

    # tuigreet necesita esta carpeta para recordar el último usuario y sesión
    sudo install -d -m 755 -o greetd -g greetd /var/cache/tuigreet
    command -v restorecon >/dev/null && sudo restorecon -R /var/cache/tuigreet

    sudo systemctl enable greetd >/dev/null 2>&1
    sudo systemctl set-default graphical.target >/dev/null 2>&1
    ok "greetd + tuigreet activado (se verá al reiniciar)"
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
        # Muestra la cabecera de comentarios de este archivo
        awk 'NR > 1 && !/^#/ { exit } NR > 1' "$0" | sed 's/^# \{0,1\}//'
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
        repo_brave
        instalar_paquetes
        instalar_fuente
        enlazar_todo
        configurar_sistema
        ajustes_gtk
        validar ;;
    *)
        error "Opción desconocida: $1  (usa --ayuda)"
        exit 1 ;;
esac

echo -e "\n${VERDE}¡Listo!${NC}"
if [[ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" == */greetd.service ]]; then
    echo "  1. Reinicia el equipo:  sudo reboot"
    echo "  2. En la pantalla de inicio, escribe tu usuario y contraseña: entrarás en Niri."
    echo "     (F2 cambia de sesión, F12 apaga o reinicia)"
    echo "  3. Pulsa Super+F1 para ver los atajos."
else
    echo "  1. Cierra la sesión actual."
    echo "  2. En la pantalla de inicio, pulsa el engranaje ⚙ (abajo a la derecha) y elige «Niri»."
    echo "  3. Entra. Pulsa Super+F1 para ver los atajos."
    echo "  Para volver a GNOME, repite el paso 2 eligiendo «GNOME»."
fi
