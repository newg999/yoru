#!/usr/bin/env python3
"""
bluetooth.py — Menú de bluetooth con rofi + bluetoothctl

  · Encender / apagar el bluetooth
  · Lista tus dispositivos; los conectados salen en verde
  · Conectar, desconectar, emparejar, confiar y olvidar
  · Buscar dispositivos nuevos (10 segundos)

Atajo: Mod+Alt+B   ·   Clic en el icono de bluetooth de la barra
Para emparejar dispositivos que piden un PIN, usa Blueman (última opción).
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from rofimenu import ejecutar, menu, avisar, escapar  # noqa: E402

BT_ON = "\U000f00af"
BT_OFF = "\U000f00b2"
BUSCAR = ""
AJUSTES = ""
VOLVER = ""
CONECTAR = ""
DESCONECTAR = ""
EMPAREJAR = ""
CONFIAR = ""
OLVIDAR = ""

# Icono según el tipo de dispositivo (campo "Icon" de bluetoothctl info)
ICONOS = {
    "audio-headset": "\U000f02cb",
    "audio-headphones": "\U000f02cb",
    "audio-card": "\U000f04c3",
    "input-mouse": "\U000f037d",
    "input-keyboard": "\U000f030c",
    "input-gaming": "\U000f0297",
    "phone": "\U000f03f2",
    "computer": "\U000f0322",
}
ICONO_GENERICO = ""


def bt(*args, timeout=15):
    return ejecutar(["bluetoothctl", *args], timeout=timeout)


def encendido():
    _, salida = bt("show")
    return "Powered: yes" in salida


def dispositivos():
    """Lista de dicts {mac, nombre, conectado, emparejado, confiado, icono}."""
    _, salida = bt("devices")
    lista = []
    for linea in salida.splitlines():
        partes = linea.split(" ", 2)
        if len(partes) < 3 or partes[0] != "Device":
            continue
        mac, nombre = partes[1], partes[2]
        _, info = bt("info", mac)
        datos = {}
        for l in info.splitlines():
            if ":" in l:
                k, v = l.strip().split(":", 1)
                datos[k.strip()] = v.strip()
        lista.append({
            "mac": mac,
            "nombre": datos.get("Alias", nombre),
            "conectado": datos.get("Connected") == "yes",
            "emparejado": datos.get("Paired") == "yes",
            "confiado": datos.get("Trusted") == "yes",
            "icono": ICONOS.get(datos.get("Icon", ""), ICONO_GENERICO),
        })
    # Conectados primero, luego emparejados, luego el resto
    return sorted(lista, key=lambda d: (not d["conectado"], not d["emparejado"], d["nombre"].lower()))


def encender():
    ejecutar(["rfkill", "unblock", "bluetooth"])
    codigo, salida = bt("power", "on")
    if codigo == 0:
        avisar("Bluetooth", "Encendido", "bluetooth-active")
    else:
        avisar("Bluetooth", f"No se pudo encender\n{salida[-150:]}", urgente=True)
    time.sleep(1)


def accion(texto, *args, timeout=25):
    avisar("Bluetooth", f"{texto}…", "bluetooth-active")
    codigo, salida = bt(*args, timeout=timeout)
    return codigo == 0, salida


def submenu(d):
    nombre = escapar(d["nombre"])
    opciones, acciones = [], []

    if d["conectado"]:
        opciones.append(f"{DESCONECTAR}  Desconectar")
        acciones.append("desconectar")
    else:
        opciones.append(f"{CONECTAR}  Conectar")
        acciones.append("conectar")
    if not d["emparejado"]:
        opciones.append(f"{EMPAREJAR}  Emparejar")
        acciones.append("emparejar")
    if not d["confiado"]:
        opciones.append(f"{CONFIAR}  Confiar (conectar solo en el futuro)")
        acciones.append("confiar")
    opciones.append(f"{OLVIDAR}  Olvidar dispositivo")
    acciones.append("olvidar")
    opciones.append(f"{VOLVER}  Volver")
    acciones.append("volver")

    estado = "conectado" if d["conectado"] else ("emparejado" if d["emparejado"] else "nuevo")
    i = menu(f"{d['icono']} ", opciones, mensaje=f"<b>{nombre}</b> · {estado}\n<span alpha='60%'>{d['mac']}</span>",
             urgentes=[len(opciones) - 2])
    if i is None:
        return None
    a = acciones[i]
    mac = d["mac"]

    if a == "conectar":
        if not d["emparejado"]:
            ok, salida = accion(f"Emparejando {d['nombre']}", "pair", mac, timeout=40)
            if not ok:
                avisar("Bluetooth", f"No se pudo emparejar {d['nombre']}.\nSi pide PIN, usa Blueman.", urgente=True)
                return None
            bt("trust", mac)
        ok, salida = accion(f"Conectando {d['nombre']}", "connect", mac)
        avisar("Bluetooth", f"{d['nombre']} conectado" if ok else f"No se pudo conectar {d['nombre']}",
               "bluetooth-active", urgente=not ok)
    elif a == "desconectar":
        ok, _ = accion(f"Desconectando {d['nombre']}", "disconnect", mac)
        avisar("Bluetooth", f"{d['nombre']} desconectado" if ok else "No se pudo desconectar")
    elif a == "emparejar":
        ok, _ = accion(f"Emparejando {d['nombre']}", "pair", mac, timeout=40)
        if ok:
            bt("trust", mac)
        avisar("Bluetooth", f"{d['nombre']} emparejado" if ok else "No se pudo emparejar. Prueba con Blueman.",
               urgente=not ok)
    elif a == "confiar":
        codigo, _ = bt("trust", mac)
        avisar("Bluetooth", f"{d['nombre']}: se conectará solo" if codigo == 0 else "No se pudo")
    elif a == "olvidar":
        codigo, _ = bt("remove", mac)
        avisar("Bluetooth", f"{d['nombre']} olvidado" if codigo == 0 else "No se pudo olvidar")
    elif a == "volver":
        return "volver"
    return None


def main():
    while True:
        if not encendido():
            i = menu(f"{BT_OFF} ", [f"{BT_ON}  Encender bluetooth", f"{AJUSTES}  Abrir Blueman"],
                     mensaje="El bluetooth está <b>apagado</b>")
            if i == 0:
                encender()
                continue
            if i == 1:
                ejecutar(["setsid", "-f", "blueman-manager"])
            return

        lista = dispositivos()
        fijas = [f"{BUSCAR}  Buscar dispositivos nuevos", f"{BT_OFF}  Apagar bluetooth",
                 f"{AJUSTES}  Abrir Blueman"]
        filas, activos = [], []
        for d in lista:
            texto = f"{d['icono']}  {escapar(d['nombre'])}"
            if d["conectado"]:
                texto += "  <span alpha='70%' size='small'>conectado</span>"
                activos.append(len(fijas) + len(filas))
            elif not d["emparejado"]:
                texto += "  <span alpha='55%' size='small'>nuevo</span>"
            filas.append(texto)

        conectados = [d["nombre"] for d in lista if d["conectado"]]
        mensaje = ("Conectado: <b>" + escapar(", ".join(conectados)) + "</b>") if conectados \
            else "Ningún dispositivo conectado"
        i = menu(f"{BT_ON} ", fijas + filas, mensaje=mensaje, activos=activos,
                 buscar=len(filas) > 6, fila=len(fijas) if filas else 0)

        if i is None:
            return
        if i == 0:
            avisar("Bluetooth", "Buscando dispositivos durante 10 segundos…\n"
                                "Pon el tuyo en modo emparejamiento.", "bluetooth-active")
            bt("--timeout", "10", "scan", "on", timeout=15)
            continue
        if i == 1:
            bt("power", "off")
            avisar("Bluetooth", "Apagado", "bluetooth-disabled")
            return
        if i == 2:
            ejecutar(["setsid", "-f", "blueman-manager"])
            return

        if submenu(lista[i - len(fijas)]) == "volver":
            continue
        return


if __name__ == "__main__":
    main()
