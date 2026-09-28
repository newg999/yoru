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
- [x] Buscar fondos de pantalla que encajen y echarlos en `wallpapers/` (naturaleza y paisajes anime, con `wallpapers/descargar.sh`)
- [x] Ajustar `gaps`, anchura del `focus-ring`, sombras y radio de esquinas (huecos 12, anillo 2, esquinas 10, sombra suave)
- [x] **Desenfoque** (blur) detrás de cada isla de la barra y de los paneles (Quickshell pide la zona exacta a niri)
- [x] **Animaciones** un 20 % más rápidas (`slowdown 0.8` en `config.kdl`) → [docs](https://niri-wm.github.io/niri/Configuration:-Animations.html)
- [x] Tema oscuro para apps GTK: `gsettings set org.gnome.desktop.interface color-scheme prefer-dark`
- [x] Tema de iconos y cursor: Papirus-Dark y Bibata Modern Ice

## Fase 3 · Centralizar los colores
Ahora mismo, si cambias de tema tienes que editar 6 archivos. Soluciones, de más fácil a más potente:
- [x] Una sola paleta (`tema/blanco.json`) que se aplica a todo con `yoru tema`
- [x] Usar **[matugen](https://github.com/InioX/matugen)** o **[wallust](https://codeberg.org/explosion-mental/wallust)**: generan la paleta a partir del fondo de pantalla (como Material You)

## Fase 4 · Una barra a tu medida
- [ ] Decidir qué módulos quieres realmente y en qué orden
- [ ] Crear tu primer módulo `custom/` con un script (por ejemplo, la temperatura o la canción que suena con `playerctl`)
- [x] Menús con rofi: wifi, bluetooth, calendario, apagado y portapapeles (ya todos en Quickshell; rofi quitado)
- [x] Menú de audio: salida, micrófono y volumen
- [x] Perfiles de energía y brillo en el centro de control (el brillo también para monitores externos, por DDC/CI)
- [x] Pasar la barra de Waybar a **[Quickshell](https://quickshell.org)**: misma estética, con paneles de verdad
- [x] Centro de control (Quickshell): wifi, bluetooth, volumen, micrófono y salidas de audio
- [x] Panel central (Quickshell): reloj, calendario, clima de tu zona, música con carátula y uso del sistema
- [x] Lanzador de apps a la izquierda (Quickshell), con las más usadas primero
- [x] Visualizador de audio (cava) junto a la canción
- [x] Pestaña Multimedia: carátula grande, progreso, aleatorio/repetir, elegir reproductor, salida y volumen
- [x] Bandeja (Telegram, Discord...) junto a CPU y RAM, como en DMS
- [x] Monitor del sistema (clic en CPU/RAM): procesos agrupados por app, buscar, ordenar, cerrar; gráficas de CPU, memoria y red
- [x] Mod+Tab abre el overview y la barra se esconde mientras (como en DMS)
- [x] Llevar a Quickshell el resto de menús de rofi: apagado, portapapeles, fondos, calendario y tienda
- [x] Tooltips en la barra: fecha completa, red y audio, CPU y memoria, clima, canción y título entero
- [x] Quitar `config/waybar/` cuando ya no haga falta

## Fase 5 · Terminal y shell
- [x] Cambiar a **zsh** (con Oh My Zsh)
- [ ] Prompt con **[Starship](https://starship.rs)**
- [x] Autosugerencias y resaltado de sintaxis
- [x] `fastfetch` con tu logo al abrir la terminal (el clásico para las capturas)
- [ ] Herramientas modernas: `eza`, `bat`, `fzf`, `zoxide`, `btop`

## Fase 6 · Pulir los detalles
- [ ] Pantalla de bloqueo más bonita: **hyprlock** o **swaylock-effects** (fondo desenfocado y reloj)
- [ ] OSD de volumen y brillo (una barra que aparece al pulsar las teclas): **[SwayOSD](https://github.com/ErikReider/SwayOSD)**
- [ ] Reglas de ventanas: qué app se abre en qué escritorio (`niri msg windows` para ver el `app-id`)
- [ ] Escritorios con nombre (`workspace "web"`, `workspace "código"`...) → [docs](https://niri-wm.github.io/niri/Configuration:-Named-Workspaces.html)
- [ ] Visualizador de audio con **cava** en la barra o en una terminal flotante
- [x] Pantalla de inicio de sesión: **greetd** + **gtkgreet** dentro de un niri mínimo, con el estilo de Yoru

## Fase 7 · Compartirlo
- [ ] README con capturas de cada parte (como hace SygurDot)
- [ ] Versión en inglés del README
- [ ] Probar la instalación desde cero en una máquina virtual limpia
- [ ] Publicarlo en r/unixporn o donde quieras 🎉

---

### Recursos útiles
- Documentación de Niri: <https://niri-wm.github.io/niri/>
- Configs de otros usuarios: busca `niri dotfiles` en GitHub
- Documentación de Quickshell: <https://quickshell.org/docs/>
- Iconos Nerd Font: <https://www.nerdfonts.com/cheat-sheet>
- Inspiración: <https://www.reddit.com/r/unixporn/>
