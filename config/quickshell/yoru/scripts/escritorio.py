#!/usr/bin/env python3
# ============================================================================
#  escritorio.py — lo que hay en la carpeta del escritorio (~/Escritorio),
#  para los iconos de barra/IconosEscritorio.qml
#
#  Se queda vigilando la carpeta: escribe una línea JSON al empezar y otra
#  cada vez que algo cambia (crear, borrar, renombrar, copiar...):
#
#    {"carpeta": "/home/tú/Escritorio",
#     "cosas": [{"nombre": "fotos", "ruta": "...", "titulo": "fotos",
#                "tipo": "carpeta" | "archivo" | "acceso",
#                "icono": "folder", "imagen": "/ruta/a/la/miniatura.png"}]}
#
#  «acceso» son los accesos directos: un .desktop (su nombre y su icono) o
#  un enlace simbólico. «icono» es un nombre del tema de iconos (o una ruta);
#  «imagen», la miniatura si la hay (fotos: la propia foto; vídeos y PDF: la
#  que ya generó Archivos en ~/.cache/thumbnails).
#
#  Con python3-gobject vigila con Gio (al instante); sin él, mira cada
#  segundo si la carpeta ha cambiado.
# ============================================================================
import configparser
import hashlib
import json
import mimetypes
import os
import subprocess
import sys
import time
import urllib.parse

try:
    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib
except (ImportError, ValueError):
    Gio = GLib = None

IMAGENES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg", ".avif"}


def carpeta_escritorio():
    try:
        r = subprocess.run(["xdg-user-dir", "DESKTOP"], capture_output=True, text=True, timeout=3)
        c = r.stdout.strip()
        if c and c != os.path.expanduser("~"):
            return c
    except (OSError, subprocess.TimeoutExpired):
        pass
    return os.path.expanduser("~/Escritorio")


def miniatura(ruta):
    """La miniatura que ya hizo Archivos (estándar de freedesktop), si existe."""
    uri = "file://" + urllib.parse.quote(os.path.abspath(ruta))
    nombre = hashlib.md5(uri.encode()).hexdigest() + ".png"
    cache = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
    for tam in ("large", "normal", "x-large"):
        m = os.path.join(cache, "thumbnails", tam, nombre)
        if os.path.exists(m):
            return m
    return ""


def icono_de(ruta, es_carpeta):
    if es_carpeta:
        return "folder"
    if Gio:
        tipo, _ = Gio.content_type_guess(ruta, None)
        icono = Gio.content_type_get_icon(tipo)
        nombres = icono.get_names() if hasattr(icono, "get_names") else []
        if nombres:
            # Los nombres van del más concreto al más genérico: que el QML elija
            return ",".join(nombres)
    tipo, _ = mimetypes.guess_type(ruta)
    if tipo:
        return tipo.replace("/", "-") + "," + tipo.split("/")[0] + "-x-generic,text-x-generic"
    return "text-x-generic"


def leer_desktop(ruta):
    p = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        p.read(ruta, encoding="utf-8")
        e = p["Desktop Entry"]
    except (configparser.Error, KeyError, UnicodeDecodeError):
        return None
    idioma = (os.environ.get("LANG") or "es").split(".")[0]
    nombre = e.get(f"Name[{idioma}]") or e.get(f"Name[{idioma.split('_')[0]}]") or e.get("Name")
    return nombre, e.get("Icon", "application-x-executable")


def listar(carpeta):
    cosas = []
    try:
        entradas = sorted(os.scandir(carpeta), key=lambda e: e.name.lower())
    except OSError:
        entradas = []
    for e in entradas:
        if e.name.startswith("."):
            continue
        ruta = e.path
        enlace = e.is_symlink()
        try:
            es_carpeta = e.is_dir()
        except OSError:
            es_carpeta = False
        cosa = {"nombre": e.name, "ruta": ruta, "titulo": e.name,
                "tipo": "carpeta" if es_carpeta else "archivo",
                "icono": icono_de(ruta, es_carpeta), "imagen": ""}
        if e.name.endswith(".desktop") and not es_carpeta:
            d = leer_desktop(ruta)
            if d:
                cosa["titulo"], cosa["icono"] = d[0] or e.name[:-8], d[1]
                cosa["tipo"] = "acceso"
        elif enlace:
            cosa["tipo"] = "acceso"
        if not es_carpeta and cosa["tipo"] != "acceso" or enlace and not es_carpeta:
            ext = os.path.splitext(e.name)[1].lower()
            cosa["imagen"] = ruta if ext in IMAGENES else miniatura(os.path.realpath(ruta))
        cosas.append(cosa)
    return cosas


def emitir(carpeta):
    print(json.dumps({"carpeta": carpeta, "cosas": listar(carpeta)}, ensure_ascii=False), flush=True)


def main():
    carpeta = carpeta_escritorio()
    os.makedirs(carpeta, exist_ok=True)
    emitir(carpeta)

    if Gio:
        bucle = GLib.MainLoop()
        pendiente = {"id": 0}

        def tarde():
            pendiente["id"] = 0
            emitir(carpeta)
            return False

        # Muchos cambios seguidos (copiar 50 fotos): una sola lista al final
        def cambio(*_):
            if pendiente["id"]:
                GLib.source_remove(pendiente["id"])
            pendiente["id"] = GLib.timeout_add(150, tarde)

        monitor = Gio.File.new_for_path(carpeta).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
        monitor.connect("changed", cambio)
        # Las miniaturas que Archivos genere después también cuentan
        cache = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
        os.makedirs(os.path.join(cache, "thumbnails", "large"), exist_ok=True)
        monitor_mini = Gio.File.new_for_path(os.path.join(cache, "thumbnails", "large")).monitor_directory(
            Gio.FileMonitorFlags.NONE, None)
        monitor_mini.connect("changed", cambio)
        bucle.run()
    else:
        antes = None
        while True:
            try:
                ahora = (os.stat(carpeta).st_mtime_ns, len(os.listdir(carpeta)))
            except OSError:
                ahora = None
            if antes is not None and ahora != antes:
                emitir(carpeta)
            antes = ahora
            time.sleep(1)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
