#!/usr/bin/env python3
"""
tienda.py — Lo que hay detrás del panel Tienda (paneles/Tienda.qml)

  tienda.py instaladas               → JSON: Flatpaks + RPM con icono en el lanzador
  tienda.py buscar <texto>           → una línea JSON por origen, según van llegando:
                                       {"origen": "flatpak", "apps": [...]}, luego "rpm"
  tienda.py instalar <tipo> <id> <remoto> <nombre>
  tienda.py desinstalar <tipo> <id> <nombre>
  tienda.py abrir <tipo> <id> <nombre>
  tienda.py actualizar               → dnf + flatpak en una terminal flotante

Cada app: {tipo: "flatpak"|"rpm", id, nombre, desc, icono, remoto, instalada}
«icono» es una ruta (icono de Flathub) o un nombre del tema de iconos.

Instalar y desinstalar: la contraseña la pide la ventana de administrador
(mate-polkit) y el resultado llega como notificación. El proceso aguanta
aunque se recargue Quickshell a medias.
"""

import glob
import json
import os
import re
import signal
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

# Paquetes de dnf que no son apps: librerías, cabeceras, módulos de lenguajes...
PREFIJOS_RUIDO = ("lib", "python3-", "perl-", "golang-", "rust-", "ghc-", "texlive-",
                  "nodejs-", "php-", "R-", "ocaml-", "mingw", "js-", "java-", "maven-")
SUFIJOS_RUIDO = ("-devel", "-libs", "-doc", "-docs", "-debuginfo", "-debugsource",
                 "-static", "-tests", "-data", "-common", "-langpacks")
RUIDO = re.compile(r"-(help|l10n|i18n|langpack|locale)(-|$)")
MAX_FEDORA = 40
IDIOMA = os.environ.get("LANG", "").split(".")[0]  # es_ES

DIRS_FLATPAK = ["/var/lib/flatpak/exports/share/applications",
                os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]
ICONOS_FLATHUB = ["/var/lib/flatpak/appstream/{}/x86_64/active/icons/128x128/{}.png",
                  "/var/lib/flatpak/appstream/{}/x86_64/active/icons/64x64/{}.png"]


def ejecutar(cmd, timeout=30):
    # stdin vacío: si dnf pregunta algo (p. ej. importar la llave de un repo),
    # que no se quede esperando una respuesta que nunca llega
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                           stdin=subprocess.DEVNULL)
        return r.returncode, r.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""


def avisar(texto, error=False, detalle=""):
    cmd = ["notify-send", "-a", "Tienda", "-i", "system-software-install"]
    if error:
        cmd += ["-u", "critical"]
    ejecutar(cmd + ["Tienda", texto + (f"\n{detalle}" if detalle else "")], timeout=5)


# ------------------------------------------------------------- Lectura
def leer_desktop(ruta):
    """Claves de la sección [Desktop Entry] de un .desktop."""
    datos = {}
    try:
        with open(ruta, encoding="utf-8", errors="replace") as f:
            seccion = None
            for linea in f:
                linea = linea.strip()
                if linea.startswith("["):
                    seccion = linea
                elif seccion == "[Desktop Entry]" and "=" in linea:
                    clave, valor = linea.split("=", 1)
                    datos.setdefault(clave, valor)
    except OSError:
        pass
    return datos


def traducido(datos, clave, defecto=""):
    idioma = IDIOMA.split("_")[0]
    return datos.get(f"{clave}[{IDIOMA}]") or datos.get(f"{clave}[{idioma}]") or datos.get(clave, defecto)


def icono_flathub(ident, remoto="flathub"):
    for patron in ICONOS_FLATHUB:
        ruta = patron.format(remoto, ident)
        if os.path.exists(ruta):
            return ruta
    return ""


def flatpaks_instalados():
    _, salida = ejecutar(["flatpak", "list", "--app", "--columns=application,name,description"])
    apps = {}
    for linea in salida.splitlines():
        partes = linea.split("\t")
        if len(partes) >= 2:
            apps[partes[0]] = partes
    return apps


