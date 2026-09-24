# Mis dotfiles · Fedora + Niri

> Cambia el nombre, el título y esta frase: es tu proyecto.

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
| Capturas con editor | `flameshot` | — |
| Notificaciones | `mako` | `config/mako/` |
| Terminal | `kitty` | `config/kitty/` |
| Bloqueo | `swaylock` + `swayidle` | `config/swaylock/` |
| Fondo | `swaybg` | `config/niri/scripts/wallpaper.sh` |
| Apps X11 | `xwayland-satellite` | automático |

Tema: **[Nord](https://www.nordtheme.com)**, con barra en islas y desenfoque. Fuente: **JetBrainsMono Nerd Font**.

## Instalación

```bash
git clone https://github.com/TU_USUARIO/mis-dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Después cierra la sesión y en la pantalla de inicio pulsa el engranaje ⚙ (abajo a la derecha), elige **Niri** y entra. **GNOME no se toca**: puedes volver a él desde el mismo menú.

| Comando | Qué hace |
|---|---|
| `./install.sh` | Instalación completa |
| `./install.sh --sin-paquetes` | Solo la fuente y los enlaces, sin usar `dnf` |
| `./install.sh --deshacer` | Quita los enlaces y restaura tu configuración anterior |

### Cómo funciona

El script **no copia** archivos: crea *enlaces simbólicos*. `~/.config/niri` apunta a `~/dotfiles/config/niri`, así que cualquier cambio que hagas se guarda en el repositorio y lo ves con `git status`. Si ya tenías configuración, se mueve primero a `~/.local/state/mis-dotfiles/backups/`.

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
| `Mod+Shift+S` | Captura con editor (Flameshot) |
| `Mod+Alt+N` | Menú de wifi |
| `Mod+Alt+B` | Menú de bluetooth |
| `Mod+Alt+C` | Calendario |
| `Mod+Alt+V` | Historial del portapapeles |
| `Mod+Alt+W` | Siguiente fondo de pantalla |
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
| Módulos de la barra | `config/waybar/config.jsonc` |
| Aspecto de la barra | `config/waybar/style.css` |
| Fondos de pantalla | Echa imágenes en `wallpapers/` |

Niri recarga su configuración **al guardar**. Para el resto:

```bash
niri validate            # comprobar la config de Niri
pkill -SIGUSR2 waybar    # recargar la barra
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
- Colores: [Nord](https://www.nordtheme.com).
