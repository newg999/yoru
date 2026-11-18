#!/usr/bin/env python3
# ============================================================================
#  musica.py — el índice de la biblioteca para «Música de Yoru»
#
#    python3 musica.py [carpeta ...]      (sin carpetas: las de siempre)
#
#  Recorre las carpetas y lee las etiquetas (mutagen) solo de lo nuevo o lo
#  cambiado (por tamaño y fecha): la primera vez tarda, las siguientes solo
#  mira fechas. Guarda:
#    ~/.cache/yoru/musica/indice.json      canciones y discos
#    ~/.cache/yoru/musica/caratulas/*.jpg  una carátula pequeña por disco
#  La ventana (comun/Tocadiscos.qml) enseña el índice guardado al momento y
#  lanza esto en segundo plano. Por stdout, una línea JSON de progreso
#  ({"leidas": n}) y otra al acabar ({"listo": true, ...}).
#  Si una carpeta no está (el NAS sin montar), se conserva lo que había.
# ============================================================================
import fcntl
import hashlib
import io
import json
import os
import sys
import time

try:
    import mutagen
except ImportError:
    mutagen = None
try:
    from PIL import Image
except ImportError:
    Image = None

AUDIO = {".mp3", ".flac", ".m4a", ".ogg", ".opus", ".oga", ".wav", ".aac", ".wma", ".ape", ".wv", ".alac", ".aiff"}
PORTADAS = ("cover", "folder", "front", "portada", "album")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "yoru", "musica")
INDICE = os.path.join(CACHE, "indice.json")
CARATULAS = os.path.join(CACHE, "caratulas")
TAM = 384   # px de la carátula guardada (la cuadrícula la pinta a ~180)


def decir(**d):
    print(json.dumps(d, ensure_ascii=False), flush=True)


def carpetas_por_defecto():
    f = os.path.expanduser("~/.local/state/yoru/ajustes.json")
    try:
        c = json.load(open(f)).get("carpetasMusica")
        if c:
            return [os.path.expanduser(x) for x in c]
    except (OSError, ValueError):
        pass
    return ["/mnt/synology/Musica/Biblioteca", os.path.expanduser("~/Música")]


def primero(tags, *claves):
    for k in claves:
        v = tags.get(k)
        if v:
            v = v[0] if isinstance(v, list) else v
            v = str(v).strip()
            if v:
                return v
    return ""


def numero(v):
    # «3/12» → 3
    try:
        return int(str(v).split("/")[0])
    except ValueError:
        return 0


def leer(ruta):
    """Las etiquetas de una canción (con lo que se pueda si no tiene)."""
    nombre = os.path.splitext(os.path.basename(ruta))[0]
    c = {"titulo": nombre, "artista": "", "albumArtista": "", "album": "", "pista": 0,
         "disco": 0, "anio": "", "genero": "", "duracion": 0, "imagen": False}
    if not mutagen:
        return c
    try:
        m = mutagen.File(ruta, easy=True)
    except Exception:
        m = None
    if m is None:
        return c
    t = m.tags or {}
    c["titulo"] = primero(t, "title") or nombre
    c["artista"] = primero(t, "artist")
    c["albumArtista"] = primero(t, "albumartist")
    c["album"] = primero(t, "album")
    c["pista"] = numero(primero(t, "tracknumber"))
    c["disco"] = numero(primero(t, "discnumber"))
    c["anio"] = primero(t, "date", "originaldate")[:4]
    c["genero"] = primero(t, "genre")
    c["duracion"] = round(getattr(m.info, "length", 0) or 0)
    return c


def imagen_incrustada(ruta):
    """Los bytes de la carátula dentro del archivo, si la lleva."""
    try:
        m = mutagen.File(ruta)
    except Exception:
        return None
    if m is None:
        return None
    if getattr(m, "pictures", None):                       # FLAC, Ogg
        return m.pictures[0].data
    tags = m.tags or {}
    for k in list(tags.keys()):
        if str(k).startswith("APIC"):                       # MP3
            return tags[k].data
    if "covr" in tags and tags["covr"]:                     # M4A
        return bytes(tags["covr"][0])
    if "metadata_block_picture" in tags:                    # Opus
        try:
            import base64
            from mutagen.flac import Picture
            return Picture(base64.b64decode(tags["metadata_block_picture"][0])).data
        except Exception:
            return None
    return None


def guardar_caratula(datos, destino):
    try:
        if Image:
            im = Image.open(io.BytesIO(datos) if isinstance(datos, bytes) else datos)
            im = im.convert("RGB")
            im.thumbnail((TAM, TAM))
            im.save(destino + ".tmp", "JPEG", quality=88)
        else:
            if not isinstance(datos, bytes):
                datos = open(datos, "rb").read()
            open(destino + ".tmp", "wb").write(datos)
        os.replace(destino + ".tmp", destino)
        return True
    except Exception:
        return False


def caratula_de(carpeta, canciones, compartida=False, titulo=""):
    """La carátula del disco: <cache>/caratulas/<hash>.jpg. Si la carpeta
    tiene un solo disco, la de la carpeta (cover.jpg...); si tiene varios
    (una carpeta «Sueltas» con singles), la que lleva dentro cada uno."""
    clave = carpeta + ("\0" + titulo if compartida else "")
    clave = hashlib.sha1(clave.encode()).hexdigest()[:16]
    destino = os.path.join(CARATULAS, clave + ".jpg")
    if os.path.exists(destino):
        return destino
    # Una imagen en la carpeta (cover.jpg, folder.jpg... o la que haya)
    try:
        imgs = [] if compartida else [e for e in os.scandir(carpeta)
                if e.is_file() and os.path.splitext(e.name)[1].lower() in (".jpg", ".jpeg", ".png", ".webp")]
    except OSError:
        imgs = []
    imgs.sort(key=lambda e: (not e.name.lower().startswith(PORTADAS), e.name.lower()))
    if imgs and guardar_caratula(imgs[0].path, destino):
        return destino
    # Si no, la que lleve dentro la primera canción que tenga
    if mutagen:
        for c in canciones[:4]:
            d = imagen_incrustada(c["ruta"])
            if d and guardar_caratula(d, destino):
                return destino
    return ""


