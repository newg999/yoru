#!/usr/bin/env bash
# ============================================================================
#  install.sh — Instalador de Yoru (Fedora + Niri)
# ----------------------------------------------------------------------------
#  Qué hace, en orden:
#    1. Comprueba que estás en Fedora y que no lo ejecutas como root
#    2. Actualiza el sistema, añade el repositorio de Brave e instala los
#       paquetes de packages.txt (y, si hay gráfica NVIDIA, su driver)
#    3. Descarga la fuente JetBrainsMono Nerd Font (iconos de la barra)
#    4. Hace copia de seguridad de tus configs actuales
#    5. Enlaza (symlink) las carpetas de config/ en ~/.config/
#       y pregunta si quieres bajar los fondos anime (5, ~20 MB)
#    6. Activa servicios (bluetooth, energía) y, si no tienes ninguna,
#       la pantalla de inicio de sesión (greetd + gtkgreet, con el estilo de Yoru)
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

set -Eeuo pipefail   # -E: el aviso de abajo también salta dentro de las funciones

# Si algo falla, el script se para (set -e). Que al menos se sepa dónde y qué hacer
trap 'error "La instalación se ha parado en la línea $LINENO de install.sh (mira el mensaje de arriba)."
      error "Cuando lo arregles, vuelve a ejecutar ./install.sh: lo que ya esté hecho se salta."' ERR

# Carpeta donde está este script (el repositorio), da igual desde dónde lo lances
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_ROOT="$HOME/.local/state/yoru/backups"
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

    # Si se clonó con "sudo git clone", la carpeta es de root: los enlaces se
    # crean, pero luego nada se puede modificar (ni tú ni el instalador)
    if [[ "$(stat -c %U "$REPO")" != "$USER" ]] || \
            find "$REPO" ! -user "$USER" -print -quit 2>/dev/null | grep -q .; then
        error "La carpeta $REPO no es tuya (¿la clonaste con sudo?). Arréglalo con:"
        error "    sudo chown -R $USER: $REPO"
        error "y vuelve a ejecutar ./install.sh"
        exit 1
    fi
}

# ------------------------------------------------------------------ Paquetes
# Primero, el sistema al día. Si no, un paquete nuevo puede necesitar una
# biblioteca más reciente que la instalada y no arrancar (pasó con Okular:
# "undefined symbol ... GLIBCXX" con una libstdc++ antigua).
actualizar_sistema() {
    paso "Actualizando el sistema (puede tardar un rato la primera vez)"
    if sudo dnf upgrade -y --refresh; then
        ok "Sistema al día"
    else
        aviso "No se pudo actualizar. Sigo, pero conviene hacerlo luego: sudo dnf upgrade --refresh"
    fi
}

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

# Flathub completo: Fedora trae una versión filtrada con solo unas pocas apps
repo_flathub() {
    paso "Flathub (apps para la tienda)"
    if ! command -v flatpak >/dev/null; then
        aviso "flatpak no está instalado. La tienda solo mostrará paquetes de Fedora."
        return
    fi
    if sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
            && sudo flatpak remote-modify --no-filter --enable flathub; then
        ok "Listo (sin filtro)"
        # Tema oscuro también para las apps GTK3 instaladas como Flatpak
        sudo flatpak install -y --noninteractive flathub org.gtk.Gtk3theme.adw-gtk3-dark >/dev/null 2>&1 \
            && ok "Tema oscuro para apps Flatpak"
    else
        aviso "No se pudo configurar Flathub"
    fi
}

