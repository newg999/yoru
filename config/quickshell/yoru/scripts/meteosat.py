#!/usr/bin/env python3
"""Meteosat: el motor del mapa del tiempo de Yoru (Canarias y alrededores).

No se usa a mano: lo arranca la ventana Meteosat (paneles/Meteosat.qml; Mod+Alt+E
o «Meteosat» en el lanzador) y le pide las vistas por la entrada, una por línea
en JSON; responde por la salida con la imagen del mapa y los datos (ver servidor()).

Modos: v viento medio · r rachas máximas · l lluvia (mm/h) · n nubes («ahora»
es el satélite Meteosat real, con rayos; la previsión, el modelo) · t temperatura.

Datos: EUMETSAT (satélite, rayos, mapa) y Open-Meteo (modelo: viento, lluvia,
nubes, temperatura; previsión por horas). Todo se guarda en ~/.cache/meteosat
para no gastar consultas al volver a abrir.
"""
import hashlib
import io
import json
import math
import os
import pickle
import sys
import threading
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

import numpy as np
from PIL import Image

# ---------------------------------------------------------------- ajustes
INICIO = (28.3, -15.8)       # centro inicial (lat, lon)
ALTO_INICIAL = 10.0          # grados de latitud visibles
# Open-Meteo gratis: ~600 puntos/minuto, 5.000/hora, 10.000/día. Cada punto cuenta.
MAX_VISTA = 100              # puntos del modelo dentro de lo que se ve
MAX_REGION = 280             # puntos por descarga como máximo
AMPLIAR = 0.3                # se descarga un 30% más por cada lado (mover/alejar sin pedir más)
REFRESCO = 5 * 60            # el satélite se renueva cada pocos minutos
CADUCA_MODELO = 3 * 3600     # los modelos se actualizan cada pocas horas
ZONA = "Atlantic/Canary"
CACHE = os.path.expanduser("~/.cache/meteosat/datos.pkl")  # datos del modelo entre sesiones

WMS = "https://view.eumetsat.int/geoserver/ows"
OPEN_METEO = "https://api.open-meteo.com/v1/forecast"
VARS = ["wind_speed_10m", "wind_gusts_10m", "wind_direction_10m", "precipitation", "cloud_cover", "temperature_2m"]

MODOS = {"v": "Viento", "r": "Rachas", "l": "Lluvia", "n": "Nubes", "t": "Temperatura"}
UNIDAD = {"v": "km/h", "r": "km/h", "l": "mm/h", "n": "%", "t": "°C"}

PALETAS = {
    "v": [(0, (46, 139, 87)), (12, (60, 170, 75)), (22, (130, 200, 60)), (30, (240, 215, 40)),
          (40, (255, 170, 30)), (50, (255, 120, 20)), (62, (235, 55, 30)), (78, (190, 10, 40)),
          (95, (200, 30, 160)), (120, (110, 20, 150))],
    "t": [(-5, (120, 60, 170)), (0, (60, 90, 200)), (8, (60, 160, 220)), (14, (70, 190, 120)),
          (19, (170, 210, 60)), (23, (250, 210, 50)), (27, (250, 150, 40)), (31, (230, 70, 40)),
          (38, (160, 20, 40))],
    "l": [(0.1, (150, 200, 255)), (0.8, (70, 140, 250)), (2, (30, 70, 220)), (4, (40, 180, 80)),
          (7, (250, 220, 0)), (12, (250, 130, 0)), (20, (220, 20, 20)), (35, (200, 0, 180))],
    "n": [(0, (70, 110, 150)), (100, (245, 245, 245))],
}
PALETAS["r"] = PALETAS["v"]
MARCAS = {
    "r": [0, 20, 30, 40, 50, 60, 80, 100],
    "v": [0, 20, 30, 40, 50, 60, 80, 100],
    "t": [0, 10, 15, 20, 25, 30, 35],
    "l": [0.1, 1, 2, 5, 10, 20],
    "n": [0, 25, 50, 75, 100],
}

