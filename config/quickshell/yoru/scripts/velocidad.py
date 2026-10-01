#!/usr/bin/env python3
"""
velocidad.py — test de velocidad de internet (paneles/Velocidad.qml)

Primero la latencia, luego la bajada y luego la subida, con varias conexiones
a la vez para llenar la línea. Mide contra:

  1. Ookla (los servidores de speedtest.net): el más rápido de los más
     cercanos, normalmente de tu misma isla o ciudad.
  2. Cloudflare (speed.cloudflare.com, como Omarchy), si Ookla no contesta.

  velocidad.py          → una línea JSON cada poco, según va midiendo:
    {"fase": "ping", "servidor": "Digimobil · Santa Cruz de Tenerife"}
    {"fase": "ping", "ms": 12.3}                    latencia (la mediana)
    {"fase": "bajada", "mbps": 180.2, "progreso": 0.4}
    {"fase": "bajada", "mbps": 185.0, "fin": true}  el resultado de la bajada
    {"fase": "subida", ...}                          igual que la bajada
    {"fase": "fin"}
    {"fase": "error", "texto": "..."}               sin internet, nos frenan...

Si el servidor contesta con un error (429 = demasiados tests seguidos) se para
todo al momento: reintentar solo alargaría el castigo.

Solo usa Python: no hace falta instalar nada. Quickshell lo para al cerrar el
panel (y entonces corta las descargas).
"""

import http.client
import json
import signal
import ssl
import statistics
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

CONEXIONES = 4           # descargas / subidas a la vez
DURACION = 8             # segundos por fase
CALENTAR = 1.5           # los primeros segundos no cuentan para el resultado
INFORMAR = 0.25          # cada cuánto se manda la velocidad del momento
VENTANA = 1.0            # la «del momento» es la del último segundo
BLOQUE = 64 * 1024
BAJAR = 25_000_000       # bytes por petición de bajada (Cloudflare no da más de ~50 MB)
SUBIR = 25_000_000       # bytes por petición de subida
CANDIDATOS = 3           # servidores de Ookla que se prueban antes de elegir
# Los de Ookla contestan 500 a quien no parece un navegador
CABECERAS = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"}

contexto = ssl.create_default_context()


def decir(**datos):
    print(json.dumps(datos), flush=True)


class Servidor:
    """Dónde y cómo medir: lo único que cambia entre Ookla y Cloudflare"""

    def __init__(self, nombre, host, puerto, ping, bajar, subir):
        self.nombre, self.host, self.puerto = nombre, host, puerto
        self.ruta_ping, self.ruta_bajar, self.ruta_subir = ping, bajar, subir

    def conexion(self, timeout=10):
        return http.client.HTTPSConnection(self.host, self.puerto, timeout=timeout, context=contexto)

    def comprobar(self, respuesta):
        quien = self.nombre.split(" · ")[0]
        if respuesta.status == 429:
            raise OSError(f"{quien} frena los tests por hacer muchos seguidos: prueba en unos minutos")
        if respuesta.status != 200:
            raise OSError(f"{quien} contesta con un error ({respuesta.status})")


def en_servidor(respuesta):
    """Lo que tardó Cloudflare en contestar (Server-Timing: cfSpeedEdge;dur=3,
    cfSpeedWorker;dur=24): no es tiempo de la red, así que no cuenta"""
    ms = 0.0
    for nombre, valor in respuesta.getheaders():
        if nombre.lower() == "server-timing" and "cfSpeed" in valor:
            for parte in valor.split(","):
                if ";dur=" in parte:
                    ms += float(parte.split(";dur=")[1])
    return ms


def latencia(s, veces=10):
    """Ida y vuelta de peticiones vacías por una conexión ya abierta"""
    c = s.conexion(timeout=5)
    tiempos = []
    for i in range(veces + 1):
        t = time.monotonic()
        c.request("GET", s.ruta_ping, headers=CABECERAS)
        r = c.getresponse()
        r.read()
        s.comprobar(r)
        if i > 0:              # la primera abre la conexión (TLS): no cuenta
            tiempos.append((time.monotonic() - t) * 1000 - en_servidor(r))
    c.close()
    return statistics.median(tiempos)


def cloudflare():
    return Servidor("Cloudflare", "speed.cloudflare.com", 443, "/__down?bytes=0",
                    f"/__down?bytes={BAJAR}", "/__up")


def ookla():
    """El servidor de Ookla con menos latencia de los más cercanos (o None)"""
    try:
        c = http.client.HTTPSConnection("www.speedtest.net", timeout=5, context=contexto)
        c.request("GET", f"/api/js/servers?engine=js&https_functional=true&limit={CANDIDATOS}",
                  headers=CABECERAS)
        lista = json.loads(c.getresponse().read())
    except (OSError, http.client.HTTPException, ValueError):
        return None

    servidores = []
    for d in lista:
        host, _, puerto = d.get("host", "").partition(":")
        if host:
            servidores.append(Servidor(f"{d.get('sponsor', host)} · {d.get('name', '')}".strip(" ·"),
                                       host, int(puerto or 443), "/latency.txt",
                                       f"/download?size={BAJAR}", "/upload"))

    def probar(s):
        try:
            return latencia(s, veces=3), s
        except (OSError, http.client.HTTPException):
            return None

    with ThreadPoolExecutor(len(servidores) or 1) as hilos:
        probados = [p for p in hilos.map(probar, servidores) if p]
    return min(probados, key=lambda p: p[0])[1] if probados else None


