#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  atajos.py — Los atajos de niri/binds.kdl, en JSON, para Ajustes › Atajos
#
#    [{"grupo": "Apps", "atajos": [{"teclas": [["Super", "Enter"], ...], "que": "Terminal"}]}]
#
#  Los grupos son los títulos «// ---- Nombre» de binds.kdl. Lo que hace cada
#  atajo: su hotkey-overlay-title o, si no tiene, la traducción de la acción
#  de niri (ACCIONES). Los que hacen lo mismo van en una sola fila (Super+←
#  y Super+H), y los de los escritorios 1-9, en «Super+1…9».
# ----------------------------------------------------------------------------

import json
import os
import re

BINDS = os.path.expanduser("~/.config/niri/binds.kdl")

ACCIONES = {
    "show-hotkey-overlay": "Chuleta de atajos de niri",
    "quit": "Cerrar la sesión",
    "power-off-monitors": "Apagar las pantallas",
    "screenshot": "Captura de una zona",
    "screenshot-screen": "Captura de la pantalla",
    "screenshot-window": "Captura de la ventana",
    "close-window": "Cerrar la ventana",
    "toggle-overview": "Overview (todas las ventanas)",
    "focus-column-left": "Ir a la ventana de la izquierda",
    "focus-column-right": "Ir a la ventana de la derecha",
    "focus-window-or-workspace-up": "Ir a la ventana o escritorio de arriba",
    "focus-window-or-workspace-down": "Ir a la ventana o escritorio de abajo",
    "move-column-left": "Mover la ventana a la izquierda",
    "move-column-right": "Mover la ventana a la derecha",
    "move-window-up-or-to-workspace-up": "Mover la ventana arriba (o al escritorio de arriba)",
    "move-window-down-or-to-workspace-down": "Mover la ventana abajo (o al escritorio de abajo)",
    "focus-column-first": "Ir a la primera ventana",
    "focus-column-last": "Ir a la última ventana",
    "move-column-to-first": "Mover la ventana al principio",
    "move-column-to-last": "Mover la ventana al final",
    "consume-or-expel-window-left": "Meter o sacar la ventana de la columna (izquierda)",
    "consume-or-expel-window-right": "Meter o sacar la ventana de la columna (derecha)",
    "consume-window-into-column": "Meter la ventana en la columna",
    "expel-window-from-column": "Sacar la ventana de la columna",
    "switch-preset-column-width": "Cambiar el ancho (1/3, 1/2, 2/3)",
    "switch-preset-column-width-back": "Cambiar el ancho (al revés)",
    "maximize-column": "Ancho completo",
    "fullscreen-window": "Pantalla completa",
    "maximize-window-to-edges": "Maximizar hasta los bordes",
    "expand-column-to-available-width": "Ocupar el hueco libre",
    "center-column": "Centrar la ventana",
    "set-column-width -10%": "Más estrecha",
    "set-column-width +10%": "Más ancha",
    "set-window-height -10%": "Más baja",
    "set-window-height +10%": "Más alta",
    "switch-focus-between-floating-and-tiling": "Pasar entre flotantes y columnas",
    "toggle-column-tabbed-display": "Columna en pestañas",
    "toggle-window-rule-opacity": "Quitar o poner la transparencia de la ventana",
    "focus-workspace N": "Ir al escritorio",
    "move-column-to-workspace N": "Mover la ventana al escritorio",
    "focus-workspace-previous": "Volver al escritorio anterior",
    "focus-workspace-down": "Escritorio de abajo",
    "focus-workspace-up": "Escritorio de arriba",
    "move-workspace-down": "Bajar el escritorio",
    "move-workspace-up": "Subir el escritorio",
    "focus-monitor-left": "Ir a la pantalla de la izquierda",
    "focus-monitor-right": "Ir a la pantalla de la derecha",
    "move-column-to-monitor-left": "Mover la ventana a la pantalla de la izquierda",
    "move-column-to-monitor-right": "Mover la ventana a la pantalla de la derecha",
    "toggle-keyboard-shortcuts-inhibit": "Recuperar los atajos si una app se los queda",
    "spawn kitty": "Terminal",
    "spawn playerctl play-pause": "Reproducir / pausar",
    "spawn playerctl next": "Canción siguiente",
    "spawn playerctl previous": "Canción anterior",
    "spawn qs -c yoru ipc call brillo subir": "Subir el brillo",
    "spawn qs -c yoru ipc call brillo bajar": "Bajar el brillo",
}

