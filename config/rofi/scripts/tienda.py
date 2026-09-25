#!/usr/bin/env python3
"""
tienda.py — Tienda de apps con rofi (Flatpak + dnf), sin GNOME ni KDE

  · Buscar apps en Flathub y en los repositorios de Fedora a la vez
  · Instalar, desinstalar y abrir. Lo ya instalado sale marcado
  · Ver tus apps instaladas (Flatpak y RPM con icono en el lanzador)
  · Actualizar todo (dnf + flatpak) en una terminal flotante

Atajo: Mod+Alt+S

Instalar y desinstalar se hace en segundo plano: la contraseña la pide la
ventana de administrador (mate-polkit) y el resultado llega como notificación.
Las apps nuevas aparecen solas en el lanzador (Mod+Espacio).
"""

import glob
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from rofimenu import ejecutar, menu, pedir_texto, avisar, escapar  # noqa: E402

BUSCAR = "\U000f0349"
INSTALAR = "\U000f01da"
BORRAR = "\U000f01b4"
ACTUALIZAR = "\U000f06b0"
ABRIR = "\U000f03cc"
APPS = "\U000f003b"
FLATPAK = "\U000f03d6"
FEDORA = ""
VOLVER = "\U000f004d"

TENUE = "#8a8f98"  # texto-tenue de tema.rasi
# La tienda no sale de la barra (es un atajo, Mod+Alt+S): va centrada
TEMA_TIENDA = "columna { width: 720px; }"

# Paquetes de dnf que no son apps: librerías, cabeceras, módulos de lenguajes...
PREFIJOS_RUIDO = ("lib", "python3-", "perl-", "golang-", "rust-", "ghc-", "texlive-",
                  "nodejs-", "php-", "R-", "ocaml-", "mingw", "js-", "java-", "maven-")
SUFIJOS_RUIDO = ("-devel", "-libs", "-doc", "-docs", "-debuginfo", "-debugsource",
                 "-static", "-tests", "-data", "-common", "-langpacks")
RUIDO = re.compile(r"-(help|l10n|i18n|langpack|locale)(-|$)")
MAX_FEDORA = 40
IDIOMA = os.environ.get("LANG", "").split(".")[0]  # es_ES

DIRS_DESKTOP = ["/usr/share/applications", "/var/lib/flatpak/exports/share/applications",
                os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]


# ------------------------------------------------------------- Lectura
def flatpaks_instalados():
    _, salida = ejecutar(["flatpak", "list", "--app", "--columns=application,name"])
    apps = {}
    for linea in salida.splitlines():
        partes = linea.split("\t")
        if len(partes) >= 2:
            apps[partes[0]] = partes[1]
    return apps


def rpms_instalados():
    _, salida = ejecutar(["rpm", "-qa", "--qf", "%{NAME}\n"])
    return set(salida.splitlines())


def buscar_flatpak(texto):
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
        vistos[clave] = {
            "tipo": "flatpak", "id": ident, "nombre": nombre, "desc": desc,
            "remoto": "flathub" if "flathub" in remotos else remotos[0],
        }
    return ordenar(list(vistos.values()), texto)


def ordenar(apps, texto):
    """Primero lo que se llama igual que lo buscado, luego lo que lo contiene."""
    t = texto.lower()

    def nota(a):
        nombres = (a["nombre"].lower(), a["id"].lower().rsplit(".", 1)[-1])
        return 0 if t in nombres else 1 if any(t in n for n in nombres) else 2
    return sorted(apps, key=nota)


def es_ruido(nombre):
    return (nombre.startswith(PREFIJOS_RUIDO) or nombre.endswith(SUFIJOS_RUIDO)
            or RUIDO.search(nombre) is not None)


def buscar_dnf(texto):
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
        vistos[nombre] = {"tipo": "rpm", "id": nombre, "nombre": nombre, "desc": desc.strip()}
    return ordenar(list(vistos.values()), texto)[:MAX_FEDORA]


def leer_desktop(ruta):
    """Name= y NoDisplay de un .desktop (solo la sección [Desktop Entry])."""
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


def nombre_traducido(datos, defecto):
    idioma = IDIOMA.split("_")[0]
    return datos.get(f"Name[{IDIOMA}]") or datos.get(f"Name[{idioma}]") or datos.get("Name", defecto)


