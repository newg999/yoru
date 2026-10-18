#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  raton.py — Ratón, touchpad y cursor para Ajustes › Ratón
#
#    raton.py leer             JSON con los ajustes (y si hay touchpad)
#    raton.py guardar '<json>' escribe su bloque en niri/local.kdl
#    raton.py restablecer      quita el bloque: vuelve lo de config.kdl
#
#  Como Ajustes › Pantallas (pantallas.py): solo se toca lo que va entre sus
#  dos marcas, niri lo aplica al guardar y una línea «// datos: {...}» guarda
#  lo elegido. Los valores de serie son los de config.kdl; en local.kdl solo
#  van los que cambias.
#
#  El tamaño del cursor se pone también en GTK (gsettings): si no, las apps
#  GTK lo dibujarían con el tamaño de antes.
# ----------------------------------------------------------------------------

import json
import os
import subprocess
import sys

CONFIG = os.path.expanduser("~/.config/niri/config.kdl")
LOCAL = os.path.expanduser("~/.config/niri/local.kdl")

INICIO = "// >>> Ratón — lo escribe Ajustes › Ratón (Mod+Alt+T)"
FIN = "// <<< Ratón"

CABECERA = """\
// ============================================================================
//  local.kdl — Ajustes solo para ESTE equipo (no se sube a git)
// ----------------------------------------------------------------------------
//  Los bloques marcados los escribe Ajustes (Mod+Alt+T). Lo que pongas fuera
//  de ellos se respeta.
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


def guardados():
    _, bloque, _ = partes(leer_local())
    for linea in (bloque or "").splitlines():
        if linea.strip().startswith("// datos: "):
            try:
                return json.loads(linea.strip()[len("// datos: "):])
            except json.JSONDecodeError:
                pass
    return {}


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


def escribir(nuevo):
    viejo = leer_local()
    with open(LOCAL, "w") as f:
        f.write(nuevo)
    r = subprocess.run(["niri", "validate", "-c", CONFIG], capture_output=True, text=True)
    if r.returncode != 0:
        if viejo is None:
            os.remove(LOCAL)
        else:
            with open(LOCAL, "w") as f:
                f.write(viejo)
        sys.exit("Niri no acepta el cambio:\n" + (r.stderr or r.stdout).strip())


def cursor_gtk(tamano):
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(int(tamano))],
                   capture_output=True)


def guardar(datos):
    antes, _, despues = partes(leer_local())
    escribir(antes.rstrip("\n") + "\n\n" + bloque(datos) + "\n" + despues.lstrip("\n"))
    cursor_gtk(datos["cursor"]["tamano"])


def restablecer():
    antes, viejo, despues = partes(leer_local())
    if viejo is not None:
        escribir(antes.rstrip("\n") + "\n" + despues.lstrip("\n"))
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
