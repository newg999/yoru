#!/usr/bin/env python3
# ============================================================================
#  aplicar.py — genera los colores de Yoru y recarga lo que haga falta
# ----------------------------------------------------------------------------
#  Normalmente se usa a través de «yoru tema»:
#    aplicar.py           vuelve a aplicar el modo guardado (blanco si no hay)
#    aplicar.py blanco    la paleta de tema/blanco.json (monocromo)
#    aplicar.py fondo     colores sacados del fondo de pantalla (matugen)
#
#  Escribe en ~/.local/state/yoru/tema/ un archivo por programa. Las configs
#  del repo los incluyen y, si no existen, usan sus colores de siempre:
#    niri.kdl    ← config/niri/config.kdl      (include optional=true)
#    kitty.conf  ← config/kitty/kitty.conf     (include)
#    colores.json ← Quickshell (comun/Tema.qml)
#  Fuera del repo a propósito: cambiar de fondo no deja cambios en git.
#
#  En modo fondo, rojo y amarillo no cambian: son los avisos y tienen que
#  reconocerse siempre.
# ============================================================================

import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BLANCO = REPO / "tema" / "blanco.json"
ESTADO = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "yoru" / "tema"
FONDO_ACTUAL = Path.home() / ".cache" / "wallpaper-actual"

# Colores de matugen (Material You) → nombres de Yoru
DESDE_MATUGEN = {
    "fondo": "surface",
    "fondo2": "surface_container_high",
    "velo": "surface_container_lowest",
    "texto": "on_surface",
    "gris": "outline",
    "gris2": "outline_variant",
    "acento": "primary",
}


def alfa(color, opacidad):
    """#rrggbb + opacidad (0-1) → #rrggbbaa"""
    return f"{color}{round(opacidad * 255):02x}"


def paleta_blanco():
    p = json.loads(BLANCO.read_text())
    return {k: v for k, v in p.items() if not k.startswith("_")}


def paleta_fondo():
    fondo = Path(FONDO_ACTUAL.read_text().strip()) if FONDO_ACTUAL.exists() else None
    if not fondo or not fondo.is_file():
        sys.exit("No encuentro el fondo actual (~/.cache/wallpaper-actual). Elige uno con Mod+Alt+W")
    salida = subprocess.run(
        ["matugen", "image", str(fondo), "--dry-run", "--json", "hex", "-q",
         "--mode", "dark", "--prefer", "saturation"],
        capture_output=True, text=True, check=True).stdout
    colores = json.loads(salida)["colors"]
    p = paleta_blanco()
    for nuestro, suyo in DESDE_MATUGEN.items():
        p[nuestro] = colores[suyo]["dark"]["color"]
    return p


def escribir(nombre, texto):
    destino = ESTADO / nombre
    temporal = destino.with_suffix(destino.suffix + ".tmp")
    temporal.write_text(texto)
    temporal.replace(destino)   # de golpe: nadie lee un archivo a medias


def generar(p, modo):
    a = p["acento"]
    escribir("colores.json", json.dumps({**p, "modo": modo}, indent=4) + "\n")

    escribir("niri.kdl", f"""// Generado por tema/aplicar.py ({modo}). No lo edites: se sobrescribe.
layout {{
    focus-ring {{
        active-color "{alfa(a, 0.8)}"
        inactive-color "{alfa(a, 0.15)}"
    }}
    border {{
        active-color "{alfa(a, 0.8)}"
        inactive-color "{alfa(a, 0.15)}"
        urgent-color "{p['rojo']}"
    }}
}}
overview {{
    backdrop-color "{p['velo']}"
}}
""")

    escribir("kitty.conf", f"""# Generado por tema/aplicar.py ({modo}). No lo edites: se sobrescribe.
foreground              {p['texto']}
background              {p['fondo']}
selection_foreground    {p['fondo']}
selection_background    {p['texto']}
cursor                  {a}
cursor_text_color       {p['fondo']}
url_color               {a}
active_tab_foreground   {p['fondo']}
active_tab_background   {p['texto']}
inactive_tab_foreground {p['gris']}
inactive_tab_background {p['fondo2']}
tab_bar_background      {p['fondo']}
""")


def recargar(primera_vez):
    """Niri y Quickshell vigilan sus archivos solos. El resto, con un aviso."""
    def callado(*cmd):
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # La barra solo vigila colores.json si ya existía al arrancar
    if primera_vez:
        callado("systemctl", "--user", "try-restart", "yoru-shell.service")
    callado("pkill", "-USR1", "-x", "kitty")   # kitty relee su config
    # Por si niri aún no vigilaba niri.kdl (la primera vez que se crea)
    callado("niri", "msg", "action", "load-config-file")


def main():
    ESTADO.mkdir(parents=True, exist_ok=True)
    archivo_modo = ESTADO / "modo"
    if len(sys.argv) > 1:
        modo = sys.argv[1]
    elif archivo_modo.exists():
        modo = archivo_modo.read_text().strip()
    else:
        modo = "blanco"

    if modo == "blanco":
        p = paleta_blanco()
    elif modo == "fondo":
        try:
            p = paleta_fondo()
        except FileNotFoundError:
            sys.exit("Falta matugen: sudo dnf install matugen  (o ./install.sh)")
        except subprocess.CalledProcessError as e:
            sys.exit(f"matugen falló: {e.stderr.strip()}")
    else:
        sys.exit(f"Modo desconocido: {modo}  (usa blanco o fondo)")

    primera_vez = not (ESTADO / "colores.json").exists()
    generar(p, modo)
    archivo_modo.write_text(modo + "\n")
    recargar(primera_vez)
    print(f"Tema {modo}: acento {p['acento']}, fondo {p['fondo']}")


if __name__ == "__main__":
    main()
