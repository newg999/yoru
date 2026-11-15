#!/usr/bin/env python3
# ============================================================================
#  cursor.py — cuánto se mueve el ratón, para que Hotaru (la luna de la
#  isla) lo siga también por encima de las ventanas
#
#  Wayland no le dice a la barra dónde está el cursor si no está encima de
#  ella. Este script lee el ratón de /dev/input y escribe, unas 60 veces por
#  segundo, cuánto se ha movido el cursor en píxeles:
#
#    12.80 -3.20
#
#  comun/Raton.qml lo suma a la última posición conocida (y la corrige cada
#  vez que el ratón pasa por la isla o el escritorio).
#
#  Imita la aceleración de niri (libinput) con lo que diga niri/raton.kdl o
#  config.kdl: con «flat» es exacto; con «adaptive», aproximado.
#
#  Permisos: system/udev/70-yoru-raton.rules deja leer SOLO los ratones (no
#  los teclados) a quien está sentado delante (install.sh lo instala). Sin
#  ella no lee nada y Hotaru sigue como antes.
# ============================================================================
import os
import re
import select
import struct
import sys
import time

EVENTO = struct.Struct("llHHi")      # timeval, tipo, código, valor
EV_SYN, EV_REL = 0, 2
REL_X, REL_Y = 0, 1
CADA = 1 / 60                         # cada cuánto escribe
NIRI = os.path.expanduser("~/.config/niri")


# ------------------------------------------------------------ Aceleración
def ajustes():
    """(perfil, velocidad) del ratón: raton.kdl manda sobre config.kdl"""
    perfil, velocidad = "adaptive", 0.0
    for nombre in ("config.kdl", "raton.kdl"):
        try:
            texto = open(os.path.join(NIRI, nombre)).read()
        except OSError:
            continue
        texto = re.sub(r"//[^\n]*", "", texto)
        bloque = re.search(r"\bmouse\s*\{([^}]*)\}", texto)
        if not bloque:
            continue
        p = re.search(r'accel-profile\s+"(\w+)"', bloque.group(1))
        v = re.search(r"accel-speed\s+(-?[\d.]+)", bloque.group(1))
        if p:
            perfil = p.group(1)
        if v:
            velocidad = max(-1.0, min(1.0, float(v.group(1))))
    return perfil, velocidad


def factor(perfil, s, rapidez):
    """Lo que multiplica libinput el movimiento. rapidez: unidades/ms"""
    if perfil == "flat":
        return 1 + s
    # Perfil lineal (adaptive) de libinput para ratones
    umbral = 0.4 - 0.25 * s
    maximo = 2.0 + 2.0 * s
    pendiente = 1.1 + s
    if rapidez < 0.07:
        f = 10 * rapidez + 0.3
    elif rapidez < umbral:
        f = 1.0
    else:
        f = pendiente * (rapidez - umbral) + 1
    return min(maximo, f)


# --------------------------------------------------------------- Ratones
def ratones():
    """Los /dev/input/eventN que son ratones (se mueven en X e Y) y no
    teclados"""
    try:
        bloques = open("/proc/bus/input/devices").read().split("\n\n")
    except OSError:
        return set()
    hay = set()
    for b in bloques:
        h = re.search(r"^H: Handlers=(.*)$", b, re.M)
        rel = re.search(r"^B: REL=([0-9a-f ]+)$", b, re.M)
        if not h or not rel:
            continue
        manejadores = h.group(1).split()
        if "kbd" in manejadores or not any(m.startswith("mouse") for m in manejadores):
            continue
        if int(rel.group(1).split()[-1], 16) & 3 != 3:
            continue
        hay.update("/dev/input/" + m for m in manejadores if m.startswith("event"))
    return hay


def main():
    abiertos = {}                       # ruta → descriptor
    perfil, s = ajustes()
    marcas = None
    revisado = 0.0
    dx = dy = 0.0                       # lo que falta por escribir
    fx = fy = 0                         # el paquete en curso (hasta SYN)
    recientes = []                      # (t, distancia) para la rapidez
    escrito = time.monotonic()

    while True:
        ahora = time.monotonic()
        # Ratones que se enchufan o se van, y los ajustes de niri
        if ahora - revisado > 2:
            revisado = ahora
            hay = ratones()
            for r in list(abiertos):
                if r not in hay:
                    os.close(abiertos.pop(r))
            for r in hay - abiertos.keys():
                try:
                    abiertos[r] = os.open(r, os.O_RDONLY | os.O_NONBLOCK)
                except OSError:
                    pass
            nuevas = []
            for n in ("config.kdl", "raton.kdl"):
                try:
                    nuevas.append(os.stat(os.path.join(NIRI, n)).st_mtime)
                except OSError:
                    nuevas.append(0)
            if nuevas != marcas:
                marcas = nuevas
                perfil, s = ajustes()

        listos, _, _ = select.select(list(abiertos.values()), [], [], CADA)
        for fd in listos:
            try:
                datos = os.read(fd, EVENTO.size * 256)
            except OSError:
                continue
            for i in range(0, len(datos) - EVENTO.size + 1, EVENTO.size):
                seg, us, tipo, cod, val = EVENTO.unpack_from(datos, i)
                if tipo == EV_REL and cod == REL_X:
                    fx += val
                elif tipo == EV_REL and cod == REL_Y:
                    fy += val
                elif tipo == EV_SYN and (fx or fy):
                    t = seg * 1000 + us / 1000          # ms
                    d = (fx * fx + fy * fy) ** 0.5
                    recientes.append((t, d))
                    while recientes and t - recientes[0][0] > 12:
                        recientes.pop(0)
                    lapso = max(1.0, t - recientes[0][0])
                    rapidez = sum(x[1] for x in recientes) / lapso
                    f = factor(perfil, s, rapidez)
                    dx += fx * f
                    dy += fy * f
                    fx = fy = 0

        ahora = time.monotonic()
        if (dx or dy) and ahora - escrito >= CADA:
            escrito = ahora
            print(f"{dx:.2f} {dy:.2f}", flush=True)
            dx = dy = 0.0


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
