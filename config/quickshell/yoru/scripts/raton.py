#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  raton.py — Ratón, touchpad, cursor y teclado para Ajustes › Ratón y
#  Ajustes › Teclado
#
#    raton.py leer                   JSON con los ajustes (y si hay touchpad)
#    raton.py guardar '<json>'       escribe niri/raton.kdl
#    raton.py restablecer [teclado]  vuelve a lo de serie el ratón (o el teclado)
#    raton.py distribuciones         JSON con las distribuciones de teclado
#                                    (con sus variantes), con nombre en español
#
#  Va en su propio archivo (raton.kdl, que config.kdl incluye después de
#  local.kdl) y no dentro de local.kdl: si ahí ya había un «input {...}»
#  escrito a mano, niri no acepta otro en el mismo archivo («duplicate node
#  input»). Al ir después, sus secciones mouse y touchpad mandan sobre las
#  de local.kdl. Niri lo aplica al guardar y una línea «// datos: {...}»
#  guarda lo elegido.
#
#  Antes iba en un bloque de local.kdl: si lo hay, se lee y se quita.
#
#  El teclado va en el mismo archivo: install.sh lo copia también al login
#  (greetd), y así la contraseña se escribe con tu distribución.
#
#  El tamaño del cursor se pone también en GTK (gsettings): si no, las apps
#  GTK lo dibujarían con el tamaño de antes.
# ----------------------------------------------------------------------------

import json
import os
import re
import subprocess
import sys

CONFIG = os.path.expanduser("~/.config/niri/config.kdl")
LOCAL = os.path.expanduser("~/.config/niri/local.kdl")
RATON = os.path.expanduser("~/.config/niri/raton.kdl")

INICIO = "// >>> Ratón — lo escribe Ajustes › Ratón (Mod+Alt+T)"
FIN = "// <<< Ratón"

CABECERA = """\
// ============================================================================
//  raton.kdl — Ratón, touchpad, cursor y teclado de ESTE equipo (no se sube
//  a git)
// ----------------------------------------------------------------------------
//  Lo escriben Ajustes › Ratón y › Teclado (Mod+Alt+T): los cambios a mano se pierden
//  al guardar desde allí. Borrarlo = volver a lo de config.kdl.
// ============================================================================
"""

# Lo que hay en config.kdl (si cambias allí algo de esto, cámbialo también aquí)
DE_SERIE = {
    "raton": {"velocidad": 0.5, "perfil": "adaptive", "natural": False, "rueda": 1.0, "zurdo": False},
    "touchpad": {"velocidad": 0.0, "tocar": True, "natural": True, "escribiendo": True,
                 "conRaton": False, "rueda": 1.0},
    "cursor": {"tamano": 24, "esconder": False},
    # distribuciones: [{layout, variant}], la primera es la principal (vacía =
    # la del sistema). cambiar: la opción grp: de xkb para pasar de una a otra
    "teclado": {"distribuciones": [], "cambiar": "alt_shift_toggle", "porVentana": False,
                "retardo": 600, "velocidad": 25, "mayus": "", "numlock": True},
}

# Lo que puede hacer Bloq Mayús (opción de xkb)
MAYUS = {"escape": "caps:escape", "ctrl": "ctrl:nocaps", "nada": "caps:none"}


def leer_local():
    try:
        with open(LOCAL) as f:
            return f.read()
    except FileNotFoundError:
        return None


def partes(texto):
    if texto is None:
        return CABECERA, None, ""
    i = texto.find(INICIO)
    j = texto.find(FIN, i + 1) if i >= 0 else -1
    if i < 0 or j < 0:
        return texto, None, ""
    return texto[:i], texto[i:j + len(FIN)], texto[j + len(FIN):]


def leer_raton():
    try:
        with open(RATON) as f:
            return f.read()
    except FileNotFoundError:
        return None


def datos_de(texto):
    for linea in (texto or "").splitlines():
        if linea.strip().startswith("// datos: "):
            try:
                return json.loads(linea.strip()[len("// datos: "):])
            except json.JSONDecodeError:
                pass
    return None


def a_mano():
    """Lo del ratón escrito a mano en local.kdl (accel-speed y accel-profile),
    para que la pestaña lo enseñe la primera vez en vez de los de serie."""
    texto = leer_local() or ""
    datos = {}
    teclado = teclado_a_mano(texto)
    if teclado:
        datos["teclado"] = teclado
    m = re.search(r"mouse\s*\{([^}]*)\}", texto)
    if not m:
        return datos
    raton = {}
    v = re.search(r"accel-speed\s+(-?[\d.]+)", m.group(1))
    if v:
        raton["velocidad"] = float(v.group(1))
    p = re.search(r'accel-profile\s+"(\w+)"', m.group(1))
    if p:
        raton["perfil"] = p.group(1)
    datos["raton"] = raton
    return datos


