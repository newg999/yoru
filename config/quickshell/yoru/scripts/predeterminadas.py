#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  predeterminadas.py — Con qué app se abre cada cosa (Ajustes › Apps)
#
#    predeterminadas.py leer                   JSON: las categorías, con la app de
#                                              cada una y las que la pueden abrir
#    predeterminadas.py poner <categoría> <app.desktop>
#    predeterminadas.py tipo <.ext | mime>     JSON: un tipo de archivo suelto
#    predeterminadas.py poner-tipo <mime> <app.desktop>
#
#  Usa Gio (lo mismo que Nautilus) y guarda en ~/.config/mimeapps.list, que
#  también lee xdg-open (yazi, la terminal, los enlaces...). Cada categoría
#  pone la app en todos sus tipos, con los nombres viejos incluidos
#  (audio/x-flac y audio/flac): xdg-open no los relaciona y abría otra app.
# ----------------------------------------------------------------------------

import json
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio  # noqa: E402

try:   # GLib 2.86+: DesktopAppInfo pasó a GioUnix
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix  # noqa: E402
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ValueError, ImportError):
    DesktopAppInfo = Gio.DesktopAppInfo

OFFICE = "application/vnd.openxmlformats-officedocument."
CATEGORIAS = [
    ("web", "Navegador", "󰖟", ["x-scheme-handler/https", "x-scheme-handler/http", "text/html",
                               "application/xhtml+xml"]),
    ("correo", "Correo", "󰇮", ["x-scheme-handler/mailto"]),
    ("archivos", "Carpetas", "󰉋", ["inode/directory"]),
    ("musica", "Música", "󰝚", ["audio/mpeg", "audio/flac", "audio/x-flac", "audio/ogg", "audio/x-vorbis+ogg",
                               "audio/opus", "audio/x-opus+ogg", "audio/wav", "audio/x-wav", "audio/aac",
                               "audio/mp4", "audio/x-m4a", "audio/webm", "audio/x-ms-wma", "audio/x-aiff"]),
    ("video", "Vídeo", "󰕧", ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo",
                             "video/avi", "video/mpeg", "video/ogg", "video/x-flv", "video/3gpp", "video/x-ms-wmv"]),
    ("imagenes", "Imágenes", "󰋩", ["image/jpeg", "image/png", "image/gif", "image/webp", "image/avif", "image/bmp",
                                   "image/svg+xml", "image/tiff", "image/heif", "image/heic", "image/jxl"]),
    ("pdf", "PDF", "󰈦", ["application/pdf"]),
    ("texto", "Texto", "󰈙", ["text/plain", "text/markdown", "text/x-log"]),
    ("documentos", "Documentos", "󰈬", [OFFICE + "wordprocessingml.document", "application/msword",
                                       "application/vnd.oasis.opendocument.text", "application/rtf"]),
    ("hojas", "Hojas de cálculo", "󰈛", [OFFICE + "spreadsheetml.sheet", "application/vnd.ms-excel",
                                        "application/vnd.oasis.opendocument.spreadsheet", "text/csv"]),
    ("presentaciones", "Presentaciones", "󰈧", [OFFICE + "presentationml.presentation",
                                               "application/vnd.ms-powerpoint",
                                               "application/vnd.oasis.opendocument.presentation"]),
    ("comprimidos", "Comprimidos", "󰗄", ["application/zip", "application/x-7z-compressed", "application/x-tar",
                                         "application/x-compressed-tar", "application/x-xz-compressed-tar",
                                         "application/gzip", "application/vnd.rar", "application/x-rar",
                                         "application/zstd"]),
]


def info(app):
    icono = app.get_icon()
    nombre = app.get_display_name()
    # La misma app instalada dos veces (del sistema y Flatpak): que se distingan
    if "flatpak" in (getattr(app, "get_filename", lambda: "")() or ""):
        nombre += " (Flatpak)"
    return {"id": app.get_id(), "nombre": nombre, "icono": icono.to_string() if icono else ""}


def por_defecto(mime):
    app = Gio.AppInfo.get_default_for_type(mime, False)
    return app.get_id() if app else ""


def candidatas(mimes):
    """Las apps que abren el tipo principal (el primero), las que abren más
    tipos de la categoría primero. Así en «Navegador» no salen los editores
    de texto (que también abren .html)."""
    principales = {a.get_id() for a in Gio.AppInfo.get_all_for_type(mimes[0])}
    cuenta, apps = {}, {}
    for m in mimes:
        for app in Gio.AppInfo.get_all_for_type(m):
            # Sin las ocultas (lanzadores internos, restos de otras apps)
            if not app.get_id() or not app.should_show() or app.get_id() not in principales:
                continue
            apps[app.get_id()] = app
            cuenta[app.get_id()] = cuenta.get(app.get_id(), 0) + 1
    orden = sorted(apps, key=lambda i: (-cuenta[i], apps[i].get_display_name().lower()))
    return [dict(info(apps[i]), tipos=cuenta[i]) for i in orden]


def describir(mimes):
    actuales = [por_defecto(m) for m in mimes]
    usadas = [a for a in actuales if a]
    # La que más se repite (normalmente la del primer tipo)
    actual = max(set(usadas), key=lambda a: (usadas.count(a), a == actuales[0])) if usadas else ""
    lista = candidatas(mimes)
    if actual and actual not in [a["id"] for a in lista]:
        app = DesktopAppInfo.new(actual)
        if app:
            lista.insert(0, dict(info(app), tipos=0))
    return {"actual": actual, "mezcla": len(set(usadas)) > 1, "apps": lista}


def leer():
    print(json.dumps([dict(describir(mimes), id=c, nombre=n, icono=i)
                      for c, n, i, mimes in CATEGORIAS], ensure_ascii=False))


def poner_en(app_id, mimes):
    app = DesktopAppInfo.new(app_id)
    if not app:
        sys.exit("No encuentro la app %s" % app_id)
    for m in mimes:
        app.set_as_default_for_type(m)


def poner(categoria, app_id):
    for c, _, _, mimes in CATEGORIAS:
        if c == categoria:
            return poner_en(app_id, mimes)
    sys.exit("Categoría desconocida: %s" % categoria)


def mime_de(texto):
    texto = texto.strip()
    if "/" in texto:
        return texto
    nombre = texto if texto.startswith(".") else "." + texto
    mime, _ = Gio.content_type_guess("archivo" + nombre, None)
    return Gio.content_type_get_mime_type(mime) or mime


def tipo(texto):
    mime = mime_de(texto)
    if not mime or mime == "application/octet-stream" and not texto.strip().endswith("octet-stream"):
        sys.exit("No conozco ese tipo de archivo")
    d = describir([mime])
    d.update(mime=mime, descripcion=Gio.content_type_get_description(mime))
    print(json.dumps(d, ensure_ascii=False))


def poner_tipo(mime, app_id):
    # También con sus otros nombres (audio/flac y audio/x-flac), como las categorías
    otros = [m for _, _, _, mimes in CATEGORIAS for m in mimes
             if m != mime and Gio.content_type_equals(m, mime)]
    poner_en(app_id, [mime] + otros)


if __name__ == "__main__":
    orden, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    if orden == "leer":
        leer()
    elif orden == "poner" and len(args) == 2:
        poner(*args)
    elif orden == "tipo" and len(args) == 1:
        tipo(args[0])
    elif orden == "poner-tipo" and len(args) == 2:
        poner_tipo(*args)
    else:
        sys.exit("predeterminadas.py leer | poner <categoría> <app> | tipo <.ext|mime> | poner-tipo <mime> <app>")
