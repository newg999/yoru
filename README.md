# Yoru 夜 · Fedora + Niri

> *Yoru* es «noche» en japonés: un escritorio oscuro, ligero y hecho a mano, pensado para usarlo cada día y mejorarlo poco a poco.

Escritorio minimalista para **Fedora** basado en **[Niri](https://github.com/niri-wm/niri)**, un gestor de ventanas en mosaico con scroll: las ventanas se colocan en una cinta horizontal infinita. Se instala con un solo script y está pensado para mejorarlo poco a poco (ver la [hoja de ruta](ROADMAP.md)).

<!-- Cuando lo tengas funcionando, haz una captura (Print) y ponla aquí:
![Mi escritorio](preview/escritorio.png)
-->

## Qué incluye

| Pieza | Programa | Configuración |
|---|---|---|
| Compositor | `niri` | `config/niri/` |
| Barra | `waybar` | `config/waybar/` |
| Lanzador y menús | `rofi` | `config/rofi/` |
| Capturas con editor | `slurp` + `swappy` | `config/swappy/` |
| Tienda de apps | `rofi` + `flatpak` + `dnf` | `config/rofi/scripts/tienda.py` |
| Notificaciones | `mako` | `config/mako/` |
| Terminal | `kitty` | `config/kitty/` |
| Bloqueo | `swaylock` + `swayidle` | `config/swaylock/` |
| Fondo | `swaybg` | `config/niri/scripts/wallpaper.sh` |
| Apps X11 | `xwayland-satellite` | automático |
| Inicio de sesión | `greetd` + `gtkgreet` (dentro de un niri mínimo) | `system/greetd/` |
| Archivos | `nautilus` | — |
| Navegador | `brave-browser` | — |
| Visor de PDF | `okular` | `config/kdeglobals` (sus colores oscuros) |
| Tema de las apps | `adw-gtk3-dark` (GTK3) · modo oscuro (GTK4) | `install.sh` → `ajustes_gtk` |

Tema: **blanco sobre oscuro translúcido**, con barra en islas, menús que salen bajo la barra (y se cierran con un clic fuera) y fondos anime. El color se reserva para los avisos. Fuente: **JetBrainsMono Nerd Font**.

## Instalación

Hay dos caminos. Lo ideal es el primero: un sistema limpio con solo lo necesario.

### A · Desde una Fedora mínima (recomendado)

1. Descarga **Fedora Everything** (la imagen *netinstall*) desde <https://fedoraproject.org/misc/#everything>.
2. En el instalador, en **Selección de software**, elige **Instalación mínima** (*Minimal Install*) y nada más.
3. Crea tu usuario y marca **Hacer administrador a este usuario**.
4. Al reiniciar entrarás en una consola de texto. Inicia sesión y ejecuta:

```bash
sudo dnf install -y git
git clone https://github.com/newg999/yoru.git ~/dotfiles
cd ~/dotfiles
./install.sh
sudo reboot
```

Al volver verás la pantalla de inicio de Yoru (tu fondo, el reloj y un recuadro como los menús): escribe tu usuario y contraseña y entrarás en Niri. `Ctrl+Alt+Supr` reinicia y `Ctrl+Alt+Fin` apaga sin entrar.

### B · Sobre una Fedora con GNOME

Los mismos comandos (sin el `reboot`). Después cierra la sesión y en la pantalla de inicio pulsa el engranaje ⚙ (abajo a la derecha), elige **Niri** y entra. **GNOME no se toca**: el instalador respeta su pantalla de inicio (GDM) y puedes volver a él desde el mismo menú.

| Comando | Qué hace |
|---|---|
| `./install.sh` | Instalación completa |
| `./install.sh --sin-paquetes` | Solo la fuente y los enlaces, sin usar `dnf` |
| `./install.sh --deshacer` | Quita los enlaces y restaura tu configuración anterior |

### Si tienes una gráfica NVIDIA

El instalador la detecta solo y te ofrece su driver oficial (desde RPM Fusion). Si tu equipo tiene **Secure Boot** activado, te pedirá inventar una **contraseña de un solo uso** (mejor solo números: en ese momento el teclado es inglés). Al reiniciar saldrá una **pantalla azul** (MOK Manager):

1. Pulsa una tecla antes de 10 segundos.
2. **Enroll MOK** → **Continue** → **Yes**.
3. Escribe esa contraseña y elige **Reboot**.

Si se te pasa, el driver no cargará: repite con `sudo mokutil --import /etc/pki/akmods/certs/public_key.der` y reinicia. Para comprobar que va: `nvidia-smi`.

### Cómo funciona

El script **no copia** archivos: crea *enlaces simbólicos*. `~/.config/niri` apunta a `~/dotfiles/config/niri`, así que cualquier cambio que hagas se guarda en el repositorio y lo ves con `git status`. Si ya tenías configuración, se mueve primero a `~/.local/state/yoru/backups/`.

## Atajos principales

`Mod` = tecla Super (Windows). **`Mod+F1` (o `Mod+Shift+/`) muestra todos los atajos en pantalla.**

| Atajo | Acción |
|---|---|
| `Mod+Return` / `Mod+T` | Terminal |
| `Mod+Space` / `Mod+D` | Lanzador de apps |
| `Mod+E` | Archivos |
| `Mod+B` | Navegador (Brave) |
| `Mod+Q` | Cerrar ventana |
| `Mod+O` | Overview (vista de todo) |
| `Mod+←/→` o `Mod+H/L` | Moverse entre columnas |
| `Mod+↑/↓` o `Mod+K/J` | Moverse entre ventanas y escritorios |
| `Mod+Ctrl+flechas` | Mover la ventana |
| `Mod+1…9` | Ir al escritorio N |
| `Mod+Shift+1…9` | Mover la ventana al escritorio N |
| `Mod+R` | Cambiar ancho (1/3, 1/2, 2/3) |
| `Mod+F` / `Mod+Shift+F` | Maximizar / pantalla completa |
| `Mod+V` | Ventana flotante |
| `Mod+W` | Columna en pestañas |
| `Mod+Alt+O` | Quitar/poner transparencia a la ventana |
| `Mod+,` / `Mod+.` | Meter la ventana de la derecha en la columna / sacarla |
| `Mod+-` / `Mod++` | Estrechar / ensanchar la columna |
| `Print` | Captura rápida (Niri) |
| `Mod+Shift+S` | Captura con editor (swappy) |
| `Mod+Alt+N` | Menú de wifi |
| `Mod+Alt+B` | Menú de bluetooth |
| `Mod+Alt+A` | Menú de audio (salida, micrófono, volumen) |
| `Mod+Alt+C` | Calendario |
| `Mod+Alt+V` | Historial del portapapeles |
| `Mod+Alt+S` | Tienda de apps (buscar, instalar, actualizar) |
| `Mod+Alt+W` | Elegir fondo de pantalla (con miniaturas) |
| `Mod+Alt+Shift+W` | Siguiente fondo de pantalla |
| `Mod+BackSpace` | Bloquear |
| `Mod+Shift+BackSpace` | Menú de apagado |
| `Mod+Alt+P` / `Mod+Alt+Shift+P` | Encender / apagar la pantalla del portátil |
| `Mod+Shift+E` | Salir de Niri |

## Dónde tocar cada cosa

| Quiero cambiar… | Archivo |
|---|---|
| Colores de bordes y sombras | `config/niri/colors.kdl` |
| Atajos | `config/niri/binds.kdl` |
| Separación entre ventanas, anchos | `config/niri/config.kdl` → `layout` |
| Qué arranca al iniciar | `config/niri/config.kdl` → `spawn-at-startup` |
| Esquinas, ventanas flotantes | `config/niri/rules.kdl` |
| Monitores y escala | `config/niri/local.kdl` (copia `local.kdl.example`) |
| Pantalla de inicio de sesión | `system/greetd/config.toml` (se copia a `/etc`, vuelve a ejecutar `./install.sh`) |
| Paquetes que se instalan | `packages.txt` |
| Módulos de la barra | `config/waybar/modulos.jsonc` (y `config.jsonc` para lo que cambia en cada pantalla) |
| Aspecto de la barra | `config/waybar/style.css` |
| Fondos de pantalla | Echa imágenes en `wallpapers/`, o añade uno de wallhaven.cc a `wallpapers/wallhaven.txt` y ejecuta `wallpapers/descargar.sh` |

Niri recarga su configuración **al guardar**. Para el resto:

```bash
niri validate            # comprobar la config de Niri
systemctl --user restart waybar   # reiniciar la barra
makoctl reload           # recargar notificaciones
niri msg windows         # ver el app-id de las ventanas abiertas (para reglas)
niri msg outputs         # ver tus monitores
```

## Problemas frecuentes

- **Los iconos de la barra salen como cuadrados:** falta la Nerd Font. Vuelve a ejecutar `./install.sh --sin-paquetes`.
- **Una app no pide la contraseña de administrador:** comprueba que `mate-polkit` está instalado.
- **No puedo compartir pantalla en Meet/Discord:** entra a Niri desde la pantalla de inicio, no desde una terminal, para que los portales arranquen.
- **Las capturas no aparecen:** se guardan en `~/Pictures/Screenshots` (cámbialo en `screenshot-path`). También quedan en el portapapeles.
- **Algo se rompió:** `./install.sh --deshacer` y vuelves a GNOME como estaba.

## Créditos

- Inspirado en [SygurDot](https://github.com/sygurd24/SygurDot).
- Configuración base a partir de la config por defecto de [Niri](https://github.com/niri-wm/niri).
- Colores de la terminal: [Nord](https://www.nordtheme.com).