def rpms_instalados():
    _, salida = ejecutar(["rpm", "-qa", "--qf", "%{NAME}\n"])
    return set(salida.splitlines())


def apps_instaladas():
    lista = []
    for ident, partes in flatpaks_instalados().items():
        datos = {}
        for d in DIRS_FLATPAK:
            if os.path.exists(f"{d}/{ident}.desktop"):
                datos = leer_desktop(f"{d}/{ident}.desktop")
                break
        lista.append({"tipo": "flatpak", "id": ident, "nombre": partes[1],
                      "desc": traducido(datos, "Comment", partes[2] if len(partes) > 2 else ""),
                      "icono": datos.get("Icon") or icono_flathub(ident), "instalada": True})

    rutas = []
    for r in sorted(glob.glob("/usr/share/applications/*.desktop")):
        datos = leer_desktop(r)
        if datos.get("NoDisplay") != "true" and datos.get("Type", "Application") == "Application":
            rutas.append((r, datos))
    if rutas:
        _, salida = ejecutar(["rpm", "-qf", "--qf", "%{NAME}\n"] + [r for r, _ in rutas])
        vistos = set()
        for (ruta, datos), paquete in zip(rutas, salida.splitlines()):
            if " " in paquete or paquete in vistos:  # "no pertenece a ningún paquete"
                continue
            vistos.add(paquete)
            lista.append({"tipo": "rpm", "id": paquete, "nombre": traducido(datos, "Name", paquete),
                          "desc": traducido(datos, "Comment"), "icono": datos.get("Icon", ""),
                          "instalada": True})

    return sorted(lista, key=lambda a: a["nombre"].lower())


def ordenar(apps, texto):
    """Primero lo que se llama igual que lo buscado, luego lo que lo contiene."""
    t = texto.lower()

    def nota(a):
        nombres = (a["nombre"].lower(), a["id"].lower().rsplit(".", 1)[-1])
        return 0 if t in nombres else 1 if any(t in n for n in nombres) else 2
    return sorted(apps, key=nota)


def buscar_flatpak(texto):
    instalados = flatpaks_instalados()
    _, salida = ejecutar(["flatpak", "search", "--columns=application,name,description,remotes",
                          texto], timeout=30)
    vistos = {}
    for linea in salida.splitlines():
        partes = linea.split("\t")
        if len(partes) < 4:
            continue
        ident, nombre, desc, remotos = partes[:4]
        remotos = remotos.split(",")
        # Si la misma app está en varios remotos, manda Flathub
        clave = ident.lower()
        if clave in vistos and "flathub" not in remotos:
            continue
        remoto = "flathub" if "flathub" in remotos else remotos[0]
        vistos[clave] = {"tipo": "flatpak", "id": ident, "nombre": nombre, "desc": desc,
                         "remoto": remoto, "icono": icono_flathub(ident, remoto),
                         "instalada": ident in instalados}
    return ordenar(list(vistos.values()), texto)


def es_ruido(nombre):
    return (nombre.startswith(PREFIJOS_RUIDO) or nombre.endswith(SUFIJOS_RUIDO)
            or RUIDO.search(nombre) is not None)


def buscar_dnf(texto):
    instalados = rpms_instalados()
    # dnf search: las líneas de resultados empiezan por espacio → " nombre.arch\tresumen"
    _, salida = ejecutar(["dnf", "-q", "search", texto], timeout=60)
    vistos = {}
    for linea in salida.splitlines():
        if not linea.startswith(" ") or "\t" not in linea:
            continue
        paquete, desc = linea.strip().split("\t", 1)
        nombre, _, arch = paquete.rpartition(".")
        if arch == "i686" or es_ruido(nombre) or nombre in vistos:
            continue
        vistos[nombre] = {"tipo": "rpm", "id": nombre, "nombre": nombre, "desc": desc.strip(),
                          "icono": nombre, "instalada": nombre in instalados}
    return ordenar(list(vistos.values()), texto)[:MAX_FEDORA]