def main():
    carpetas = [os.path.abspath(os.path.expanduser(a)) for a in sys.argv[1:]] or carpetas_por_defecto()
    os.makedirs(CARATULAS, exist_ok=True)

    # Uno a la vez: si ya hay otro escaneando, este no hace nada
    cerrojo = open(os.path.join(CACHE, ".escaneando"), "w")
    try:
        fcntl.flock(cerrojo, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        decir(listo=False, ocupado=True)
        return

    try:
        viejo = json.load(open(INDICE))
    except (OSError, ValueError):
        viejo = {}
    antes = {c["ruta"]: c for c in viejo.get("canciones", [])}

    canciones, nuevas, sin_montar = [], [], []
    inicio = time.monotonic()
    for raiz in carpetas:
        if not os.path.isdir(raiz):
            # Sin montar (o sin crear): lo que había de ella se queda
            sin_montar.append(raiz)
            canciones += [c for r, c in antes.items() if r.startswith(raiz + os.sep)]
            continue
        for dirpath, dirnames, archivos in os.walk(raiz):
            dirnames[:] = sorted(d for d in dirnames if not d.startswith((".", "#", "$")))
            for nombre in sorted(archivos):
                if os.path.splitext(nombre)[1].lower() not in AUDIO or nombre.startswith("."):
                    continue
                ruta = os.path.join(dirpath, nombre)
                try:
                    st = os.stat(ruta)
                except OSError:
                    continue
                v = antes.get(ruta)
                if v and v.get("tam") == st.st_size and v.get("mtime") == st.st_mtime_ns:
                    canciones.append(v)
                    continue
                nuevas.append((ruta, dirpath, st))

    # Las etiquetas de lo nuevo, de 16 en 16. Ayuda poco (la primera vez,
    # de 12 a 10 min con 3.100 canciones en el NAS): lo que frena es el NAS
    from concurrent.futures import ThreadPoolExecutor
    leidas = 0
    with ThreadPoolExecutor(max_workers=16) as hilos:
        for (ruta, dirpath, st), c in zip(nuevas, hilos.map(lambda n: leer(n[0]), nuevas)):
            c.update(ruta=ruta, carpeta=dirpath, tam=st.st_size, mtime=st.st_mtime_ns)
            canciones.append(c)
            leidas += 1
            if leidas % 50 == 0:
                decir(leidas=leidas)

    # Discos: por carpeta y nombre de disco (un recopilatorio con varios
    # artistas en una carpeta es un solo disco)
    discos = {}
    for c in canciones:
        nombre = c["album"] or os.path.basename(c["carpeta"])
        clave = c["carpeta"] + "\0" + nombre
        d = discos.get(clave)
        if not d:
            d = discos[clave] = {"id": hashlib.sha1(clave.encode()).hexdigest()[:12], "titulo": nombre,
                                 "artista": "", "anio": c["anio"], "genero": c["genero"],
                                 "carpeta": c["carpeta"], "caratula": "", "canciones": []}
        d["canciones"].append(c)
    por_carpeta = {}
    for d in discos.values():
        por_carpeta[d["carpeta"]] = por_carpeta.get(d["carpeta"], 0) + 1
    lista = []
    for d in discos.values():
        cs = sorted(d["canciones"], key=lambda c: (c["disco"], c["pista"], c["ruta"]))
        artistas = {c["albumArtista"] or c["artista"] for c in cs}
        d["artista"] = artistas.pop() if len(artistas) == 1 else (cs[0]["albumArtista"] or "Varios artistas")
        d["anio"] = min((c["anio"] for c in cs if c["anio"]), default="")
        d["caratula"] = caratula_de(d["carpeta"], cs, por_carpeta[d["carpeta"]] > 1, d["titulo"])
        d["duracion"] = sum(c["duracion"] for c in cs)
        d["canciones"] = [c["ruta"] for c in cs]
        for c in cs:
            c["disco_id"] = d["id"]
        lista.append(d)
    lista.sort(key=lambda d: (d["artista"].lower(), d["anio"], d["titulo"].lower()))
    canciones.sort(key=lambda c: (c.get("albumArtista") or c["artista"]).lower())

    nuevo = {"version": 1, "carpetas": carpetas, "sinMontar": sin_montar,
             "fecha": int(time.time()), "canciones": canciones, "discos": lista}
    if (nuevo["canciones"], nuevo["discos"], nuevo["sinMontar"]) != (
            viejo.get("canciones"), viejo.get("discos"), viejo.get("sinMontar")) or not viejo:
        with open(INDICE + ".tmp", "w") as f:
            json.dump(nuevo, f, ensure_ascii=False, separators=(",", ":"))
        os.replace(INDICE + ".tmp", INDICE)
    decir(listo=True, canciones=len(canciones), discos=len(lista), leidas=leidas,
          sinMontar=sin_montar, segundos=round(time.monotonic() - inicio, 1))


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