def teclado_a_mano(texto):
    """La distribución y la repetición escritas a mano en local.kdl"""
    m = re.search(r"keyboard\s*\{(.*?)\n\s*\}", texto, re.S)
    if not m:
        return {}
    teclado = {}
    capas = re.search(r'layout\s+"([^"]*)"', m.group(1))
    if capas and capas.group(1):
        variantes = re.search(r'variant\s+"([^"]*)"', m.group(1))
        variantes = variantes.group(1).split(",") if variantes else []
        teclado["distribuciones"] = [{"layout": l, "variant": variantes[i] if i < len(variantes) else ""}
                                     for i, l in enumerate(capas.group(1).split(","))]
    for clave, nombre in (("retardo", "repeat-delay"), ("velocidad", "repeat-rate")):
        v = re.search(nombre + r"\s+(\d+)", m.group(1))
        if v:
            teclado[clave] = int(v.group(1))
    return teclado


def del_sistema():
    """La distribución que eligió Fedora al instalar (localectl)"""
    r = subprocess.run(["localectl", "status"], capture_output=True, text=True)
    campos = {}
    for linea in r.stdout.splitlines():
        if ":" in linea:
            k, v = linea.split(":", 1)
            campos[k.strip()] = v.strip()
    capas = campos.get("X11 Layout", "us").split(",")
    variantes = campos.get("X11 Variant", "").split(",")
    return [{"layout": l, "variant": variantes[i] if i < len(variantes) else ""} for i, l in enumerate(capas)]


def guardados():
    return datos_de(leer_raton()) or datos_de(partes(leer_local())[1]) or a_mano()


def hay_touchpad():
    try:
        with open("/proc/bus/input/devices") as f:
            return "touchpad" in f.read().lower()
    except OSError:
        return False


def leer():
    datos = json.loads(json.dumps(DE_SERIE))
    for seccion, valores in guardados().items():
        if seccion in datos:
            datos[seccion].update({k: v for k, v in valores.items() if k in datos[seccion]})
    if not datos["teclado"]["distribuciones"]:
        datos["teclado"]["distribuciones"] = del_sistema()
    datos["hayTouchpad"] = hay_touchpad()
    print(json.dumps(datos))


def num(v):
    return ("%.2f" % float(v)).rstrip("0").rstrip(".") if float(v) != int(float(v)) else "%.1f" % float(v)


# Las secciones mouse y touchpad de local.kdl sustituyen enteras a las de
# config.kdl (niri no las mezcla), y en ellas no vale «natural-scroll false»:
# una opción desactivada simplemente no se escribe
def bandera(nombre, v):
    return [nombre] if v else []


def bloque(datos):
    r, t, c = datos["raton"], datos["touchpad"], datos["cursor"]
    raton = ["accel-speed " + num(r["velocidad"]),
             'accel-profile "%s"' % ("flat" if r["perfil"] == "flat" else "adaptive"),
             "scroll-factor " + num(r["rueda"])]
    raton += bandera("natural-scroll", r["natural"]) + bandera("left-handed", r["zurdo"])
    touch = ["accel-speed " + num(t["velocidad"]), "scroll-factor " + num(t["rueda"])]
    touch += bandera("tap", t["tocar"]) + bandera("natural-scroll", t["natural"])
    touch += bandera("dwt", t["escribiendo"]) + bandera("disabled-on-external-mouse", t["conRaton"])
    touch += bandera("left-handed", r["zurdo"])        # el touchpad usa la mano del ratón
    cursor = ["xcursor-size %d" % int(c["tamano"])] + bandera("hide-when-typing", c["esconder"])

    lineas = [INICIO, "input {"] + bloque_teclado(datos["teclado"]) + ["    mouse {"]
    lineas += ["        " + x for x in raton]
    lineas += ["    }", "    touchpad {"]
    lineas += ["        " + x for x in touch]
    lineas += ["    }", "}", "cursor {"]
    lineas += ["    " + x for x in cursor]
    lineas += ["}", "// datos: " + json.dumps({k: datos[k] for k in DE_SERIE}), FIN]
    return "\n".join(lineas)