instalar_paquetes() {
    paso "Instalando paquetes (packages.txt)"
    # Lee el archivo quitando comentarios y líneas vacías
    mapfile -t PAQUETES < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$REPO/packages.txt" | grep -v '^[[:space:]]*$' | awk '{print $1}')

    # Todos de golpe (rápido). --skip-unavailable: si alguno no existe en esta
    # versión de Fedora (p. ej. cliphist en Fedora 43), se instala el resto
    if sudo dnf install -y --skip-unavailable "${PAQUETES[@]}"; then
        local faltan=()
        for p in "${PAQUETES[@]}"; do
            rpm -q --whatprovides "$p" >/dev/null 2>&1 || faltan+=("$p")
        done
        if (( ${#faltan[@]} )); then
            aviso "No están en los repositorios de tu Fedora: ${faltan[*]}"
        else
            ok "Todos los paquetes instalados"
        fi
        return
    fi

    # Si aun así falla (un conflicto, un repositorio caído...), uno a uno
    # para saber cuál es el problemático

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

# cliphist (historial del portapapeles) no está en los repositorios de
# Fedora 43: en ese caso se baja el programa oficial de su GitHub
CLIPHIST_VERSION="v0.7.0"
cliphist_si_falta() {
    command -v cliphist >/dev/null && return 0
    if [[ "$(uname -m)" != "x86_64" ]]; then
        aviso "cliphist no está disponible para $(uname -m): sin historial del portapapeles"
        return 0
    fi
    paso "cliphist (historial del portapapeles) desde GitHub"
    local tmp
    tmp="$(mktemp)"
    if curl -fsSL -o "$tmp" \
            "https://github.com/sentriz/cliphist/releases/download/$CLIPHIST_VERSION/$CLIPHIST_VERSION-linux-amd64" \
            && sudo install -m 755 "$tmp" /usr/local/bin/cliphist; then
        ok "cliphist $CLIPHIST_VERSION en /usr/local/bin"
    else
        aviso "No se pudo descargar cliphist: el portapapeles funciona, pero sin historial"
    fi
    rm -f "$tmp"
}

# -------------------------------------------------------------------- NVIDIA
# Si hay una gráfica NVIDIA se instala su driver oficial (RPM Fusion).
# Con Secure Boot activado, el driver hay que firmarlo con una clave propia
# que la BIOS debe aceptar: se prepara aquí y se registra al reiniciar.
NVIDIA_CLAVE_PENDIENTE=0
CLAVE_AKMODS="/etc/pki/akmods/certs/public_key.der"

tiene_nvidia() {
    local d
    for d in /sys/bus/pci/devices/*; do
        [[ "$(cat "$d/vendor" 2>/dev/null)" == "0x10de" ]] || continue   # 0x10de = NVIDIA
        # Clase 0x03... = tarjeta gráfica (así no cuenta el audio HDMI de la tarjeta)
        [[ "$(cat "$d/class" 2>/dev/null)" == 0x03* ]] && return 0
    done
    return 1
}

drivers_nvidia() {
    tiene_nvidia || return 0
    paso "Tarjeta gráfica NVIDIA detectada"
    if rpm -q akmod-nvidia >/dev/null 2>&1; then
        ok "El driver de NVIDIA ya estaba instalado"
        return
    fi
    echo "  Sin su driver oficial, la tarjeta va lenta y sin aceleración."
    echo "  Se instala desde RPM Fusion (el repositorio de Fedora para software no libre)."
    if [[ ! -t 0 ]]; then
        aviso "Sin terminal para preguntar: me lo salto. Vuelve a ejecutar ./install.sh para instalarlo."
        return
    fi
    local respuesta
    read -rp "  ¿Instalar el driver de NVIDIA? [S/n] " respuesta
    if [[ "${respuesta,,}" == n* ]]; then
        aviso "No se instala. La gráfica NVIDIA funcionará con el driver libre (nouveau), más lento."
        return
    fi

    # 1. RPM Fusion (libre y no libre)
    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        local fedora
        fedora="$(rpm -E %fedora)"
        if ! sudo dnf install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"; then
            aviso "No se pudo añadir RPM Fusion. Sin él no hay driver de NVIDIA."
            return
        fi
    fi
    ok "RPM Fusion"

    # 2. Secure Boot: la clave tiene que existir ANTES de compilar el driver,
    #    para que salga firmado
    sudo dnf install -y akmods mokutil >/dev/null
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        paso "Secure Boot está activado: hay que registrar una clave"
        sudo kmodgenca -a >/dev/null 2>&1 || true
        if mokutil --test-key "$CLAVE_AKMODS" 2>/dev/null | grep -qi "already enrolled"; then
            ok "La clave ya estaba registrada"
        else
            echo
            echo "  El driver de NVIDIA se compila en tu equipo, y con Secure Boot la BIOS"
            echo "  solo carga lo que esté firmado con una clave que ella conozca. Vamos a"
            echo "  darle la nuestra en dos pasos:"
            echo "    · Ahora: inventa una contraseña de UN SOLO USO (se usa una vez al"
            echo "      reiniciar y ya). Consejo: solo números, p. ej. 12345678, porque en"
            echo "      esa pantalla el teclado es inglés y los símbolos cambian de sitio."
            echo "    · Al reiniciar: una pantalla azul te pedirá confirmarla (te lo"
            echo "      recuerdo al final)."
            echo
            if sudo mokutil --import "$CLAVE_AKMODS"; then
                NVIDIA_CLAVE_PENDIENTE=1
                ok "Clave preparada: se registra al reiniciar"
            else
                aviso "No se pudo preparar la clave. Repite luego: sudo mokutil --import $CLAVE_AKMODS"
            fi
        fi
    else
        ok "Secure Boot desactivado: no hace falta registrar ninguna clave"
    fi

    # 3. El driver (akmod: se recompila solo con cada kernel nuevo)
    #    + nvidia-smi y la aceleración de vídeo
    if ! sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda; then
        aviso "No se pudo instalar el driver de NVIDIA"
        return
    fi
    echo "  Compilando el driver (unos minutos; si no da tiempo, se termina solo al arrancar)..."
    sudo akmods --force >/dev/null 2>&1 || true
    ok "Driver de NVIDIA instalado"

    # 4. Ajuste de la documentación de niri: sin él, niri puede acaparar ~1 GB de VRAM
    sudo install -D -m 644 "$REPO/system/nvidia/50-niri-vram.json" \
        /etc/nvidia/nvidia-application-profiles-rc.d/50-niri-vram.json
    ok "Perfil de NVIDIA para niri (memoria de vídeo)"
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

    # Colores oscuros para las apps KDE (Okular): es un archivo, no una carpeta
    enlazar "$REPO/config/kdeglobals" "$CONFIG_DIR/kdeglobals"

    paso "Enlazando fondos de pantalla"
    enlazar "$REPO/wallpapers" "$HOME/.local/share/wallpapers"

    # Git ya guarda que son ejecutables; esto es solo por si vino en un .zip
    chmod +x "$REPO"/config/niri/scripts/*.sh "$REPO"/config/rofi/scripts/*.{sh,py} \
        "$REPO"/wallpapers/descargar.sh 2>/dev/null || true
    mkdir -p "$HOME/Pictures/Screenshots"
}

# ------------------------------------------------------------------- Fondos
# Los fondos anime no están en el repo (son de sus autores): se descargan de
# wallhaven.cc. Son bastantes MB, así que se pregunta antes.
bajar_fondos() {
    paso "Fondos de pantalla anime"
    local total faltan
    total=$(grep -cv '^[[:space:]]*\(#\|$\)' "$REPO/wallpapers/wallhaven.txt" || true)
    faltan=0
    while read -r id url; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        [[ -f "$REPO/wallpapers/anime-$id.${url##*.}" ]] || faltan=$((faltan + 1))
    done < "$REPO/wallpapers/wallhaven.txt"

    if [[ $faltan -eq 0 ]]; then
        ok "Ya están los $total"
        return
    fi
    if [[ ! -t 0 ]]; then
        aviso "Sin terminal para preguntar: no se bajan. Hazlo luego con wallpapers/descargar.sh"
        return
    fi
    local respuesta
    read -rp "  ¿Descargar $faltan fondos (unos 20 MB)? [s/N] " respuesta
    if [[ "${respuesta,,}" == s* ]]; then
        "$REPO/wallpapers/descargar.sh" && ok "Fondos descargados" \
            || aviso "No se pudieron bajar algunos (¿sin internet?). Reintenta con wallpapers/descargar.sh"
    else
        aviso "Saltado. Puedes bajarlos cuando quieras con wallpapers/descargar.sh"
    fi
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

    # Los PDF se abren con Okular
    xdg-mime default org.kde.okular.desktop application/pdf 2>/dev/null && ok "PDF → Okular"

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
    if ! command -v gtkgreet >/dev/null || ! command -v greetd >/dev/null; then
        aviso "greetd o gtkgreet no están instalados, me lo salto"
        return
    fi

    # Todo esto es de root (lo usa el usuario "greetd", no tú): se copia.
    # La config original de greetd se guarda una vez, por si quieres volver
    if [[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.original ]]; then
        sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.original
    fi
    local f
    for f in config.toml niri-greeter.kdl gtkgreet.css; do
        sudo install -m 644 "$REPO/system/greetd/$f" "/etc/greetd/$f"
    done

    # Fondo: el que tengas puesto ahora; si no, el primero de la lista
    local fondo=""
    [[ -f "$HOME/.cache/wallpaper-actual" ]] && fondo="$(readlink -f "$(cat "$HOME/.cache/wallpaper-actual")" 2>/dev/null || true)"
    if [[ ! -f "$fondo" ]]; then
        fondo="$(ls "$REPO"/wallpapers/anime-* 2>/dev/null | head -n1 || true)"
    fi
    [[ -f "$fondo" ]] || fondo="$REPO/wallpapers/nord-aurora.png"
    sudo install -D -m 644 "$fondo" /usr/share/backgrounds/yoru/inicio

    # Lista de sesiones para el desplegable (Niri, y GNOME si lo tienes)
    [[ -x /usr/libexec/gtkgreet-update-environments ]] \
        && sudo /usr/libexec/gtkgreet-update-environments --write >/dev/null 2>&1 || true

    sudo systemctl enable greetd >/dev/null 2>&1
    sudo systemctl set-default graphical.target >/dev/null 2>&1
    ok "Pantalla de inicio gráfica (greetd + gtkgreet) activada: se verá al reiniciar"
}

# -------------------------------------------------------------------- Barra
# Waybar arranca como servicio de usuario: si se cae, systemd la levanta.
# (el servicio ya viene con waybar y no se activa dentro de GNOME)
activar_barra() {
    paso "Barra (waybar)"
    if systemctl --user enable waybar.service >/dev/null 2>&1; then
        ok "Servicio de usuario activado"
    else
        aviso "No se pudo activar waybar.service (¿está instalado waybar?)"
    fi
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
    # GTK3: "Adwaita-dark" ya no existe en GTK 3.24.5x (vuelve en silencio al
    # tema claro). adw-gtk3-dark además se ve igual que las apps GTK4.
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    # Lo mismo para las apps GTK3 que van por Xwayland (leen este archivo)
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<'INI'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-application-prefer-dark-theme=true
gtk-icon-theme-name=Papirus-Dark
INI
    ok "Tema oscuro (adw-gtk3-dark) e iconos Papirus-Dark"

    # Blueman sin icono en la bandeja (la barra ya tiene su módulo).
    # El agente que muestra el PIN al emparejar sigue funcionando.
    gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']" 2>/dev/null \
        && ok "Blueman sin icono en la bandeja"
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
    local destinos=("$HOME/.local/share/wallpapers" "$CONFIG_DIR/kdeglobals")
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
        bajar_fondos
        activar_barra
        ajustes_gtk
        validar ;;
    "")
        comprobar_sistema
        actualizar_sistema
        repo_brave
        instalar_paquetes
        cliphist_si_falta
        repo_flathub
        drivers_nvidia
        instalar_fuente
        enlazar_todo
        bajar_fondos
        configurar_sistema
        activar_barra
        ajustes_gtk
        validar ;;
    *)
        error "Opción desconocida: $1  (usa --ayuda)"
        exit 1 ;;
esac

echo -e "\n${VERDE}¡Listo!${NC}"
if (( NVIDIA_CLAVE_PENDIENTE )); then
    echo -e "\n${AMARILLO}IMPORTANTE (NVIDIA + Secure Boot): al reiniciar saldrá una pantalla azul${NC}"
    echo "  (MOK Manager). Tienes 10 segundos para pulsar una tecla; si no, se la salta."
    echo "    1. «Enroll MOK»  →  «Continue»  →  «Yes»"
    echo "    2. Escribe la contraseña de un solo uso que pusiste"
    echo "    3. «Reboot»"
    echo "  Si se te pasa, el driver de NVIDIA no cargará. Se repite con:"
    echo "    sudo mokutil --import $CLAVE_AKMODS   y reiniciando otra vez."
    echo "  Para comprobar después que funciona:  nvidia-smi"
    echo
fi
if [[ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" == */greetd.service ]]; then
    echo "  1. Reinicia el equipo:  sudo reboot"
    echo "  2. En la pantalla de inicio, escribe tu usuario y contraseña: entrarás en Niri."
    echo "     (Ctrl+Alt+Supr reinicia y Ctrl+Alt+Fin apaga, sin entrar)"
    echo "  3. Pulsa Super+F1 para ver los atajos."
else
    echo "  1. Cierra la sesión actual."
    echo "  2. En la pantalla de inicio, pulsa el engranaje ⚙ (abajo a la derecha) y elige «Niri»."
    echo "  3. Entra. Pulsa Super+F1 para ver los atajos."
    echo "  Para volver a GNOME, repite el paso 2 eligiendo «GNOME»."
fi
