#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  raton.py — Ratón, touchpad y cursor para Ajustes › Ratón
#
#    raton.py leer             JSON con los ajustes (y si hay touchpad)
#    raton.py guardar '<json>' escribe niri/raton.kdl
#    raton.py restablecer      borra raton.kdl: vuelve lo de config.kdl
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
//  raton.kdl — Ratón, touchpad y cursor de ESTE equipo (no se sube a git)
// ----------------------------------------------------------------------------
//  Lo escribe Ajustes › Ratón (Mod+Alt+T): los cambios a mano se pierden
//  al guardar desde allí. Borrarlo = volver a lo de config.kdl.
// ============================================================================
"""

# Lo que hay en config.kdl (si cambias allí algo de esto, cámbialo también aquí)
DE_SERIE = {
    "raton": {"velocidad": 0.5, "perfil": "adaptive", "natural": False, "rueda": 1.0, "zurdo": False},
    "touchpad": {"velocidad": 0.0, "tocar": True, "natural": True, "escribiendo": True,
                 "conRaton": False, "rueda": 1.0},
    "cursor": {"tamano": 24, "esconder": False},
}


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
    m = re.search(r"mouse\s*\{([^}]*)\}", texto)
    if not m:
        return {}
    raton = {}
    v = re.search(r"accel-speed\s+(-?[\d.]+)", m.group(1))
    if v:
        raton["velocidad"] = float(v.group(1))
    p = re.search(r'accel-profile\s+"(\w+)"', m.group(1))
    if p:
        raton["perfil"] = p.group(1)
    return {"raton": raton}


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

    lineas = [INICIO, "input {", "    mouse {"]
    lineas += ["        " + x for x in raton]
    lineas += ["    }", "    touchpad {"]
    lineas += ["        " + x for x in touch]
    lineas += ["    }", "}", "cursor {"]
    lineas += ["    " + x for x in cursor]
    lineas += ["}", "// datos: " + json.dumps({k: datos[k] for k in ("raton", "touchpad", "cursor")}), FIN]
    return "\n".join(lineas)


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


def restablecer():
    escribir(None)
    cursor_gtk(DE_SERIE["cursor"]["tamano"])


if __name__ == "__main__":
    orden = sys.argv[1] if len(sys.argv) > 1 else ""
    if orden == "leer":
        leer()
    elif orden == "guardar" and len(sys.argv) > 2:
        guardar(json.loads(sys.argv[2]))
    elif orden == "restablecer":
        restablecer()
    else:
        sys.exit("raton.py leer | guardar '<json>' | restablecer")
