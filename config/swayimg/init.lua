-- ===========================================================================
--  swayimg — el visor de imágenes de Yoru
--  install.sh enlaza config/swayimg en ~/.config/swayimg
--  Todas las opciones: /usr/share/doc/swayimg/CONFIG.md
--
--  Teclas: ← → (o rueda) = anterior / siguiente · + - = zoom · 0 = tamaño
--  real · Enter = galería (miniaturas) y vuelta · f = pantalla completa ·
--  r = girar · i = mostrar u ocultar los datos · q / Esc = salir
-- ===========================================================================

-- Sin barra de título ni bordes: solo la imagen (en niri no hacen falta)
swayimg.decoration = false

-- La letra de Yoru; los datos se ven unos segundos al cambiar de imagen
swayimg.text.font = "JetBrainsMono Nerd Font"
swayimg.text.size = 18
swayimg.text.padding = 16
swayimg.text.timeout = 3
swayimg.text.status_timeout = 2
swayimg.text.shadow = 0x00000000

-- Arriba, nombre y medidas; abajo, en qué imagen vas y el zoom
swayimg.viewer.text = {
  topleft = { "{name}", "{frame.width}×{frame.height} · {sizehr}" },
  topright = {},
  bottomleft = { "{list.index} de {list.total} · {scale}" },
  bottomright = {},
}

-- Al abrir una imagen, también las demás de su carpeta (← → para pasar)
swayimg.imagelist.adjacent = true

-- Tamaño: la imagen entera si no cabe; si cabe, a su tamaño real
swayimg.viewer.default_scale = "optimal"

-- Galería: miniaturas grandes, con un borde en la elegida
swayimg.gallery.thumb_size = 220
swayimg.gallery.padding_size = 10
swayimg.gallery.border_size = 2
swayimg.gallery.selected_scale = 1.05

-- Colores del tema (los escribe «yoru tema»: tema/aplicar.py). Si aún no
-- existen, se quedan los de swayimg
pcall(dofile, os.getenv("HOME") .. "/.local/state/yoru/tema/swayimg.lua")

-- Una sola ventana: «yoru abrir» (bin/yoru) escribe la ruta en este archivo
-- y avisa con la señal USR1; aquí se abre esa imagen (con las demás de su
-- carpeta) en vez de abrir otro visor
local pedido = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/yoru-swayimg-abrir"
local function abrir_pedido()
  local f = io.open(pedido)
  if not f then return end
  local ruta = f:read("*l")
  f:close()
  os.remove(pedido)
  if not ruta or ruta == "" then return end
  swayimg.imagelist.clear()
  swayimg.imagelist.add(ruta:match("^(.*)/[^/]*$") or ".")
  swayimg.mode = "viewer"
  swayimg.viewer.open_path(ruta)
end
swayimg.viewer.on_signal("USR1", abrir_pedido)
swayimg.slideshow.on_signal("USR1", abrir_pedido)
swayimg.gallery.on_signal("USR1", abrir_pedido)
