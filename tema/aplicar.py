#!/usr/bin/env python3
# ============================================================================
#  aplicar.py — genera los colores de Yoru y recarga lo que haga falta
# ----------------------------------------------------------------------------
#  Normalmente se usa a través de «yoru tema»:
#    aplicar.py              vuelve a aplicar el modo guardado (blanco si no hay)
#    aplicar.py blanco       la paleta de tema/blanco.json (monocromo)
#    aplicar.py fondo        colores sacados del fondo de pantalla (matugen)
#    aplicar.py fondo-claro  lo mismo, en claro
#    aplicar.py <paleta>     una de tema/paletas/ (nord, catppuccin...)
#    aplicar.py --lista      los temas que hay, en JSON (para el panel de Ajustes)
#    aplicar.py --kde        solo ~/.config/kdeglobals: las claves de
#                            config/kdeglobals (iconos...) y los colores del
#                            tema de ahora. Lo demás que tenga ese archivo (lo
#                            que cambies en Plasma) se queda. La barra lo
#                            ejecuta al arrancar en niri (yoru kdeglobals)
#
#  Escribe en ~/.local/state/yoru/tema/ un archivo por programa. Las configs
#  del repo los incluyen y, si no existen, usan sus colores de siempre:
#    niri.kdl    ← config/niri/config.kdl      (include optional=true)
#    kitty.conf  ← config/kitty/kitty.conf     (include)
#    colores.json ← Quickshell (comun/Tema.qml)
#    fastfetch.zsh ← config/zsh/zshrc (colores del logo de fastfetch)
#    Yoru.colors ← esquema de color de KDE (apps Qt y Plasma): se copia en
#                 ~/.local/share/color-schemes/ y sus colores, en
#                 ~/.config/kdeglobals (ver «aplicar.py --kde»)
#    mpv.conf    ← config/mpv/mpv.conf         (include: colores de uosc)
#    swayimg     ← config/swayimg/config       (include: colores del visor)
#  Fuera del repo a propósito: cambiar de fondo no deja cambios en git.
#
#  En modo fondo, rojo y amarillo no cambian: son los avisos y tienen que
#  reconocerse siempre.
# ============================================================================

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BLANCO = REPO / "tema" / "blanco.json"
PALETAS = REPO / "tema" / "paletas"
ESTADO = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "yoru" / "tema"
FONDO_ACTUAL = Path.home() / ".cache" / "wallpaper-actual"
KDEGLOBALS_BASE = REPO / "config" / "kdeglobals"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
ESQUEMAS = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "color-schemes"

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


def leer_paleta(archivo):
    """Una paleta de tema/paletas/ (sin las claves «_» de nombre y notas)"""
    p = json.loads(archivo.read_text())
    return {k: v for k, v in p.items() if not k.startswith("_")}


def lista():
    """Los temas que se pueden elegir, con sus colores (los del fondo no se
    saben hasta generarlos)"""
    temas = [
        {"id": "blanco", "nombre": "Yoru", "claro": False, "colores": paleta_blanco()},
        {"id": "fondo", "nombre": "Del fondo", "claro": False, "colores": None},
        {"id": "fondo-claro", "nombre": "Del fondo (claro)", "claro": True, "colores": None},
    ]
    for archivo in sorted(PALETAS.glob("*.json")):
        datos = json.loads(archivo.read_text())
        temas.append({"id": archivo.stem, "nombre": datos.get("_nombre", archivo.stem),
                      "claro": datos.get("_claro", False), "colores": leer_paleta(archivo)})
    print(json.dumps(temas))


def paleta_fondo(claro=False):
    fondo = Path(FONDO_ACTUAL.read_text().strip()) if FONDO_ACTUAL.exists() else None
    if not fondo or not fondo.is_file():
        sys.exit("No encuentro el fondo actual (~/.cache/wallpaper-actual). Elige uno con Mod+Alt+W")
    salida = subprocess.run(
        ["matugen", "image", str(fondo), "--dry-run", "--json", "hex", "-q",
         "--mode", "light" if claro else "dark", "--prefer", "saturation"],
        capture_output=True, text=True, check=True).stdout
    colores = json.loads(salida)["colors"]
    # Si mientras matugen trabajaba se ha puesto otro fondo (dos cambios
    # seguidos), este resultado ya no vale: lo escribiría encima del bueno si
    # terminara el último. La otra llamada, la del fondo nuevo, se encarga.
    if FONDO_ACTUAL.read_text().strip() != str(fondo):
        sys.exit(0)
    p = paleta_blanco()
    variante = "light" if claro else "dark"
    for nuestro, suyo in DESDE_MATUGEN.items():
        p[nuestro] = colores[suyo][variante]["color"]
    return p


def mezcla(c1, c2, t):
    """Del color c1 (t=0) al c2 (t=1)"""
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(a, b))


def rgb(color):
    """#rrggbb → «r,g,b», como lo quieren los archivos de KDE"""
    return ",".join(str(int(color[i:i + 2], 16)) for i in (1, 3, 5))


