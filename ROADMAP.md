# Hoja de ruta de Yoru · de "funciona" a "mi escritorio perfecto"

La idea es avanzar **una fase cada vez** y hacer un commit en git al terminar cada tarea. Así, si algo se rompe, vuelves atrás con `git checkout`.

Marca las casillas conforme avances (`- [x]`).

---

## Fase 0 · Preparar el terreno
- [x] Crear el repositorio en GitHub y subir esta base → <https://github.com/newg999/yoru>
- [ ] *(Recomendado)* Probar la instalación desde una **Fedora mínima** en una máquina virtual (GNOME Boxes)
- [ ] Ejecutar `./install.sh` y entrar en Niri desde la pantalla de inicio
- [ ] Hacer la primera captura y ponerla en el README

## Fase 1 · Que todo funcione en tu equipo
- [x] Copiar `local.kdl.example` a `local.kdl` y ajustar monitores y escala (`niri msg outputs`)
- [ ] Revisar touchpad y ratón en `config.kdl` → `input` (velocidad, scroll natural...)
- [ ] Comprobar volumen, brillo, wifi, bluetooth y batería en la barra (batería ya añadida)
- [ ] Comprobar que compartir pantalla funciona (Meet, Discord...)
- [ ] Probar el bloqueo (`Mod+BackSpace`) y la suspensión
- [ ] Anotar en un `TROUBLESHOOTING.md` cada problema que encuentres y cómo lo arreglaste

## Fase 2 · Tu identidad visual
- [x] Elegir **tu** paleta: tema "blanco" (monocromo translúcido)
- [ ] Buscar fondos de pantalla que encajen y echarlos en `wallpapers/`
- [ ] Ajustar `gaps`, anchura del `focus-ring`, sombras y radio de esquinas
- [ ] Probar **desenfoque** (blur) en la barra con un `layer-rule` y `background-effect` → [docs](https://niri-wm.github.io/niri/Configuration:-Layer-Rules.html)
- [ ] Probar las **animaciones** y encontrar la velocidad que te guste → [docs](https://niri-wm.github.io/niri/Configuration:-Animations.html)
- [x] Tema oscuro para apps GTK: `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`
- [ ] Tema de iconos y cursor (por ejemplo, Papirus y Bibata)

## Fase 3 · Centralizar los colores
Ahora mismo, si cambias de tema tienes que editar 6 archivos. Soluciones, de más fácil a más potente:
- [ ] Un script `scripts/tema.sh` que sustituya los colores con `sed` en todos los archivos
- [ ] Usar **[matugen](https://github.com/InioX/matugen)** o **[wallust](https://codeberg.org/explosion-mental/wallust)**: generan la paleta a partir del fondo de pantalla (como Material You)

## Fase 4 · Una barra a tu medida
- [ ] Decidir qué módulos quieres realmente y en qué orden
- [ ] Crear tu primer módulo `custom/` con un script (por ejemplo, la temperatura o la canción que suena con `playerctl`)
- [x] Menús con rofi: wifi, bluetooth, calendario, apagado y portapapeles
- [x] Menú de audio: salida, micrófono y volumen
- [ ] Más menús: perfiles de energía, brillo
- [ ] *(Avanzado)* Probar alternativas a Waybar: **[Quickshell](https://quickshell.org)**, **[Ironbar](https://github.com/JakeStanger/ironbar)** o **[eww](https://github.com/elkowar/eww)**

## Fase 5 · Terminal y shell
- [ ] Cambiar a **zsh** o **fish**
- [ ] Prompt con **[Starship](https://starship.rs)**
- [ ] Autosugerencias y resaltado de sintaxis
- [ ] `fastfetch` con tu logo al abrir la terminal (el clásico para las capturas)
- [ ] Herramientas modernas: `eza`, `bat`, `fzf`, `zoxide`, `btop`

## Fase 6 · Pulir los detalles
- [ ] Pantalla de bloqueo más bonita: **hyprlock** o **swaylock-effects** (fondo desenfocado y reloj)
- [ ] OSD de volumen y brillo (una barra que aparece al pulsar las teclas): **[SwayOSD](https://github.com/ErikReider/SwayOSD)**
- [ ] Reglas de ventanas: qué app se abre en qué escritorio (`niri msg windows` para ver el `app-id`)
- [ ] Escritorios con nombre (`workspace "web"`, `workspace "código"`...) → [docs](https://niri-wm.github.io/niri/Configuration:-Named-Workspaces.html)
- [ ] Visualizador de audio con **cava** en la barra o en una terminal flotante
- [x] Pantalla de inicio de sesión: **greetd** + **tuigreet** (en instalaciones mínimas)

## Fase 7 · Compartirlo
- [ ] README con capturas de cada parte (como hace SygurDot)
- [ ] Versión en inglés del README
- [ ] Probar la instalación desde cero en una máquina virtual limpia
- [ ] Publicarlo en r/unixporn o donde quieras 🎉

---

### Recursos útiles
- Documentación de Niri: <https://niri-wm.github.io/niri/>
- Configs de otros usuarios: busca `niri dotfiles` en GitHub
- Wiki de Waybar: <https://github.com/Alexays/Waybar/wiki>
- Iconos Nerd Font: <https://www.nerdfonts.com/cheat-sheet>
- Inspiración: <https://www.reddit.com/r/unixporn/>
