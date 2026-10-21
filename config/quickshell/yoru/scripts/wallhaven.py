#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  wallhaven.py — Buscar y bajar fondos de wallhaven.cc (pestaña Descubrir
#  del panel Fondos). Usa la API pública: sin cuenta, solo fondos SFW.
#
#    wallhaven.py buscar <tema|texto> <página>   → JSON: {"pagina", "ultima", "fondos": [...]}
#    wallhaven.py bajar <id> <url>               → ruta del fondo bajado
#    wallhaven.py borrar <ruta>                  → lo manda a la papelera
#
#  Los fondos se bajan a ~/.local/share/wallpapers (la carpeta wallpapers/
#  del repo) como wallhaven-<id>.<ext>, y se apuntan en wallhaven.txt para
#  que wallpapers/descargar.sh los vuelva a bajar en otro equipo.
# ----------------------------------------------------------------------------
import json
import os
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

API = "https://wallhaven.cc/api/v1/search"
CARPETA = os.path.expanduser("~/.local/share/wallpapers")
LISTA = os.path.join(CARPETA, "wallhaven.txt")
CABECERA_LISTA = "# Bajados desde el panel de fondos (Descubrir)"
ACTUAL = os.path.expanduser("~/.cache/wallpaper-actual")
# Las miniaturas de Mis fondos (scripts/fondos.sh); la segunda, de antes del carrusel
MINIATURAS = [os.path.expanduser("~/.cache/fondos-tarjetas"),
              os.path.expanduser("~/.cache/fondos-miniaturas")]
WALLPAPER_SH = os.path.expanduser("~/.config/niri/scripts/wallpaper.sh")

# Temas del panel: qué se le pide a Wallhaven. categories = general/anime/gente
TEMAS = {
    "populares": {"categories": "110", "sorting": "toplist", "topRange": "1w"},
    "naturaleza": {"q": "nature", "categories": "100", "sorting": "toplist", "topRange": "1y"},
    "anime": {"categories": "010", "sorting": "toplist", "topRange": "3M"},
    "minimalista": {"q": "minimalism", "categories": "110", "sorting": "toplist", "topRange": "1y"},
    "noche": {"q": "night", "categories": "110", "sorting": "toplist", "topRange": "1y"},
}


def pedir(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "yoru-fondos"})
    return urllib.request.urlopen(req, timeout=timeout)


def buscar(consulta, pagina):
    params = dict(TEMAS.get(consulta) or {"q": consulta, "categories": "110", "sorting": "relevance"})
    # Que llenen bien una pantalla de 2560x1440: grandes y apaisados
    params.update({"purity": "100", "atleast": "2560x1440", "ratios": "16x9,16x10,21x9", "page": pagina})
    with pedir(API + "?" + urllib.parse.urlencode(params)) as r:
        datos = json.load(r)
    bajados = {f.rsplit(".", 1)[0].split("-")[-1] for f in os.listdir(CARPETA)}
    print(json.dumps({
        "pagina": datos["meta"]["current_page"],
        "ultima": datos["meta"]["last_page"],
        "fondos": [{
            "id": w["id"],
            "url": w["path"],
            "miniatura": w["thumbs"]["small"],
            "resolucion": w["resolution"],
            "megas": round(w["file_size"] / 1e6, 1),
            "bajado": w["id"] in bajados,
        } for w in datos["data"]],
    }))


def bajar(ident, url):
    destino = os.path.join(CARPETA, f"wallhaven-{ident}.{url.rsplit('.', 1)[-1]}")
    if not os.path.exists(destino):
        # A un temporal y luego se mueve: el panel de fondos no ve nunca uno a medias
        fd, tmp = tempfile.mkstemp(dir=CARPETA, prefix=".bajando-")
        try:
            with pedir(url, timeout=60) as r, os.fdopen(fd, "wb") as f:
                while trozo := r.read(1 << 16):
                    f.write(trozo)
            os.chmod(tmp, 0o644)   # mkstemp lo crea solo para ti
            os.replace(tmp, destino)
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)
        apuntar(ident, url)
    print(destino)


def apuntar(ident, url):
    try:
        with open(LISTA) as f:
            texto = f.read()
    except FileNotFoundError:
        texto = ""
    if f"{ident} " in texto:
        return
    with open(LISTA, "a") as f:
        if CABECERA_LISTA not in texto:
            f.write(("" if texto.endswith("\n\n") or not texto else "\n" if texto.endswith("\n") else "\n\n")
                    + CABECERA_LISTA + "\n")
        f.write(f"{ident} {url}\n")


def borrar(ruta):
    """A la papelera (se puede recuperar), sin su miniatura y fuera de
    wallhaven.txt para que descargar.sh no lo vuelva a bajar."""
    ruta = os.path.realpath(ruta)
    if os.path.dirname(ruta) != os.path.realpath(CARPETA) or not os.path.isfile(ruta):
        raise ValueError("no es un fondo de la carpeta de fondos")
    # Si es el que está puesto, antes se pasa al siguiente. Lo lanza niri:
    # swaybg tiene que seguir vivo aunque se reinicie la shell
    try:
        with open(ACTUAL) as f:
            puesto = os.path.realpath(f.read().strip()) == ruta
    except FileNotFoundError:
        puesto = False
    if puesto:
        subprocess.run(["niri", "msg", "action", "spawn", "--", WALLPAPER_SH, "next"], check=False)

    if subprocess.run(["gio", "trash", ruta], capture_output=True).returncode != 0:
        os.remove(ruta)
    nombre = os.path.splitext(os.path.basename(ruta))[0]
    for carpeta in MINIATURAS:
        try:
            os.remove(os.path.join(carpeta, nombre + ".jpg"))
        except FileNotFoundError:
            pass

    # Fuera de la lista (los de wallhaven se llaman anime-<id> o wallhaven-<id>)
    ident = nombre.split("-")[-1]
    try:
        with open(LISTA) as f:
            lineas = f.readlines()
    except FileNotFoundError:
        lineas = []
    quedan = [l for l in lineas if l.split(" ")[0] != ident]
    if len(quedan) != len(lineas):
        with open(LISTA, "w") as f:
            f.writelines(quedan)
    print(ruta)


if __name__ == "__main__":
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "buscar":
            buscar(sys.argv[2], int(sys.argv[3]))
        elif len(sys.argv) == 4 and sys.argv[1] == "bajar":
            bajar(sys.argv[2], sys.argv[3])
        elif len(sys.argv) == 3 and sys.argv[1] == "borrar":
            borrar(sys.argv[2])
        else:
            sys.exit(__doc__ or "uso: wallhaven.py buscar <tema|texto> <página> | bajar <id> <url> | borrar <ruta>")
    except Exception as e:   # el panel enseña el error tal cual
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