def luminancia(color):
    r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


# ------------------------------------------------------------------- KDE
# Un archivo de KDE (kdeglobals, .colors): [grupos] con clave=valor. Se lee
# y se escribe a mano, conservando el orden y las mayúsculas de las claves
def leer_ini(texto):
    grupos, actual = {}, None
    for linea in texto.splitlines():
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        if linea.startswith("["):
            actual = grupos.setdefault(linea, {})
        elif "=" in linea and actual is not None:
            clave, valor = linea.split("=", 1)
            actual[clave] = valor
    return grupos


def escribir_ini(grupos):
    return "\n".join(g + "\n" + "".join(f"{k}={v}\n" for k, v in claves.items())
                     for g, claves in grupos.items())


def esquema_kde(p):
    """El esquema de color «Yoru» con los mismos papeles que Breeze Dark:
    velo en las vistas (lo más oscuro), fondo en las ventanas, fondo2 en
    botones y cabeceras, y el acento en la selección y el foco"""
    a, texto, gris = p["acento"], p["texto"], p["gris"]
    # Sobre el acento, el texto que mejor se lea
    sobre_acento = p["fondo"] if luminancia(a) > luminancia(p["fondo"]) else p["texto"]
    if abs(luminancia(sobre_acento) - luminancia(a)) < 0.3:
        sobre_acento = p["velo"] if luminancia(a) > 0.5 else p["texto"]
    # No hay verde en la paleta: el de Nord, más o menos apagado según el tema
    verde = mezcla("#a3be8c", texto, 0.15)

    def grupo(fondo, alterno, primero=texto, inactivo=gris):
        return {
            "BackgroundAlternate": rgb(alterno),
            "BackgroundNormal": rgb(fondo),
            "DecorationFocus": rgb(a),
            "DecorationHover": rgb(mezcla(a, fondo, 0.4)),
            "ForegroundActive": rgb(a),
            "ForegroundInactive": rgb(inactivo),
            "ForegroundLink": rgb(a),
            "ForegroundNegative": rgb(p["rojo"]),
            "ForegroundNeutral": rgb(p["amarillo"]),
            "ForegroundNormal": rgb(primero),
            "ForegroundPositive": rgb(verde),
            "ForegroundVisited": rgb(mezcla(a, gris, 0.5)),
        }

    seleccion = grupo(a, mezcla(a, p["fondo"], 0.5), primero=sobre_acento,
                      inactivo=mezcla(sobre_acento, a, 0.4))
    seleccion["ForegroundActive"] = rgb(sobre_acento)
    seleccion["ForegroundLink"] = rgb(sobre_acento)
    return {
        "[ColorEffects:Disabled]": {
            "Color": "56,56,56", "ColorAmount": "0", "ColorEffect": "0",
            "ContrastAmount": "0.65", "ContrastEffect": "1",
            "IntensityAmount": "0.1", "IntensityEffect": "2",
        },
        "[ColorEffects:Inactive]": {
            "ChangeSelectionColor": "true", "Color": "112,111,110", "ColorAmount": "0.025",
            "ColorEffect": "2", "ContrastAmount": "0.1", "ContrastEffect": "2", "Enable": "false",
            "IntensityAmount": "0", "IntensityEffect": "0",
        },
        "[Colors:Button]": grupo(p["fondo2"], mezcla(p["fondo2"], a, 0.15)),
        "[Colors:Complementary]": grupo(p["velo"], p["fondo"]),
        "[Colors:Header]": grupo(p["fondo2"], p["fondo"]),
        "[Colors:Header][Inactive]": grupo(p["fondo"], p["fondo2"]),
        "[Colors:Selection]": seleccion,
        "[Colors:Tooltip]": grupo(p["fondo2"], p["fondo"]),
        "[Colors:View]": grupo(p["velo"], mezcla(p["velo"], p["fondo"], 0.5)),
        "[Colors:Window]": grupo(p["fondo"], p["fondo2"]),
        "[General]": {"ColorScheme": "Yoru", "Name": "Yoru", "shadeSortColumn": "true"},
        "[KDE]": {"contrast": "4"},
        "[WM]": {
            "activeBackground": rgb(p["fondo"]),
            "activeBlend": rgb(texto),
            "activeForeground": rgb(texto),
            "inactiveBackground": rgb(p["velo"]),
            "inactiveBlend": rgb(gris),
            "inactiveForeground": rgb(gris),
        },
    }


