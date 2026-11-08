#!/usr/bin/env python3
# ============================================================================
#  mega.py — el espacio de tu cuenta de MEGA y su carpeta, para el panel de
#  MEGA de la barra (paneles/PanelMega.qml)
#
#    mega.py   →   {"usado": 13167959142, "total": 53687091200,
#                   "carpeta": "/home/don/Descargas/Mega"}
#
#  MEGAsync no tiene una orden para preguntárselo: lo saca de su
#  configuración (~/.local/share/data/Mega Limited/MEGAsync/MEGAsync.cfg).
#  Ahí los nombres van cifrados y los valores en base64, así que se
#  reconocen por su forma:
#    · total: un número exacto de GiB (los planes son 20 GB, 50 GB, 2 TB...)
#    · usado: el mayor de los que quedan por debajo, sin contar las fechas
#      (que también son números largos: segundos o milisegundos desde 1970)
#    · carpeta: la primera ruta que exista
#  Lo que no encuentre sale como null (el panel lo deja sin poner).
#  No lee nada más: ni la sesión ni el correo salen de aquí.
# ============================================================================
import base64
import json
import os
import re

CFG = os.path.expanduser("~/.local/share/data/Mega Limited/MEGAsync/MEGAsync.cfg")
GIB = 1 << 30


def es_fecha(n):
    # Entre 2020 y 2040, en segundos o en milisegundos
    return 1.57e9 <= n <= 2.21e9 or 1.57e12 <= n <= 2.21e12


def leer():
    numeros, rutas = [], []
    seccion = ""
    with open(CFG, errors="ignore") as f:
        for linea in f:
            linea = linea.strip()
            if linea.startswith("["):
                seccion = linea
                continue
            # Los datos de la cuenta van en su sección, no en [General]
            if seccion in ("", "[General]") or "=" not in linea:
                continue
            valor = linea.split("=", 1)[1].strip('"')
            try:
                texto = base64.b64decode(valor, validate=True).decode()
            except Exception:
                continue
            if re.fullmatch(r"\d{4,}", texto):
                numeros.append(int(texto))
            elif texto.startswith("/") and os.path.isdir(texto):
                rutas.append(texto)

    totales = [n for n in numeros if n >= GIB and n % GIB == 0 and n < 1 << 50]
    total = max(totales) if totales else None
    usados = [n for n in numeros if not es_fecha(n) and (total is None or n < total)
              and n not in totales]
    usado = max(usados) if usados and total else None
    return {"usado": usado, "total": total, "carpeta": rutas[0] if rutas else None}


if __name__ == "__main__":
    try:
        print(json.dumps(leer()))
    except OSError:
        print(json.dumps({"usado": None, "total": None, "carpeta": None}))