def desktop_de(app):
    """Ruta del .desktop de una app instalada (para abrirla con gio)."""
    if app["tipo"] == "flatpak":
        for d in DIRS_DESKTOP[1:]:
            ruta = os.path.join(d, app["id"] + ".desktop")
            if os.path.exists(ruta):
                return ruta
        return None
    _, salida = ejecutar(["rpm", "-ql", app["id"]])
    for ruta in salida.splitlines():
        if ruta.startswith("/usr/share/applications/") and ruta.endswith(".desktop") \
                and leer_desktop(ruta).get("NoDisplay") != "true":
            return ruta
    return None


def apps_instaladas():
    """Flatpaks + paquetes RPM que ponen un icono en el lanzador."""
    lista = [{"tipo": "flatpak", "id": i, "nombre": n, "desc": i}
             for i, n in flatpaks_instalados().items()]

    rutas = [r for r in glob.glob("/usr/share/applications/*.desktop")
             if leer_desktop(r).get("NoDisplay") != "true"]
    if rutas:
        _, salida = ejecutar(["rpm", "-qf", "--qf", "%{NAME}\n"] + rutas)
        paquetes = {}
        for ruta, paquete in zip(rutas, salida.splitlines()):
            if " " in paquete:  # "no pertenece a ningún paquete"
                continue
            nombre = nombre_traducido(leer_desktop(ruta), paquete)
            paquetes.setdefault(paquete, nombre)
        lista += [{"tipo": "rpm", "id": p, "nombre": n, "desc": p} for p, n in paquetes.items()]

    return sorted(lista, key=lambda a: a["nombre"].lower())


# ------------------------------------------------------------- Acciones
# Shell desacoplado: el trabajo sigue aunque el menú se cierre. Si falla,
# la notificación incluye las últimas líneas del error.
SEGUNDO_PLANO = """
hecho=$1 fallo=$2; shift 2
if salida=$("$@" 2>&1); then
    notify-send -a Tienda -i system-software-install Tienda "$hecho"
else
    notify-send -a Tienda -c error Tienda "$fallo
$(printf '%s' "$salida" | tail -n 3)"
fi
"""