def aplicar_kde(p):
    """Escribe el esquema Yoru.colors y lo pone en ~/.config/kdeglobals junto
    con las claves de config/kdeglobals. Avisa a las apps de KDE abiertas"""
    esquema = esquema_kde(p)
    texto_esquema = escribir_ini(esquema)
    ESQUEMAS.mkdir(parents=True, exist_ok=True)
    (ESQUEMAS / "Yoru.colors").write_text(texto_esquema)

    destino = CONFIG / "kdeglobals"
    actual = {}
    if destino.is_symlink():      # de cuando era un enlace al repo
        destino.unlink()
    elif destino.exists():
        actual = leer_ini(destino.read_text())
    for nombre, claves in esquema.items():
        if nombre.startswith("[Colors:") or nombre.startswith("[ColorEffects:"):
            actual[nombre] = dict(claves)          # los colores, enteros
        else:
            actual.setdefault(nombre, {}).update(claves)
    for nombre, claves in leer_ini(KDEGLOBALS_BASE.read_text()).items():
        actual.setdefault(nombre, {}).update(claves)
    # Plasma compara esta huella con la del esquema: si no coincide, cree que
    # el esquema ha cambiado y vuelve a aplicar el suyo
    actual["[General]"]["ColorSchemeHash"] = hashlib.sha1(texto_esquema.encode()).hexdigest()
    temporal = destino.with_suffix(".tmp")
    temporal.write_text(escribir_ini(actual))
    temporal.replace(destino)
    # Las apps de KDE abiertas cambian de colores al momento (0 = la paleta)
    subprocess.run(["dbus-send", "--session", "--type=signal", "/KGlobalSettings",
                    "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def ansi(color):
    """#rrggbb → código de color de terminal (38;2;r;g;b), como lo pide fastfetch"""
    r, g, b = (int(color[i:i + 2], 16) for i in (1, 3, 5))
    return f"38;2;{r};{g};{b}"


def escribir(nombre, texto):
    destino = ESTADO / nombre
    temporal = destino.with_suffix(destino.suffix + ".tmp")
    temporal.write_text(texto)
    temporal.replace(destino)   # de golpe: nadie lee un archivo a medias


def generar(p, modo):
    a = p["acento"]
    escribir("colores.json", json.dumps({**p, "modo": modo}, indent=4) + "\n")
    aplicar_kde(p)

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

    escribir("fastfetch.zsh", f"""# Generado por tema/aplicar.py ({modo}). No lo edites: se sobrescribe.
# Colores del logo de fastfetch (los usa config/zsh/zshrc)
ff_colores=(
    --logo-color-1 '{ansi(a)}'
    --logo-color-2 '{ansi(p['gris'])}'
    --color-keys '{ansi(a)}'
)
""")

    # uosc (la interfaz de mpv): sus colores van sin «#»
    h = lambda c: c.lstrip("#")
    escribir("mpv.conf", f"""# Generado por tema/aplicar.py ({modo}). No lo edites: se sobrescribe.
script-opts-append=uosc-color=foreground={h(a)},foreground_text={h(p['fondo'])},background={h(p['fondo'])},background_text={h(p['texto'])},curtain={h(p['velo'])},success={h(a)},error={h(p['rojo'])}
background-color="{p['velo']}"
""")

    # swayimg (visor de imágenes): colores ARGB, 0xAARRGGBB
    argb = lambda c, alfa="ff": "0x" + alfa + c.lstrip("#")
    escribir("swayimg.lua", f"""-- Generado por tema/aplicar.py ({modo}). No lo edites: se sobrescribe.
swayimg.viewer.set_window_background({argb(p['velo'])})
swayimg.slideshow.set_window_background({argb(p['velo'])})
swayimg.viewer.mark_color = {argb(a)}
swayimg.gallery.window_color = {argb(p['velo'])}
swayimg.gallery.unselected_color = {argb(p['fondo2'])}
swayimg.gallery.selected_color = {argb(p['fondo2'])}
swayimg.gallery.border_color = {argb(a)}
swayimg.text.color = {argb(p['texto'])}
swayimg.text.background = {argb(p['fondo'], 'cc')}
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
    if sys.argv[1:] == ["--lista"]:
        lista()
        return
    if sys.argv[1:] == ["--kde"]:
        # Los colores del tema de ahora (o los de Yoru, si aún no hay)
        colores = ESTADO / "colores.json"
        try:
            p = json.loads(colores.read_text())
            p.pop("modo", None)
        except (OSError, ValueError):
            p = paleta_blanco()
        aplicar_kde(p)
        return
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
    elif modo in ("fondo", "fondo-claro"):
        try:
            p = paleta_fondo(claro=modo == "fondo-claro")
        except FileNotFoundError:
            sys.exit("Falta matugen: sudo dnf install matugen  (o ./install.sh)")
        except subprocess.CalledProcessError as e:
            sys.exit(f"matugen falló: {e.stderr.strip()}")
    elif (PALETAS / f"{modo}.json").is_file():
        p = leer_paleta(PALETAS / f"{modo}.json")
    else:
        otras = " · ".join(a.stem for a in sorted(PALETAS.glob("*.json")))
        sys.exit(f"Tema desconocido: {modo}  (usa blanco, fondo, fondo-claro o {otras})")

    primera_vez = not (ESTADO / "colores.json").exists()
    generar(p, modo)
    archivo_modo.write_text(modo + "\n")
    recargar(primera_vez)
    print(f"Tema {modo}: acento {p['acento']}, fondo {p['fondo']}")


if __name__ == "__main__":
    main()
