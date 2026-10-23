#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  pantallas.py — Colocación de las pantallas para Ajustes › Pantallas
#
#    pantallas.py leer             JSON con las pantallas conectadas
#    pantallas.py guardar '<json>' escribe su bloque en niri/local.kdl
#    pantallas.py restablecer      quita el bloque (niri vuelve a lo suyo)
#
#  Niri recarga local.kdl al guardarlo, así que los cambios se ven al momento.
#  Solo se toca lo que va entre las dos marcas; el resto de local.kdl (lo que
#  escribas a mano) se respeta. Dentro del bloque va también una línea
#  «// datos: {...}» con lo elegido, para recordar dónde estaba una pantalla
#  aunque ahora esté apagada.
#
#  A los monitores externos se les nombra por marca, modelo y número de serie
#  (así su ajuste vale aunque cambies de puerto); al del portátil, por su
#  conector (eDP-1), que no cambia.
# ----------------------------------------------------------------------------

import json
import os
import subprocess
import sys
import time

CONFIG = os.path.expanduser("~/.config/niri/config.kdl")
LOCAL = os.path.expanduser("~/.config/niri/local.kdl")
APAGAR = "~/.config/niri/scripts/pantallas.sh"

INICIO = "// >>> Pantallas — lo escribe Ajustes › Pantallas (Mod+Alt+T)"
FIN = "// <<< Pantallas"

CABECERA = """\
// ============================================================================
//  local.kdl — Ajustes solo para ESTE equipo (no se sube a git)
// ----------------------------------------------------------------------------
//  Las pantallas se colocan desde Ajustes › Pantallas, que escribe el bloque
//  de abajo. Lo que pongas fuera de él se respeta.
// ============================================================================
"""


def leer_local():
    try:
        with open(LOCAL) as f:
            return f.read()
    except FileNotFoundError:
        return None


def partes(texto):
    """(antes, bloque, después) del bloque de pantallas; bloque None si no hay."""
    if texto is None:
        return CABECERA, None, ""
    i = texto.find(INICIO)
    j = texto.find(FIN, i + 1) if i >= 0 else -1
    if i < 0 or j < 0:
        return texto, None, ""
    return texto[:i], texto[i:j + len(FIN)], texto[j + len(FIN):]


def datos_guardados():
    _, bloque, _ = partes(leer_local())
    if bloque:
        for linea in bloque.splitlines():
            linea = linea.strip()
            if linea.startswith("// datos: "):
                try:
                    return json.loads(linea[len("// datos: "):])
                except json.JSONDecodeError:
                    pass
    return {"pantallas": {}, "apagarPortatil": False}


def ident(o):
    if o["name"].startswith("eDP"):
        return o["name"]
    return " ".join(x or "Unknown" for x in (o["make"], o["model"], o["serial"]))


def leer():
    todas = salidas()
    guardado = datos_guardados()
    lista = []
    for nombre in sorted(todas):
        o = todas[nombre]
        i = ident(o)
        g = guardado["pantallas"].get(i, {})
        interna = nombre.startswith("eDP")

        # Modos sin repetir (niri a veces da dos iguales)
        modos, vistos = [], set()
        for m in o["modes"]:
            clave = (m["width"], m["height"], m["refresh_rate"])
            if clave not in vistos:
                vistos.add(clave)
                modos.append({"w": m["width"], "h": m["height"], "hz": m["refresh_rate"],
                              "preferido": m["is_preferred"]})

        log = o["logical"]
        if o["current_mode"] is not None:
            m = o["modes"][o["current_mode"]]
            modo = {"w": m["width"], "h": m["height"], "hz": m["refresh_rate"]}
        else:
            modo = g.get("modo") or next(({"w": m["w"], "h": m["h"], "hz": m["hz"]}
                                          for m in modos if m["preferido"]), None) \
                or {"w": modos[0]["w"], "h": modos[0]["h"], "hz": modos[0]["hz"]}

        # «Dell Inc.» + «DELL P2219H» → «DELL P2219H»
        marca = (o["make"] or "").replace(" Inc.", "").strip()
        modelo = (o["model"] or "").strip()
        if modelo.lower().startswith(marca.split(" ")[0].lower()) if marca else True:
            marca = ""
        etiqueta = "Pantalla del portátil" if interna else (" ".join(x for x in (marca, modelo) if x) or nombre)
        lista.append({
            "nombre": nombre,
            "id": i,
            "etiqueta": etiqueta,
            "interna": interna,
            "encendida": log is not None,
            "x": log["x"] if log else g.get("x"),
            "y": log["y"] if log else g.get("y"),
            "escala": log["scale"] if log else g.get("escala", 1),
            "giro": log["transform"] if log else g.get("giro", "Normal"),
            "modo": modo,
            "modos": modos,
            "principal": g.get("principal", False),
            "pulgadas": round((o["physical_size"][0] ** 2 + o["physical_size"][1] ** 2) ** 0.5 / 25.4, 1)
            if o.get("physical_size") and o["physical_size"][0] else 0,
        })
    print(json.dumps({"pantallas": lista, "apagarPortatil": guardado.get("apagarPortatil", False)}))