# ------------------------------------------------------------- Acciones
def trabajar(cmd, hecho, fallo):
    # Si Quickshell se recarga mientras tanto, esto sigue hasta el final
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        avisar(fallo, error=True, detalle=str(e))
        return 1
    if r.returncode == 0:
        avisar(hecho)
    else:
        ultimas = "\n".join((r.stderr or r.stdout).strip().splitlines()[-3:])
        avisar(fallo, error=True, detalle=ultimas)
    return r.returncode


def instalar(tipo, ident, remoto, nombre):
    if tipo == "flatpak":
        cmd = ["flatpak", "install", "-y", "--noninteractive", remoto or "flathub", ident]
    else:
        cmd = ["pkexec", "dnf", "install", "-y", ident]
    return trabajar(cmd, f"{nombre} instalado. Ya está en el lanzador (Mod+Espacio).",
                    f"No se pudo instalar {nombre}")


def desinstalar(tipo, ident, nombre):
    if tipo == "flatpak":
        cmd = ["flatpak", "uninstall", "-y", "--noninteractive", ident]
    else:
        cmd = ["pkexec", "dnf", "remove", "-y", ident]
    return trabajar(cmd, f"{nombre} desinstalado.", f"No se pudo desinstalar {nombre}")


def desktop_de(tipo, ident):
    """Ruta del .desktop de una app instalada (para abrirla con gio)."""
    if tipo == "flatpak":
        for d in DIRS_FLATPAK:
            if os.path.exists(f"{d}/{ident}.desktop"):
                return f"{d}/{ident}.desktop"
        return None
    _, salida = ejecutar(["rpm", "-ql", ident])
    for ruta in salida.splitlines():
        if ruta.startswith("/usr/share/applications/") and ruta.endswith(".desktop") \
                and leer_desktop(ruta).get("NoDisplay") != "true":
            return ruta
    return None


def abrir(tipo, ident, nombre):
    ruta = desktop_de(tipo, ident)
    if ruta:
        subprocess.Popen(["setsid", "-f", "gio", "launch", ruta])
    elif tipo == "flatpak":
        subprocess.Popen(["setsid", "-f", "flatpak", "run", ident])
    else:
        avisar(f"{nombre} no tiene icono en el lanzador (se usa desde la terminal)")


def actualizar():
    """Las actualizaciones pueden ser muchas: mejor verlas en una terminal."""
    guion = (
        'echo -e "\\033[1m==> Sistema (dnf)\\033[0m"; sudo dnf upgrade --refresh; '
        'echo -e "\\n\\033[1m==> Apps (Flatpak)\\033[0m"; flatpak update; '
        'echo; read -rsn1 -p "Listo. Pulsa una tecla para cerrar…"'
    )
    subprocess.Popen(["setsid", "-f", "kitty", "--class", "tienda", "--title", "Actualizaciones",
                      "bash", "-c", guion])


def main():
    orden, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    if orden == "instaladas":
        print(json.dumps(apps_instaladas(), ensure_ascii=False))
    elif orden == "buscar" and args:
        texto = " ".join(args)
        with ThreadPoolExecutor() as hilos:
            trabajos = {hilos.submit(buscar_flatpak, texto): "flatpak",
                        hilos.submit(buscar_dnf, texto): "rpm"}
            # Flathub suele contestar antes que dnf: cada origen sale en cuanto llega
            for f in as_completed(trabajos):
                print(json.dumps({"origen": trabajos[f], "apps": f.result()}, ensure_ascii=False),
                      flush=True)
    elif orden == "instalar" and len(args) == 4:
        sys.exit(instalar(*args))
    elif orden == "desinstalar" and len(args) == 3:
        sys.exit(desinstalar(*args))
    elif orden == "abrir" and len(args) == 3:
        abrir(*args)
    elif orden == "actualizar":
        actualizar()
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