CIUDADES = [  # las primeras tienen prioridad si los nombres se solapan
    ("Santa Cruz", 28.463, -16.251), ("Las Palmas", 28.124, -15.430),
    ("Arrecife", 28.963, -13.548), ("Pto. del Rosario", 28.500, -13.862),
    ("San Sebastián", 28.091, -17.111), ("S/C de La Palma", 28.684, -17.765),
    ("Valverde", 27.809, -17.915), ("Madeira", 32.650, -16.910),
    ("Ponta Delgada", 37.740, -25.670), ("Lisboa", 38.720, -9.140),
    ("Madrid", 40.420, -3.700), ("Sevilla", 37.390, -5.980), ("Oporto", 41.150, -8.610),
    ("Málaga", 36.720, -4.420), ("Valencia", 39.470, -0.380), ("Barcelona", 41.390, 2.170),
    ("Casablanca", 33.570, -7.590), ("Rabat", 34.020, -6.840), ("Marrakech", 31.630, -8.010),
    ("Agadir", 30.430, -9.600), ("Tan-Tan", 28.440, -11.100), ("El Aaiún", 27.150, -13.200),
    ("Dajla", 23.680, -15.960), ("Nuadibú", 20.930, -17.030), ("Argel", 36.750, 3.060),
    ("Orán", 35.700, -0.630), ("Uarzazat", 30.920, -6.890),
]