def num(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


GIROS = {"Normal": None, "90": "90", "180": "180", "270": "270", "Flipped": "flipped",
         "Flipped90": "flipped-90", "Flipped180": "flipped-180", "Flipped270": "flipped-270"}


def bloque(datos):
    lineas = [INICIO]
    guardar = {"pantallas": {}, "apagarPortatil": bool(datos.get("apagarPortatil"))}
    for p in datos["pantallas"]:
        guardar["pantallas"][p["id"]] = {k: p.get(k) for k in ("x", "y", "escala", "giro", "modo", "principal")}
        cuerpo = []
        # El portátil nunca se apaga «fijo»: sin monitor te quedarías a oscuras.
        # Para eso está «apagarPortatil» (pantallas.sh, solo si hay otro).
        if not p["encendida"] and not p["interna"]:
            cuerpo.append("off")
        m = p["modo"]
        cuerpo.append('mode "%dx%d@%d.%03d"' % (m["w"], m["h"], m["hz"] // 1000, m["hz"] % 1000))
        cuerpo.append("scale %s" % num(p["escala"]))
        if GIROS.get(p.get("giro") or "Normal"):
            cuerpo.append('transform "%s"' % GIROS[p["giro"]])
        if p.get("x") is not None:
            cuerpo.append("position x=%d y=%d" % (p["x"], p["y"]))
        if p.get("principal"):
            cuerpo.append("focus-at-startup")
        # VRR solo con los juegos (la regla de config/niri/rules.kdl): en el
        # escritorio, frecuencia fija. Si el monitor no tiene VRR, no hace nada
        cuerpo.append("variable-refresh-rate on-demand=true")
        lineas.append('output "%s" {' % p["id"].replace('"', '\\"'))
        lineas += ["    " + c for c in cuerpo]
        lineas.append("}")
    if guardar["apagarPortatil"]:
        lineas.append('spawn-sh-at-startup "%s"' % APAGAR)
    lineas.append("// datos: " + json.dumps(guardar, ensure_ascii=False))
    lineas.append(FIN)
    return "\n".join(lineas)


def salidas():
    return json.loads(subprocess.run(["niri", "msg", "-j", "outputs"],
                                     capture_output=True, text=True, check=True).stdout)


def escribir(nuevo):
    """Escribe local.kdl; si niri no lo acepta, deja el de antes y falla."""
    viejo = leer_local()
    # El portátil apagado a mano (Mod+Alt+Shift+P) se enciende solo si cambia
    # su sección de local.kdl: niri la vuelve a aplicar entera. Se apunta
    # para apagarlo otra vez en cuanto niri recargue.
    apagadas = [n for n, o in salidas().items() if n.startswith("eDP") and o["logical"] is None]
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
    # Niri recarga al ver el archivo cambiado (unas décimas después)
    for _ in range(20):
        if not apagadas:
            break
        time.sleep(0.1)
        ahora = salidas()
        for n in list(apagadas):
            if n in ahora and ahora[n]["logical"] is not None:
                subprocess.run(["niri", "msg", "output", n, "off"])
                apagadas.remove(n)


def guardar(datos):
    antes, _, despues = partes(leer_local())
    antes = antes.rstrip("\n") + "\n\n"
    escribir(antes + bloque(datos) + "\n" + despues.lstrip("\n"))


def restablecer():
    texto = leer_local()
    antes, viejo, despues = partes(texto)
    if viejo is None:
        return
    escribir(antes.rstrip("\n") + "\n" + despues.lstrip("\n"))


if __name__ == "__main__":
    orden = sys.argv[1] if len(sys.argv) > 1 else ""
    if orden == "leer":
        leer()
    elif orden == "guardar" and len(sys.argv) > 2:
        guardar(json.loads(sys.argv[2]))
    elif orden == "restablecer":
        restablecer()
    else:
        sys.exit(__doc__ or "pantallas.py leer | guardar '<json>' | restablecer")