def en_segundo_plano(cmd, hecho, fallo):
    subprocess.Popen(["setsid", "-f", "sh", "-c", SEGUNDO_PLANO, "tienda", hecho, fallo] + cmd,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def instalar(app):
    nombre = app["nombre"]
    if app["tipo"] == "flatpak":
        cmd = ["flatpak", "install", "-y", "--noninteractive", app["remoto"], app["id"]]
    else:
        cmd = ["pkexec", "dnf", "install", "-y", app["id"]]
    avisar("Tienda", f"Instalando {nombre}…", icono="system-software-install")
    en_segundo_plano(cmd, f"{nombre} instalado. Ya está en el lanzador (Mod+Espacio).",
                     f"No se pudo instalar {nombre}")


def desinstalar(app):
    nombre = app["nombre"]
    if app["tipo"] == "flatpak":
        cmd = ["flatpak", "uninstall", "-y", "--noninteractive", app["id"]]
    else:
        cmd = ["pkexec", "dnf", "remove", "-y", app["id"]]
    avisar("Tienda", f"Desinstalando {nombre}…")
    en_segundo_plano(cmd, f"{nombre} desinstalado.", f"No se pudo desinstalar {nombre}")


def abrir(app):
    ruta = desktop_de(app)
    if ruta:
        ejecutar(["setsid", "-f", "gio", "launch", ruta])
    elif app["tipo"] == "flatpak":
        ejecutar(["setsid", "-f", "flatpak", "run", app["id"]])
    else:
        avisar("Tienda", f"{app['nombre']} no tiene icono en el lanzador (se usa desde la terminal)")


def actualizar_todo():
    """Las actualizaciones pueden ser muchas: mejor verlas en una terminal."""
    guion = (
        'echo -e "\\033[1m==> Sistema (dnf)\\033[0m"; sudo dnf upgrade --refresh; '
        'echo -e "\\n\\033[1m==> Apps (Flatpak)\\033[0m"; flatpak update; '
        'echo; read -rsn1 -p "Listo. Pulsa una tecla para cerrar…"'
    )
    ejecutar(["setsid", "-f", "kitty", "--class", "tienda", "--title", "Actualizaciones",
              "bash", "-c", guion])


# ------------------------------------------------------------- Menús
def fila(app, instalada):
    icono = FLATPAK if app["tipo"] == "flatpak" else FEDORA
    marca = "  ✓" if instalada else ""
    desc = f"  <span foreground='{TENUE}'>{escapar(app['desc'])}</span>" if app["desc"] else ""
    return f"{icono}  <b>{escapar(app['nombre'])}</b>{marca}{desc}"


def esta_instalada(app, flatpaks, rpms):
    if app["tipo"] == "flatpak":
        return app["id"] in flatpaks
    return app["id"] in rpms


def menu_app(app, instalada):
    """Ficha de una app: qué es, de dónde viene y qué hacer con ella."""
    origen = (f"Flatpak · {app.get('remoto', 'instalado')}" if app["tipo"] == "flatpak"
              else "Fedora (dnf)")
    mensaje = (f"<b>{escapar(app['nombre'])}</b>\n{escapar(app['desc'])}\n"
               f"<span foreground='{TENUE}'>{origen} · {escapar(app['id'])}</span>")
    if instalada:
        opciones = [f"{ABRIR}  Abrir", f"{BORRAR}  Desinstalar", f"{VOLVER}  Volver"]
        acciones = [abrir, desinstalar, None]
    else:
        opciones = [f"{INSTALAR}  Instalar", f"{VOLVER}  Volver"]
        acciones = [instalar, None]
    i = menu(app["nombre"], opciones, mensaje=mensaje, urgentes=[1] if instalada else [],
             tema=TEMA_TIENDA)
    if i is None:
        return "salir"
    if acciones[i] is None:
        return "volver"
    if acciones[i] is desinstalar:
        seguro = menu("¿Seguro?", [f"{BORRAR}  Sí, desinstalar {escapar(app['nombre'])}",
                                   f"{VOLVER}  No"], urgentes=[0], fila=1, tema=TEMA_TIENDA)
        if seguro != 0:
            return "volver"
    acciones[i](app)
    return "salir"


def lista_apps(titulo, apps, mensaje, flatpaks, rpms):
    """Lista con búsqueda; devuelve 'salir' o 'volver'."""
    while True:
        instaladas = [esta_instalada(a, flatpaks, rpms) for a in apps]
        opciones = [f"{VOLVER}  Volver"] + [fila(a, ok) for a, ok in zip(apps, instaladas)]
        activos = [k + 1 for k, ok in enumerate(instaladas) if ok]
        i = menu(titulo, opciones, mensaje=mensaje, activos=activos, tema=TEMA_TIENDA,
                 buscar=True, fila=1 if apps else 0, max_lineas=12)
        if i is None:
            return "salir"
        if i == 0:
            return "volver"
        if menu_app(apps[i - 1], instaladas[i - 1]) == "salir":
            return "salir"


def buscar():
    texto = pedir_texto(BUSCAR, mensaje="¿Qué app buscas? (nombre o lo que hace: «editor de fotos»…)",
                        posicion="")
    if not texto or not texto.strip():
        return "volver"
    texto = texto.strip()
    avisar("Tienda", f"Buscando «{texto}»…")
    with ThreadPoolExecutor() as hilos:
        f_flatpak = hilos.submit(buscar_flatpak, texto)
        f_dnf = hilos.submit(buscar_dnf, texto)
        f_fp_inst = hilos.submit(flatpaks_instalados)
        f_rpm_inst = hilos.submit(rpms_instalados)
    apps = f_flatpak.result() + f_dnf.result()
    if not apps:
        avisar("Tienda", f"Nada para «{texto}»")
        return "volver"
    mensaje = (f"{len(apps)} resultados para <b>{escapar(texto)}</b> · "
               f"{FLATPAK} Flatpak  {FEDORA} Fedora · escribe para filtrar")
    return lista_apps("Resultados", apps, mensaje, f_fp_inst.result(), f_rpm_inst.result())


def instaladas():
    apps = apps_instaladas()
    flatpaks = {a["id"] for a in apps if a["tipo"] == "flatpak"}
    rpms = {a["id"] for a in apps if a["tipo"] == "rpm"}
    mensaje = f"{len(apps)} apps · {FLATPAK} Flatpak  {FEDORA} Fedora · escribe para filtrar"
    return lista_apps("Instaladas", apps, mensaje, flatpaks, rpms)


def main():
    while True:
        opciones = [
            f"{BUSCAR}  Buscar apps",
            f"{APPS}  Instaladas",
            f"{ACTUALIZAR}  Actualizar todo",
        ]
        i = menu("Tienda", opciones, mensaje="Apps de <b>Flathub</b> y de <b>Fedora</b>",
                 tema=TEMA_TIENDA)
        if i is None:
            return
        if i == 2:
            actualizar_todo()
            return
        if (buscar if i == 0 else instaladas)() == "salir":
            return


if __name__ == "__main__":
    main()