def bloque_teclado(t):
    distribuciones = t["distribuciones"] or del_sistema()
    opciones = []
    if len(distribuciones) > 1 and t["cambiar"]:
        opciones.append("grp:" + t["cambiar"])
    # Si Bloq Mayús cambia de distribución, no puede hacer otra cosa
    if t["mayus"] in MAYUS and not (len(distribuciones) > 1 and t["cambiar"] == "caps_toggle"):
        opciones.append(MAYUS[t["mayus"]])
    xkb = ['layout "%s"' % ",".join(d["layout"] for d in distribuciones)]
    if any(d["variant"] for d in distribuciones):
        xkb.append('variant "%s"' % ",".join(d["variant"] for d in distribuciones))
    if opciones:
        xkb.append('options "%s"' % ",".join(opciones))
    lineas = ["    keyboard {", "        xkb {"]
    lineas += ["            " + x for x in xkb]
    lineas += ["        }",
               "        repeat-delay %d" % int(t["retardo"]),
               "        repeat-rate %d" % int(t["velocidad"])]
    if t["porVentana"]:
        lineas.append('        track-layout "window"')
    lineas += ["        numlock"] if t["numlock"] else []
    lineas.append("    }")
    return lineas


def validar_o_volver(restaurar):
    r = subprocess.run(["niri", "validate", "-c", CONFIG], capture_output=True, text=True)
    if r.returncode != 0:
        restaurar()
        sys.exit("Niri no acepta el cambio:\n" + (r.stderr or r.stdout).strip())


def escribir(nuevo):
    """Escribe raton.kdl (None = borrarlo) y quita el bloque viejo de local.kdl."""
    viejo, local = leer_raton(), leer_local()

    def restaurar():
        if viejo is None:
            if os.path.exists(RATON):
                os.remove(RATON)
        else:
            with open(RATON, "w") as f:
                f.write(viejo)
        if local is not None:
            with open(LOCAL, "w") as f:
                f.write(local)

    if nuevo is None:
        if os.path.exists(RATON):
            os.remove(RATON)
    else:
        with open(RATON, "w") as f:
            f.write(nuevo)
    antes, bloque, despues = partes(local)
    if local is not None and bloque is not None:
        with open(LOCAL, "w") as f:
            f.write(antes.rstrip("\n") + "\n" + despues.lstrip("\n"))
    validar_o_volver(restaurar)


def cursor_gtk(tamano):
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(int(tamano))],
                   capture_output=True)


def guardar(datos):
    escribir(CABECERA + "\n" + bloque(datos) + "\n")
    cursor_gtk(datos["cursor"]["tamano"])


def restablecer(que):
    """Vuelve a lo de serie el ratón (touchpad y cursor incluidos) o el
    teclado, sin tocar lo otro. Si ya no queda nada cambiado, borra raton.kdl."""
    actuales = guardados()
    secciones = ["teclado"] if que == "teclado" else ["raton", "touchpad", "cursor"]
    for seccion in secciones:
        actuales.pop(seccion, None)
    if not any(k in actuales for k in DE_SERIE):
        escribir(None)
    else:
        datos = json.loads(json.dumps(DE_SERIE))
        for seccion, valores in actuales.items():
            if seccion in datos:
                datos[seccion].update({k: v for k, v in valores.items() if k in datos[seccion]})
        escribir(CABECERA + "\n" + bloque(datos) + "\n")
    if que != "teclado":
        cursor_gtk(DE_SERIE["cursor"]["tamano"])


def distribuciones():
    """Las de xkb (evdev.lst), con sus variantes, traducidas si se puede"""
    try:
        import gettext
        traducir = gettext.translation("xkeyboard-config", languages=["es"]).gettext
    except OSError:
        traducir = str
    lista, parte = [], ""
    with open("/usr/share/X11/xkb/rules/evdev.lst") as f:
        for linea in f:
            if linea.startswith("!"):
                parte = linea[1:].strip()
                continue
            trozos = linea.split(None, 1)
            if len(trozos) < 2:
                continue
            if parte == "layout":
                lista.append({"layout": trozos[0], "variant": "", "nombre": traducir(trozos[1].strip())})
            elif parte == "variant":
                capa, nombre = trozos[1].split(":", 1)
                lista.append({"layout": capa, "variant": trozos[0], "nombre": traducir(nombre.strip())})
    print(json.dumps(lista, ensure_ascii=False))


if __name__ == "__main__":
    orden = sys.argv[1] if len(sys.argv) > 1 else ""
    if orden == "leer":
        leer()
    elif orden == "guardar" and len(sys.argv) > 2:
        guardar(json.loads(sys.argv[2]))
    elif orden == "restablecer":
        restablecer(sys.argv[2] if len(sys.argv) > 2 else "raton")
    elif orden == "distribuciones":
        distribuciones()
    else:
        sys.exit("raton.py leer | guardar '<json>' | restablecer [teclado] | distribuciones")