class Medidor:
    """Cuenta los bytes que mueven todas las conexiones"""

    def __init__(self):
        self.bytes = 0
        self.cerrojo = threading.Lock()
        self.parar = threading.Event()
        self.fallos = 0
        self.motivo = ""             # por qué se paró antes de tiempo

    def sumar(self, n):
        with self.cerrojo:
            self.bytes += n

    def fallar(self, error, servidor):
        """Un error del servidor para todo; uno de red se reintenta unas veces"""
        self.fallos += 1
        if isinstance(error, http.client.HTTPException) or self.fallos > 2 * CONEXIONES \
                or str(error).startswith(servidor.nombre.split(" · ")[0]):
            self.motivo = self.motivo or str(error)
            self.parar.set()
        else:
            time.sleep(1)


def bajar(s, m):
    while not m.parar.is_set():
        try:
            c = s.conexion()
            c.request("GET", s.ruta_bajar, headers=CABECERAS)
            r = c.getresponse()
            s.comprobar(r)
            while not m.parar.is_set():
                trozo = r.read(BLOQUE)
                if not trozo:
                    break
                m.sumar(len(trozo))
            c.close()
        except (OSError, http.client.HTTPException) as e:
            m.fallar(e, s)


def subir(s, m):
    trozo = bytes(BLOQUE)
    while not m.parar.is_set():
        try:
            c = s.conexion()
            c.putrequest("POST", s.ruta_subir)
            for nombre, valor in CABECERAS.items():
                c.putheader(nombre, valor)
            c.putheader("Content-Type", "application/octet-stream")
            c.putheader("Content-Length", str(SUBIR))
            c.endheaders()
            enviados = 0
            while enviados < SUBIR and not m.parar.is_set():
                n = min(BLOQUE, SUBIR - enviados)
                c.send(trozo[:n])
                enviados += n
                m.sumar(n)
            if enviados == SUBIR:
                r = c.getresponse()
                r.read()
                s.comprobar(r)
            c.close()
        except (OSError, http.client.HTTPException) as e:
            m.fallar(e, s)


def medir(s, fase, trabajo):
    m = Medidor()
    for _ in range(CONEXIONES):
        threading.Thread(target=trabajo, args=(s, m), daemon=True).start()

    inicio = time.monotonic()
    muestras = [(inicio, 0)]          # (momento, bytes hasta entonces)
    base = None                       # (momento, bytes) al acabar de calentar
    while True:
        time.sleep(INFORMAR)
        ahora = time.monotonic()
        total = m.bytes
        muestras.append((ahora, total))
        transcurrido = ahora - inicio
        if base is None and transcurrido >= CALENTAR:
            base = (ahora, total)
        if transcurrido >= DURACION or m.parar.is_set():
            break
        # Velocidad del último segundo
        viejas = [x for x in muestras if ahora - x[0] <= VENTANA + 0.01]
        t0, b0 = viejas[0] if len(viejas) > 1 else muestras[-2]
        mbps = (total - b0) * 8 / (ahora - t0) / 1e6
        decir(fase=fase, mbps=round(mbps, 1), progreso=round(transcurrido / DURACION, 3))

    m.parar.set()
    if m.motivo or m.bytes == 0 or base is None:
        raise OSError(m.motivo or f"No se pudo medir la {fase}")
    t0, b0 = base
    mbps = (total - b0) * 8 / (ahora - t0) / 1e6
    decir(fase=fase, mbps=round(mbps, 1), progreso=1, fin=True)


def main():
    # Si quien lee se va (se cierra el panel), salir sin más
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    try:
        s = ookla() or cloudflare()
        if s.host == "speed.cloudflare.com":
            # cf-ray acaba en el código del centro de datos: «...-MAD»
            c = s.conexion()
            c.request("GET", s.ruta_ping, headers=CABECERAS)
            r = c.getresponse()
            r.read()
            s.comprobar(r)
            rayo = r.getheader("cf-ray", "")
            if "-" in rayo:
                s.nombre = "Cloudflare · " + rayo.rsplit("-", 1)[1]
        decir(fase="ping", servidor=s.nombre)
        decir(fase="ping", ms=round(latencia(s), 1))
        medir(s, "bajada", bajar)
        medir(s, "subida", subir)
        decir(fase="fin")
    except (OSError, http.client.HTTPException) as e:
        decir(fase="error", texto=str(e) or "Sin conexión con el servidor del test")
        sys.exit(1)


if __name__ == "__main__":
    main()
