#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  acerca.py — Datos del equipo y de Yoru para Ajustes › Acerca de
#
#    acerca.py leer       JSON: equipo, sistema, piezas y la versión de Yoru
#    acerca.py buscar     igual, pero antes pregunta a GitHub (git fetch)
#                         cuántos cambios nuevos hay de Yoru
#
#  Todo se lee sin ser root: /etc/os-release, /proc, /sys, lspci y git.
# ----------------------------------------------------------------------------

import json
import os
import platform
import re
import shutil
import subprocess
import sys

CASA = os.path.expanduser("~")
# El repositorio: ~/.local/bin/yoru es un enlace a su bin/yoru
REPO = os.path.dirname(os.path.dirname(os.path.realpath(os.path.join(CASA, ".local/bin/yoru"))))


def orden(*args, cwd=None):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=20, cwd=cwd).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def leer(ruta):
    try:
        with open(ruta) as f:
            return f.read().strip()
    except OSError:
        return ""


def sistema():
    datos = {}
    for linea in leer("/etc/os-release").splitlines():
        clave, _, valor = linea.partition("=")
        datos[clave] = valor.strip('"')
    return datos.get("PRETTY_NAME", "Linux")


# Fabricantes con nombre largo en la placa → el de siempre
NOMBRES = {
    "Micro-Star International Co., Ltd.": "MSI",
    "ASUSTeK COMPUTER INC.": "ASUS",
    "Gigabyte Technology Co., Ltd.": "Gigabyte",
    "LENOVO": "Lenovo",
    "HP": "HP",
    "Dell Inc.": "Dell",
}


def modelo():
    # Placa o modelo del portátil; los fabricantes rellenan a veces con basura
    basura = {"", "To Be Filled By O.E.M.", "Default string", "System Product Name"}
    for vendedor, nombre in (("sys_vendor", "product_name"), ("board_vendor", "board_name")):
        v = leer(f"/sys/class/dmi/id/{vendedor}")
        n = leer(f"/sys/class/dmi/id/{nombre}")
        if n not in basura and not re.fullmatch(r"MS-\w+", n):
            v = NOMBRES.get(v, re.sub(r"[\s,]*(Co\.|Ltd\.?|Inc\.?|Corporation)", "", v).strip())
            n = re.sub(r"\s*\(MS-\w+\)$", "", n)   # «(MS-7E61)»: el código interno de MSI
            return f"{v} {n}".strip()
    return ""


def procesador():
    for linea in leer("/proc/cpuinfo").splitlines():
        if linea.startswith("model name"):
            nombre = linea.split(":", 1)[1].strip()
            return re.sub(r"\s+\d+-Core Processor$|\s+with .*$|\(R\)|\(TM\)", "", nombre).strip()
    return platform.processor()


def graficas():
    lista = []
    for linea in orden("lspci", "-mm").splitlines():
        campos = re.findall(r'"([^"]*)"', linea)
        if len(campos) >= 3 and re.search(r"VGA|3D|Display", campos[0]):
            fabricante, nombre = campos[1], campos[2]
            # «AD104 [GeForce RTX 4070 Ti]» → «GeForce RTX 4070 Ti»
            corchetes = re.search(r"\[([^\]]+)\]", nombre)
            nombre = corchetes.group(1) if corchetes else nombre
            fabricante = "NVIDIA" if "NVIDIA" in fabricante else "AMD" if "AMD" in fabricante \
                else "Intel" if "Intel" in fabricante else fabricante
            if not nombre.startswith(fabricante):
                nombre = f"{fabricante} {nombre}"
            lista.append(nombre)
    return lista


def memoria():
    for linea in leer("/proc/meminfo").splitlines():
        if linea.startswith("MemTotal:"):
            return round(int(linea.split()[1]) / 1024 / 1024, 1)   # GiB
    return 0


def disco():
    uso = shutil.disk_usage("/")
    return {"usado": round(uso.used / 1e9), "total": round(uso.total / 1e9)}


def yoru(buscar):
    if not os.path.isdir(os.path.join(REPO, ".git")):
        return None
    if buscar:
        orden("git", "fetch", "-q", cwd=REPO)
    ultimo = orden("git", "log", "-1", "--format=%h%x09%cs%x09%s", cwd=REPO).split("\t")
    nuevos = orden("git", "rev-list", "--count", "HEAD..@{u}", cwd=REPO)
    return {
        "repo": REPO.replace(CASA, "~"),
        "commit": ultimo[0] if ultimo else "",
        "fecha": ultimo[1] if len(ultimo) > 1 else "",
        "mensaje": ultimo[2] if len(ultimo) > 2 else "",
        "nuevos": int(nuevos) if nuevos.isdigit() else 0,
        "cambiosLocales": orden("git", "status", "--porcelain", cwd=REPO) != "",
        # La página del repositorio (https://github.com/...), si es de GitHub
        "web": re.sub(r"^git@github\.com:", "https://github.com/",
                      orden("git", "remote", "get-url", "origin", cwd=REPO)).removesuffix(".git"),
    }


def main():
    buscar = len(sys.argv) > 1 and sys.argv[1] == "buscar"
    niri = orden("niri", "--version").replace("niri ", "")
    print(json.dumps({
        "equipo": platform.node(),
        "modelo": modelo(),
        "sistema": sistema(),
        "kernel": platform.release(),
        "escritorio": f"Niri {niri.split()[0]}" if niri else "Niri",
        "procesador": procesador(),
        "graficas": graficas(),
        "memoria": memoria(),
        "disco": disco(),
        "yoru": yoru(buscar),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
