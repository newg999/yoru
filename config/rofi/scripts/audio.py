#!/usr/bin/env python3
"""
audio.py — Menú de audio con rofi + PipeWire

  · Elige por dónde suena: altavoces, auriculares, monitor (HDMI), bluetooth...
    La salida activa sale en verde. Lo que esté sonando se mueve al momento.
  · Elige el micrófono
  · Silenciar / activar y volumen rápido
  · Mezclador completo (pavucontrol)

Atajo: Mod+Alt+A   ·   Clic en el volumen de la barra

Si hace falta, cambia solo el perfil de la tarjeta (por ejemplo, de
"analógico" a "HDMI"), intentando no perder el micrófono por el camino.
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from rofimenu import ejecutar, menu, avisar, escapar  # noqa: E402

ALTAVOZ = "\U000f04c3"
AURICULARES = "\U000f02cb"
MONITOR = "\U000f0379"
BLUETOOTH = "\U000f00af"
MICRO = "\U000f036c"
MICRO_OFF = "\U000f036d"
VOL_ALTO = "\U000f057e"
VOL_OFF = "\U000f0581"
AJUSTES = "\U000f0493"
VOLVER = "\U000f004d"   # flecha atrás

# Icono según el tipo de puerto ("port.type" de PipeWire)
ICONOS = {
    "speaker": ALTAVOZ,
    "headphones": AURICULARES,
    "headset": AURICULARES,
    "hdmi": MONITOR,
    "displayport": MONITOR,
    "mic": MICRO,
}


# ------------------------------------------------------------- Lectura
def pw_dump():
    _, salida = ejecutar(["pw-dump"], timeout=5)
    try:
        return json.loads(salida)
    except json.JSONDecodeError:
        return []


def info_ruta(ruta):
    """El campo "info" de una ruta es [n, clave, valor, clave, valor...]."""
    datos = ruta.get("info") or []
    return dict(zip(datos[1::2], datos[2::2]))


def nodo_por_defecto(objetos, clave):
    """Nombre del sink/source por defecto (default.audio.sink/source)."""
    for o in objetos:
        if o.get("type", "").endswith("Metadata") and \
                o.get("props", {}).get("metadata.name") == "default":
            for m in o.get("metadata", []):
                if m.get("key") == clave:
                    return (m.get("value") or {}).get("name")
    return None


def destinos(objetos, direccion):
    """
    Lista de salidas (direccion="Output") o entradas ("Input") disponibles.
    Cada una es un dict con: texto, icono, activo, y lo necesario para elegirla.
    """
    clase = "Audio/Sink" if direccion == "Output" else "Audio/Source"
    defecto = nodo_por_defecto(objetos, "default.audio.sink" if direccion == "Output"
                               else "default.audio.source")
    nodos = [o for o in objetos if o.get("type", "").endswith("Node")
             and o["info"]["props"].get("media.class") == clase]
    tarjetas = [o for o in objetos if o.get("type", "").endswith("Device")
                and o["info"]["props"].get("media.class") == "Audio/Device"]

    lista = []
    for t in tarjetas:
        props, params = t["info"]["props"], t["info"].get("params", {})
        perfil = (params.get("Profile") or [{}])[0].get("index")
        activas = {r["index"] for r in params.get("Route", [])}
        nodo = next((n for n in nodos if n["info"]["props"].get("device.id") == t["id"]), None)
        nombre_tarjeta = props.get("device.description", props.get("device.name", "?"))
        es_bt = props.get("device.api") == "bluez5"

        for r in params.get("EnumRoute", []):
            if r.get("direction") != direccion or r.get("available") == "no":
                continue
            info = info_ruta(r)
            if es_bt:
                texto, icono = nombre_tarjeta, BLUETOOTH
            else:
                texto = r.get("description", r["name"])
                if info.get("device.product.name"):  # nombre del monitor (HDMI)
                    texto = f"{info['device.product.name']} ({texto})"
                icono = ICONOS.get(info.get("port.type"), ALTAVOZ if direccion == "Output" else MICRO)
            lista.append({
                "texto": texto,
                "icono": icono,
                "activo": (nodo is not None and nodo["info"]["props"].get("node.name") == defecto
                           and perfil in r.get("profiles", []) and r["index"] in activas),
                "tarjeta": t,
                "ruta": r,
            })

    # Sinks/sources sin tarjeta (virtuales, EasyEffects...), sin los "monitor"
    for n in nodos:
        p = n["info"]["props"]
        if p.get("device.id") is None and not p.get("node.name", "").endswith(".monitor"):
            lista.append({
                "texto": p.get("node.description", p.get("node.name", "?")),
                "icono": ALTAVOZ if direccion == "Output" else MICRO,
                "activo": p.get("node.name") == defecto,
                "nodo": p.get("node.name"),
            })
    return lista


# ------------------------------------------------------------- Cambios
def mejor_perfil(tarjeta, ruta):
    """Perfil que incluye la ruta y conserva las demás rutas activas (el micro...)."""
    params = tarjeta["info"].get("params", {})
    actual = (params.get("Profile") or [{}])[0].get("index")
    if actual in ruta.get("profiles", []):
        return None  # no hace falta cambiar
    otras = [r for r in params.get("Route", []) if r.get("direction") != ruta.get("direction")]
    candidatos = []
    for p in params.get("EnumProfile", []):
        if p["index"] not in ruta.get("profiles", []) or p.get("available") == "no":
            continue
        conserva = sum(1 for r in otras
                       if any(e["index"] == r["index"] and p["index"] in e.get("profiles", [])
                              for e in params.get("EnumRoute", [])))
        candidatos.append((conserva, p.get("priority", 0), p["name"]))
    return max(candidatos)[2] if candidatos else None


def nodo_de_tarjeta(id_tarjeta, clase, intentos=20):
    """Espera a que aparezca el sink/source de la tarjeta tras cambiar de perfil."""
    for _ in range(intentos):
        for o in pw_dump():
            p = o.get("info", {}).get("props", {}) if o.get("type", "").endswith("Node") else {}
            if p.get("device.id") == id_tarjeta and p.get("media.class") == clase:
                return p.get("node.name")
        time.sleep(0.15)
    return None


def elegir(destino, direccion):
    salida = direccion == "Output"
    clase = "Audio/Sink" if salida else "Audio/Source"

    if "nodo" in destino:
        nodo = destino["nodo"]
    else:
        tarjeta, ruta = destino["tarjeta"], destino["ruta"]
        nombre_tarjeta = tarjeta["info"]["props"]["device.name"]
        perfil = mejor_perfil(tarjeta, ruta)
        if perfil:
            ejecutar(["pactl", "set-card-profile", nombre_tarjeta, perfil])
        nodo = nodo_de_tarjeta(tarjeta["id"], clase)
        if not nodo:
            avisar("Audio", f"No se pudo activar {destino['texto']}", urgente=True)
            return
        # Bluetooth no tiene "puertos" que elegir; el resto sí
        if tarjeta["info"]["props"].get("device.api") != "bluez5":
            ejecutar(["pactl", "set-sink-port" if salida else "set-source-port", nodo, ruta["name"]])

    ejecutar(["pactl", "set-default-sink" if salida else "set-default-source", nodo])

    # Mueve lo que ya está sonando (o grabando) al nuevo destino
    lista = "sink-inputs" if salida else "source-outputs"
    mover = "move-sink-input" if salida else "move-source-output"
    _, streams = ejecutar(["pactl", "list", "short", lista])
    for linea in streams.splitlines():
        if linea.strip():
            ejecutar(["pactl", mover, linea.split()[0], nodo])

    avisar("Audio", f"{'Sonando por' if salida else 'Micrófono'}: {destino['texto']}")


def volumen(objetivo):
    """(porcentaje, silenciado) de @DEFAULT_AUDIO_SINK@ o @DEFAULT_AUDIO_SOURCE@."""
    _, s = ejecutar(["wpctl", "get-volume", objetivo])
    try:
        return round(float(s.split()[1]) * 100), "MUTED" in s
    except (IndexError, ValueError):
        return 0, False


# ------------------------------------------------------------- Menús
def menu_destinos(direccion):
    lista = destinos(pw_dump(), direccion)
    titulo = "Salida" if direccion == "Output" else "Micrófono"
    opciones = [f"{VOLVER}  Volver"] + [f"{d['icono']}  {escapar(d['texto'])}" for d in lista]
    activos = [i + 1 for i, d in enumerate(lista) if d["activo"]]
    i = menu(titulo, opciones, activos=activos, fila=activos[0] if activos else 1)
    if i is None or i == 0:
        return
    elegir(lista[i - 1], direccion)


def menu_volumen():
    niveles = [10, 25, 50, 75, 100]
    actual, _ = volumen("@DEFAULT_AUDIO_SINK@")
    opciones = [f"{VOLVER}  Volver"] + [f"{VOL_ALTO}  {n}%" for n in niveles]
    cercano = min(range(len(niveles)), key=lambda k: abs(niveles[k] - actual)) + 1
    i = menu("Volumen", opciones, mensaje=f"Ahora: {actual}%   (la rueda sobre la barra va de 5 en 5)",
             activos=[cercano], fila=cercano)
    if i:
        ejecutar(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{niveles[i - 1]}%"])


def main():
    while True:
        objetos = pw_dump()
        salidas = destinos(objetos, "Output")
        entradas = destinos(objetos, "Input")
        salida = next((d["texto"] for d in salidas if d["activo"]), "—")
        micro = next((d["texto"] for d in entradas if d["activo"]), "—")
        vol, mudo = volumen("@DEFAULT_AUDIO_SINK@")
        _, micro_mudo = volumen("@DEFAULT_AUDIO_SOURCE@")

        # Las salidas van directamente en el menú principal: un clic y listo
        opciones = [f"{d['icono']}  {escapar(d['texto'])}" for d in salidas]
        n = len(opciones)
        opciones += [
            f"{VOL_OFF if mudo else VOL_ALTO}  {'Activar sonido' if mudo else 'Silenciar'}",
            f"{VOL_ALTO}  Volumen: {vol}%",
            f"{MICRO_OFF if micro_mudo else MICRO}  Micrófono: {escapar(micro)}"
            f"{'  (silenciado)' if micro_mudo else ''}",
            f"{MICRO_OFF if not micro_mudo else MICRO}  "
            f"{'Activar micrófono' if micro_mudo else 'Silenciar micrófono'}",
            f"{AJUSTES}  Mezclador completo",
        ]
        activos = [i for i, d in enumerate(salidas) if d["activo"]]
        urgentes = ([n] if mudo else []) + ([n + 2] if micro_mudo else [])
        mensaje = (f"Sonando por <b>{escapar(salida)}</b> · "
                   f"{'<span foreground=\"#bf616a\">silenciado</span>' if mudo else f'{vol}%'}")

        i = menu("Audio", opciones, mensaje=mensaje, activos=activos, urgentes=urgentes,
                 fila=activos[0] if activos else 0)
        if i is None:
            return
        if i < n:
            elegir(salidas[i], "Output")
            return
        accion = i - n
        if accion == 0:
            ejecutar(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        elif accion == 1:
            menu_volumen()
        elif accion == 2:
            menu_destinos("Input")
        elif accion == 3:
            ejecutar(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
        elif accion == 4:
            ejecutar(["setsid", "-f", "pavucontrol"])
            return


if __name__ == "__main__":
    main()