# ---------------------------------------------------------------- descargas
def descargar(url, timeout=40):
    req = urllib.request.Request(url, headers={"User-Agent": "yoru-meteosat/3.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def wms(capas, bbox, w, h, transparente=False):
    lat0, lon0, lat1, lon1 = bbox
    q = {"service": "WMS", "version": "1.3.0", "request": "GetMap", "layers": capas,
         "styles": "", "crs": "EPSG:4326", "bbox": f"{lat0},{lon0},{lat1},{lon1}",
         "width": w, "height": h,
         # JPEG es ~10 veces más rápido de generar; PNG solo para capas transparentes
         "format": "image/png" if transparente else "image/jpeg"}
    if transparente:
        q["transparent"] = "true"
    return Image.open(io.BytesIO(descargar(WMS + "?" + urllib.parse.urlencode(q)))).convert("RGBA")


def open_meteo(lats, lons):
    """Previsión por horas para muchos puntos. Devuelve (horas, {var: array[T, n]})."""
    trozos = [(lats[i:i + 100], lons[i:i + 100]) for i in range(0, len(lats), 100)]

    def pedir(t):
        q = {"latitude": ",".join(f"{x:.3f}" for x in t[0]),
             "longitude": ",".join(f"{x:.3f}" for x in t[1]),
             "hourly": ",".join(VARS), "wind_speed_unit": "kmh",
             "timezone": ZONA, "forecast_days": 3}
        d = json.loads(descargar(OPEN_METEO + "?" + urllib.parse.urlencode(q)))
        return d if isinstance(d, list) else [d]

    with ThreadPoolExecutor() as ex:
        puntos = [p for r in ex.map(pedir, trozos) for p in r]
    horas = puntos[0]["hourly"]["time"]
    datos = {}
    for v in VARS:
        a = np.array([[x if x is not None else np.nan for x in p["hourly"][v]] for p in puntos],
                     dtype=np.float32).T
        datos[v] = np.nan_to_num(a)
    return horas, datos


# ---------------------------------------------------------------- utilidades de dibujo
def colorear(valores, modo):
    paleta = PALETAS[modo]
    xs = [p[0] for p in paleta]
    rgb = np.stack([np.interp(valores, xs, [p[1][c] for p in paleta]) for c in range(3)], -1)
    return rgb.astype(np.uint8)


def campo(rejilla, w, h, caja=None):
    """Rejilla (ny, nx) -> array (h, w) suavizado; caja = trozo de la rejilla a mostrar."""
    im = Image.fromarray(rejilla.astype(np.float32))
    return np.asarray(im.resize((w, h), Image.BICUBIC, box=caja))


def motivo(e):
    if getattr(e, "code", None) == 429:
        try:
            razon = json.loads(e.read()).get("reason", "")
        except Exception:
            razon = ""
        if "Hourly" in razon:
            return f"Open-Meteo: límite por hora agotado, vuelve en {60 - datetime.now().minute} min"
        if "Daily" in razon:
            return "Open-Meteo: límite diario agotado, vuelve mañana"
        return "Open-Meteo: demasiadas consultas seguidas, espera un minuto"
    return f"{e.__class__.__name__}: {e}"[:90]


def capa_color(modo, valores):
    h, w = valores.shape
    rgb = colorear(valores, modo)
    if modo == "l":
        alfa = np.clip((valores - 0.05) / 0.25, 0, 1) * 215
    elif modo == "n":
        alfa = np.clip((valores - 10) / 90, 0, 1) * 235
        rgb[:] = 245
    else:
        alfa = np.full((h, w), 205.0)
    return Image.fromarray(np.dstack([rgb, alfa.astype(np.uint8)]), "RGBA")


# ---------------------------------------------------------------- la app
MAPAS_EN_DISCO = ("base", "lineas")
DIR_MAPAS = os.path.join(os.path.dirname(CACHE), "mapas")


def en_disco(tipo, clave, fn):
    """Envuelve fn: lee la imagen de disco si ya se descargó, si no la descarga y la guarda."""
    def leer():
        ruta = os.path.join(DIR_MAPAS, f"{tipo}-{hashlib.md5(repr(clave).encode()).hexdigest()}.png")
        try:
            with Image.open(ruta) as im:
                os.utime(ruta)
                return im.convert("RGBA")
        except Exception:
            pass
        img = fn()
        try:
            os.makedirs(DIR_MAPAS, exist_ok=True)
            img.save(ruta + ".tmp.png", compress_level=1)
            os.replace(ruta + ".tmp.png", ruta)
            viejos = sorted(os.scandir(DIR_MAPAS), key=lambda e: e.stat().st_mtime)
            for e in viejos[:-60]:      # como mucho 60 mapas (unos 100 MB)
                os.remove(e.path)
        except Exception:
            pass
        return img
    return leer


class App:
    def __init__(self, modo, alto):
        self.modo = modo
        self.centro = list(INICIO)
        self.alto = alto
        self.desfase = 0          # horas desde "ahora"
        self.cache = {}           # (tipo, clave) -> (tiempo, dato)
        self.regiones = []        # zonas del modelo ya descargadas
        self.cargar()
        self.aviso = ""
        self.fallo = False
        self.reproduciendo = False
        self.max_desfase = 0
        self.U = self.V = None    # campo de viento en píxeles (para las partículas)

    # --- caché en disco (para no gastar consultas al volver a abrir)
    def cargar(self):
        try:
            with open(CACHE, "rb") as f:
                d = pickle.load(f)
            self.regiones = d.get("regiones", [])
            if "ciudades" in d:
                self.cache[("ciudades", 0)] = d["ciudades"]
        except Exception:
            pass

    def guardar(self):
        try:
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            d = {"regiones": self.regiones}
            if ("ciudades", 0) in self.cache:
                d["ciudades"] = self.cache[("ciudades", 0)]
            with open(CACHE + ".tmp", "wb") as f:
                pickle.dump(d, f)
            os.replace(CACHE + ".tmp", CACHE)
        except Exception:
            pass

    # --- vista
    def bbox(self, w, h):
        lat, lon = self.centro
        ancho = self.alto * w / h
        return (lat - self.alto / 2, lon - ancho / 2, lat + self.alto / 2, lon + ancho / 2)

    def cacheado(self, tipo, clave, caduca, fn):
        k = (tipo, clave)
        if k in self.cache and time.time() - self.cache[k][0] < caduca:
            return self.cache[k][1]
        if tipo in MAPAS_EN_DISCO:   # el mapa de fondo no cambia: se guarda en disco
            fn = en_disco(tipo, clave, fn)
        try:
            v = fn()
        except Exception:
            if k in self.cache:      # mejor datos viejos que nada
                return self.cache[k][1]
            raise
        self.cache[k] = (time.time(), v)
        if len(self.cache) > 40:  # no acumular vistas viejas
            for viejo in sorted(self.cache, key=lambda x: self.cache[x][0])[:10]:
                del self.cache[viejo]
        return v

    def region(self, bbox):
        """Zona del modelo que cubre la vista: reutiliza una descargada si vale.
        Devuelve (region, aviso)."""
        lat0, lon0, lat1, lon1 = bbox
        paso_ideal = max(0.2, math.sqrt((lat1 - lat0) * (lon1 - lon0) / MAX_VISTA))
        vieja = None
        for r in reversed(self.regiones):
            rb = r["bbox"]
            if rb[0] <= lat0 and rb[1] <= lon0 and rb[2] >= lat1 and rb[3] >= lon1 \
                    and r["paso"] <= paso_ideal * 1.6:
                if time.time() - r["t"] < CADUCA_MODELO:
                    return r, ""
                vieja = vieja or r
        dlat, dlon = (lat1 - lat0) * AMPLIAR, (lon1 - lon0) * AMPLIAR
        rb = (max(-89.0, lat0 - dlat), lon0 - dlon, min(89.0, lat1 + dlat), lon1 + dlon)
        paso = max(paso_ideal, math.sqrt((rb[2] - rb[0]) * (rb[3] - rb[1]) / MAX_REGION))
        nx = max(2, round((rb[3] - rb[1]) / paso))
        ny = max(2, round((rb[2] - rb[0]) / paso))
        lats = [rb[2] - (j + 0.5) * (rb[2] - rb[0]) / ny for j in range(ny) for _ in range(nx)]
        lons = [rb[1] + (i + 0.5) * (rb[3] - rb[1]) / nx for _ in range(ny) for i in range(nx)]
        try:
            horas, datos = open_meteo(lats, lons)
        except Exception as e:
            if vieja:
                return vieja, f"Datos de hace {int((time.time() - vieja['t']) / 60)} min ({motivo(e)})"
            raise
        r = {"t": time.time(), "bbox": rb, "paso": paso, "nx": nx, "ny": ny, "horas": horas,
             "datos": {v: a.reshape(len(horas), ny, nx) for v, a in datos.items()}}
        self.regiones = (self.regiones + [r])[-8:]
        self.guardar()
        return r, ""

    def ciudades(self):
        r = open_meteo([c[1] for c in CIUDADES], [c[2] for c in CIUDADES])
        self.cache[("ciudades", 0)] = (time.time(), r)
        self.guardar()
        return r


# ---------------------------------------------------------------- servidor (ventana de Yoru)
VAR_MODO = {"v": "wind_speed_10m", "r": "wind_gusts_10m", "l": "precipitation", "n": "cloud_cover",
            "t": "temperature_2m"}
DIR_VISTAS = os.path.join(os.path.dirname(CACHE), "vistas")


def redondear(a, n=2):
    return [round(float(x), n) for x in np.asarray(a).ravel()]


def vista(app, w, h, numero):
    """El mapa de la vista (fondo, color del modo y costas; sin textos ni viento, que
    los dibuja la ventana) en un PNG, y lo que la ventana necesita para el resto."""
    bbox = app.bbox(w, h)
    clave_px = tuple(round(x, 3) for x in bbox) + (w, h)
    lat0, lon0, lat1, lon1 = bbox
    app.aviso = ""
    with ThreadPoolExecutor() as ex:
        f_base = ex.submit(app.cacheado, "base", clave_px, 1e9,
                           lambda: wms("backgrounds:ne_background", bbox, w, h))
        f_lineas = ex.submit(app.cacheado, "lineas", clave_px, 1e9, lambda: wms(
            "backgrounds:ne_10m_coastline,osmgray:ne_10m_admin_0_boundary_lines_land",
            bbox, w, h, True))
        f_mod = ex.submit(app.region, bbox)
        f_ciu = ex.submit(app.cacheado, "ciudades", 0, CADUCA_MODELO, app.ciudades)
        sat = app.modo == "n" and app.desfase == 0
        if sat:
            f_sat = ex.submit(app.cacheado, "sat", clave_px, REFRESCO - 10, lambda: (
                wms("mtg_fd:rgb_geocolour", bbox, w, h),
                wms("mtg_fd:li_afa", bbox, w, h, True)))

    img = f_base.result().copy()
    if app.modo in ("l", "n"):
        gris = img.convert("L").point(lambda v: int(25 + v * 0.38))
        img = Image.merge("RGBA", (gris, gris, gris.point(lambda v: min(255, v + 12)),
                                   img.getchannel("A")))
    reg = None
    horas = []
    try:
        reg, app.aviso = f_mod.result()
        horas = reg["horas"]
    except Exception as e:
        app.aviso = f"Sin datos del modelo ({motivo(e)})"

    ahora = datetime.now().strftime("%Y-%m-%dT%H:00")
    i0 = horas.index(ahora) if ahora in horas else 0
    if horas:
        app.desfase = max(-i0, min(len(horas) - 1 - i0, app.desfase))
    idx = i0 + app.desfase
    sat = app.modo == "n" and app.desfase == 0

    rejilla = None
    if reg:
        nx, ny, rb, datos = reg["nx"], reg["ny"], reg["bbox"], reg["datos"]
        caja = ((lon0 - rb[1]) / (rb[3] - rb[1]) * nx, (rb[2] - lat1) / (rb[2] - rb[0]) * ny,
                (lon1 - rb[1]) / (rb[3] - rb[1]) * nx, (rb[2] - lat0) / (rb[2] - rb[0]) * ny)
        valores = datos[VAR_MODO[app.modo]][idx]
        if not sat:
            campo_px = campo(valores, w, h, caja)
            if app.modo == "l":
                campo_px = np.clip(campo_px, 0, None)
            img = Image.alpha_composite(img, capa_color(app.modo, campo_px))
        vel = datos["wind_speed_10m"][idx]
        ang = np.radians(datos["wind_direction_10m"][idx])
        # La rejilla del modelo (de norte a sur y de oeste a este): para el valor
        # bajo el ratón y las partículas del viento
        rejilla = {"bbox": list(rb), "nx": nx, "ny": ny, "valor": redondear(valores, 1),
                   "u": redondear(-vel * np.sin(ang)), "v": redondear(-vel * np.cos(ang))}
    if sat:
        try:
            fondo, rayos = f_sat.result()
            img = Image.alpha_composite(fondo, rayos)
        except Exception as e:
            app.aviso = f"Sin imagen de satélite ({e.__class__.__name__})"
            sat = False
    try:
        img = Image.alpha_composite(img, f_lineas.result())
    except Exception:
        pass

    ciudades = []
    try:
        _, dc = f_ciu.result()
        for k, (nombre, lat, lon) in enumerate(CIUDADES):
            v = float(dc[VAR_MODO[app.modo]][idx, k])
            ciudades.append({"nombre": nombre, "lat": lat, "lon": lon, "valor": round(v, 1)})
    except Exception:
        pass

    # Un archivo por vista (la ventana carga el nuevo y deja el anterior hasta
    # tenerlo): se guardan los dos últimos
    os.makedirs(DIR_VISTAS, exist_ok=True)
    ruta = os.path.join(DIR_VISTAS, f"vista-{numero % 2}.png")
    img.convert("RGB").save(ruta + ".tmp.png", compress_level=1)
    os.replace(ruta + ".tmp.png", ruta)
    return {"imagen": ruta, "bbox": list(bbox), "horas": horas, "idx": idx, "desfase": app.desfase,
            "min": -i0, "max": len(horas) - 1 - i0 if horas else 0, "sat": sat,
            "aviso": app.aviso, "rejilla": rejilla, "ciudades": ciudades}


def servidor():
    """Para la ventana de Yoru. Por la entrada, una petición por línea:
        {"n": 7, "lat": 28.3, "lon": -15.8, "alto": 10, "w": 1200, "h": 700,
         "modo": "r", "desfase": 0}
    y por la salida, una respuesta por línea: {"n": 7, "imagen": ruta, ...} (ver
    vista()) o {"n": 7, "error": "..."}. Al arrancar manda {"paletas": ...}.
    Si llegan varias mientras dibuja, solo atiende la última."""
    app = App("r", ALTO_INICIAL)
    pendiente = [None]
    hay = threading.Event()

    def leer():
        for linea in sys.stdin:
            try:
                pendiente[0] = json.loads(linea)
                hay.set()
            except ValueError:
                pass
        os._exit(0)     # la ventana se cerró

    def responder(d):
        sys.stdout.write(json.dumps(d, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    threading.Thread(target=leer, daemon=True).start()
    responder({"paletas": {m: [[v, "#%02x%02x%02x" % c] for v, c in p] for m, p in PALETAS.items()},
               "marcas": MARCAS, "unidades": UNIDAD, "modos": MODOS, "inicio": list(INICIO),
               "alto": ALTO_INICIAL})
    while True:
        hay.wait()
        hay.clear()
        p = pendiente[0]
        try:
            app.modo = p.get("modo", app.modo) if p.get("modo") in MODOS else app.modo
            app.centro = [float(p["lat"]), float(p["lon"])]
            app.alto = max(1.5, min(45, float(p["alto"])))
            app.desfase = int(p.get("desfase", 0))
            r = vista(app, max(64, int(p["w"])), max(64, int(p["h"])), int(p["n"]))
            r["n"] = p["n"]
            responder(r)
        except Exception as e:
            responder({"n": p.get("n"), "error": motivo(e)})


if __name__ == "__main__":
    servidor()
