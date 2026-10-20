#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  actualizaciones.py — Cuántas actualizaciones hay (para comun/Actualizaciones.qml)
#
#    actualizaciones.py contar   JSON: {sistema, seguridad, apps, nombres}
#                                  sistema   paquetes de Fedora (dnf)
#                                  seguridad cuántos de ellos son de seguridad
#                                  apps      Flatpaks
#                                  nombres   unos cuantos, los conocidos primero
#
#  Solo mira, no instala nada (instalar: tienda.py actualizar, en una
#  terminal). dnf usa su caché de usuario, así que no pide contraseña.
# ----------------------------------------------------------------------------

import json
import re
import subprocess


def ejecutar(*orden):
    try:
        return subprocess.run(orden, capture_output=True, text=True, timeout=300).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def dnf_ocupado():
    """¿Está dnf en marcha (instalando, actualizando, install.sh...)? Entonces
    no se mira: dnf check-update se quedaría esperando y además le haría
    esperar a él («Waiting for a lock on the system repository»)."""
    return subprocess.run(["pgrep", "-x", "dnf|dnf5"], capture_output=True).returncode == 0


def contar():
    # «nombre.arquitectura  versión  repositorio» (sin la sección de obsoletos)
    paquetes = []
    for linea in ejecutar("dnf", "check-update", "--refresh", "-q").splitlines():
        if linea.startswith("Obsolet"):
            break
        m = re.match(r"^(\S+)\.(x86_64|noarch|i686|aarch64)\s+\S+\s+\S+", linea)
        if m:
            paquetes.append(m.group(1))
    seguridad = set()
    for linea in ejecutar("dnf", "updateinfo", "list", "--security", "-q").splitlines():
        partes = linea.split()
        if len(partes) >= 4 and partes[1] == "security":
            seguridad.add(partes[3])
    apps = [l.split("\t")[0] for l in ejecutar("flatpak", "remote-ls", "--updates",
                                                 "--columns=name").splitlines() if l.strip()]
    # Para enseñar: primero las apps y los paquetes sin pinta de librería
    conocidos = [p for p in paquetes if not re.search(r"^(lib|python3-|perl-|golang-|texlive-)|-(libs|devel|common|data)$", p)]
    # (y sin los «runtimes» de Flatpak, que nadie reconoce)
    apps_vistas = [a for a in apps if not re.search(r"Platform|Runtime|Codecs|Locale|GL\b|Mesa", a)]
    return {"sistema": len(paquetes), "seguridad": len(seguridad), "apps": len(apps),
            "nombres": (apps_vistas + conocidos)[:8]}


if __name__ == "__main__":
    # Sin salida: la barra se queda con la cuenta de antes y mira otra vez luego
    if not dnf_ocupado():
        print(json.dumps(contar(), ensure_ascii=False))