# Por partes del comando, para los spawn sin título
ORDENES = [
    ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+", "Subir el volumen"),
    ("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "Bajar el volumen"),
    ("wpctl set-mute @DEFAULT_AUDIO_SINK@", "Silenciar"),
    ("wpctl set-mute @DEFAULT_AUDIO_SOURCE@", "Silenciar el micrófono"),
    ("bloquear.sh", "Bloquear la pantalla"),
    ("output eDP-1 on", "Encender la pantalla del portátil"),
    ("output eDP-1 off", "Apagar la pantalla del portátil"),
]

TECLAS = {
    "Mod": "Super", "Super": "Super", "Shift": "Mayús", "Ctrl": "Ctrl", "Control": "Ctrl", "Alt": "Alt",
    "Return": "Enter", "Space": "Espacio", "BackSpace": "Retroceso", "Delete": "Supr",
    "Escape": "Esc", "Tab": "Tab", "Print": "Impr Pant", "Home": "Inicio", "End": "Fin",
    "Page_Up": "Re Pág", "Page_Down": "Av Pág",
    "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
    "Slash": "/", "Comma": ",", "Period": ".", "Plus": "+", "Minus": "-", "Equal": "=",
    "BracketLeft": "[", "BracketRight": "]", "masculine": "º",
    "WheelScrollDown": "Rueda ↓", "WheelScrollUp": "Rueda ↑",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Silencio",
    "XF86AudioMicMute": "Micro", "XF86AudioPlay": "▶", "XF86AudioPause": "⏸",
    "XF86AudioNext": "⏭", "XF86AudioPrev": "⏮",
    "XF86MonBrightnessUp": "Brillo +", "XF86MonBrightnessDown": "Brillo −",
}

LINEA = re.compile(r'^\s*([\w+]+)((?:\s+[\w-]+=(?:"[^"]*"|\S+))*)\s*\{\s*(.*?);?\s*\}\s*$')


def tecla(combo):
    """Super+Alt+T → ["Super", "Alt", "T"] (cada tecla, una caja en Ajustes)"""
    return [TECLAS.get(t, t.upper() if len(t) == 1 else t) for t in combo.split("+")]


def que_hace(accion, titulo):
    if titulo:
        return titulo
    partes = re.findall(r'"([^"]*)"|(\S+)', accion)
    plano = " ".join(a or b for a, b in partes)
    if plano in ACCIONES:
        return ACCIONES[plano]
    for trozo, texto in ORDENES:
        if trozo in plano:
            return texto
    return plano


def leer():
    grupos, grupo = [], None
    try:
        lineas = open(BINDS).read().splitlines()
    except FileNotFoundError:
        return []
    for linea in lineas:
        cabecera = re.match(r"^\s*//\s*-{4,}\s*([^-\s].*?)\s*$", linea)
        if cabecera:
            grupo = {"grupo": cabecera.group(1), "atajos": []}
            grupos.append(grupo)
            continue
        m = LINEA.match(linea)
        if not m or linea.strip().startswith("//"):
            continue
        combo, props, accion = m.groups()
        titulo = re.search(r'hotkey-overlay-title=(?:"([^"]*)"|(null))', props)
        titulo = titulo.group(1) if titulo else None
        # Los escritorios 1-9: una fila con «1…9»
        numero = re.match(r"^(.*\+)(\d)$", combo)
        clave = accion
        if numero and re.search(r"\b%s$" % numero.group(2), accion):
            combo = numero.group(1) + "1…9"
            clave = re.sub(r"\d+$", "N", accion)
        if grupo is None:
            grupo = {"grupo": "General", "atajos": []}
            grupos.append(grupo)
        mismo = next((a for a in grupo["atajos"] if a["clave"] == clave), None)
        texto = tecla(combo)
        if mismo:
            if texto not in mismo["teclas"]:
                mismo["teclas"].append(texto)
            if titulo and not mismo["titulado"]:
                mismo["que"], mismo["titulado"] = titulo, True
        else:
            grupo["atajos"].append({"clave": clave, "teclas": [texto], "titulado": bool(titulo),
                                    "que": que_hace(clave, titulo)})
    for g in grupos:
        for a in g["atajos"]:
            del a["clave"], a["titulado"]
    return [g for g in grupos if g["atajos"]]


if __name__ == "__main__":
    print(json.dumps(leer(), ensure_ascii=False))
