#!/usr/bin/env python3
"""
monitor.py — datos para el monitor del sistema de Yoru (paneles/Monitor.qml)

Cada INTERVALO segundos escribe una línea JSON con:
  procesos: [{pid, nombre, usuario, cpu (%), mem (bytes), comando}]
  cpu (%), memUsada / memTotal (bytes), red (bytes/s bajada y subida),
  disco (bytes/s leídos y escritos)

La CPU de cada proceso es la de los últimos segundos (no la media desde que
arrancó, que es lo que da "ps"). Solo lee /proc: no necesita nada más.
Quickshell lo arranca al abrir el panel y lo para al cerrarlo.
"""

import json
import os
import pwd
import sys
import time

INTERVALO = 2
PAGINA = os.sysconf("SC_PAGE_SIZE")
NUCLEOS = os.cpu_count() or 1
MI_UID = os.getuid()

usuarios = {}


def usuario(uid):
    if uid not in usuarios:
        try:
            usuarios[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            usuarios[uid] = str(uid)
    return usuarios[uid]


def cpu_total():
    with open("/proc/stat") as f:
        n = [int(x) for x in f.readline().split()[1:]]
    return sum(n), n[3] + n[4]


def leer_procesos():
    """pid → (nombre, uid, ticks de cpu, memoria, comando)"""
    datos = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as f:
                stat = f.read()
            # El nombre va entre paréntesis y puede tener espacios
            nombre = stat[stat.index("(") + 1:stat.rindex(")")]
            campos = stat[stat.rindex(")") + 2:].split()
            ticks = int(campos[11]) + int(campos[12])
            rss = int(campos[21]) * PAGINA
            uid = os.stat(f"/proc/{pid}").st_uid
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                comando = f.read().replace(b"\0", b" ").decode(errors="replace").strip()
            datos[int(pid)] = (nombre, uid, ticks, rss, comando)
        except (FileNotFoundError, ProcessLookupError, PermissionError, ValueError, IndexError):
            continue
    return datos


def memoria():
    info = {}
    with open("/proc/meminfo") as f:
        for linea in f:
            clave, valor = linea.split(":", 1)
            info[clave] = int(valor.split()[0]) * 1024
    return info["MemTotal"] - info["MemAvailable"], info["MemTotal"]


def red():
    bajada = subida = 0
    with open("/proc/net/dev") as f:
        for linea in f.readlines()[2:]:
            nombre, datos = linea.split(":", 1)
            if nombre.strip() == "lo":
                continue
            c = datos.split()
            bajada += int(c[0])
            subida += int(c[8])
    return bajada, subida


def disco():
    leido = escrito = 0
    with open("/proc/diskstats") as f:
        for linea in f:
            c = linea.split()
            nombre = c[2]
            # Solo discos enteros (nvme0n1, sda...), no sus particiones
            if nombre.startswith(("loop", "ram", "zram", "dm-")):
                continue
            if nombre.startswith("nvme") and "p" in nombre[4:]:
                continue
            if nombre.startswith(("sd", "vd")) and nombre[-1].isdigit():
                continue
            leido += int(c[5]) * 512
            escrito += int(c[9]) * 512
    return leido, escrito


def main():
    antes_total, antes_libre = cpu_total()
    antes = leer_procesos()
    antes_red, antes_disco = red(), disco()
    antes_t = time.monotonic()

    while True:
        time.sleep(INTERVALO)
        total, libre = cpu_total()
        ahora = leer_procesos()
        ahora_red, ahora_disco = red(), disco()
        t = time.monotonic()
        dt_ticks = max(1, total - antes_total)
        dt = max(0.001, t - antes_t)

        procesos = []
        for pid, (nombre, uid, ticks, rss, comando) in ahora.items():
            previo = antes.get(pid)
            uso = 0.0
            if previo:
                # % de toda la CPU (100 % = todos los núcleos a tope)
                uso = 100 * (ticks - previo[2]) / dt_ticks
            procesos.append({
                "pid": pid,
                "nombre": nombre,
                "usuario": usuario(uid),
                "mio": uid == MI_UID,
                "cpu": round(uso, 1),
                "mem": rss,
                "comando": comando or f"[{nombre}]",
            })

        usada, total_mem = memoria()
        print(json.dumps({
            "procesos": procesos,
            "cpu": round(100 * (1 - (libre - antes_libre) / dt_ticks), 1),
            "nucleos": NUCLEOS,
            "memUsada": usada,
            "memTotal": total_mem,
            "bajada": (ahora_red[0] - antes_red[0]) / dt,
            "subida": (ahora_red[1] - antes_red[1]) / dt,
            "leido": (ahora_disco[0] - antes_disco[0]) / dt,
            "escrito": (ahora_disco[1] - antes_disco[1]) / dt,
        }), flush=True)

        antes_total, antes_libre, antes = total, libre, ahora
        antes_red, antes_disco, antes_t = ahora_red, ahora_disco, t


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
