#!/usr/bin/env python3
"""
bluetooth.py — Menú de bluetooth con rofi + bluetoothctl

  · Encender / apagar el bluetooth
  · Lista tus dispositivos; los conectados salen en verde
  · Conectar, desconectar, emparejar, confiar y olvidar
  · Buscar dispositivos nuevos: la lista se va llenando en directo mientras
    busca; pulsa el tuyo en cuanto aparezca y se empareja y conecta solo
  · Batería de los dispositivos que la informan (auriculares, ratones...)

Atajo: Mod+Alt+B   ·   Clic en el icono de bluetooth de la barra
"""

import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from rofimenu import ejecutar, menu, menu_en_vivo, avisar, escapar  # noqa: E402

BT_ON = "\U000f00af"
BT_OFF = "\U000f00b2"
BUSCAR = ""
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
BATERIA = "\U000f0079"
SEGUNDOS_BUSQUEDA = 60


def bt(*args, timeout=15):
    return ejecutar(["bluetoothctl", *args], timeout=timeout)


def encendido():
    _, salida = bt("show")
    return "Powered: yes" in salida


def macs_y_nombres():
    """[(mac, nombre)] de `bluetoothctl devices`, sin los que no tienen nombre."""
    _, salida = bt("devices")
    lista = []
    for linea in salida.splitlines():
        partes = linea.split(" ", 2)
        if len(partes) < 3 or partes[0] != "Device":
            continue
        # Sin nombre, bluetoothctl pone la MAC con guiones: son balizas y
        # aparatos ajenos que solo ensucian la lista
        if partes[2].replace("-", ":") == partes[1]:
            continue
        lista.append((partes[1], partes[2]))
    return lista


def info(mac, nombre):
    _, salida = bt("info", mac)
    datos = {}
    for l in salida.splitlines():
        if ":" in l:
            k, v = l.strip().split(":", 1)
            datos[k.strip()] = v.strip()
    bateria = re.search(r"\((\d+)\)", datos.get("Battery Percentage", ""))
    return {
        "mac": mac,
        "nombre": datos.get("Alias", nombre),
        "conectado": datos.get("Connected") == "yes",
        "emparejado": datos.get("Paired") == "yes",
        "confiado": datos.get("Trusted") == "yes",
        "icono": ICONOS.get(datos.get("Icon", ""), ICONO_GENERICO),
        "bateria": int(bateria.group(1)) if bateria else None,
    }


def dispositivos():
    """Tus dispositivos: los emparejados y los conectados (no todo lo que ronda cerca)."""
    lista = [info(mac, nombre) for mac, nombre in macs_y_nombres()]
    lista = [d for d in lista if d["emparejado"] or d["conectado"]]
    # Conectados primero, luego emparejados, luego el resto
    return sorted(lista, key=lambda d: (not d["conectado"], not d["emparejado"], d["nombre"].lower()))


def hay_adaptador():
    _, salida = bt("list")
    return "Controller" in salida


def encender():
    ejecutar(["rfkill", "unblock", "bluetooth"])
    # Tras desbloquearlo, el adaptador tarda unos segundos en volver a
    # aparecer (carga su firmware). Si le pedimos "power on" antes, falla con
    # "No default controller available".
    for _ in range(40):
        if hay_adaptador():
            break
        time.sleep(0.25)
    for _ in range(5):
        codigo, salida = bt("power", "on")
        if codigo == 0:
            return
        time.sleep(0.5)
    avisar("Bluetooth", f"No se pudo encender\n{salida[-150:]}", urgente=True)


def accion(texto, *args, timeout=25):
    avisar("Bluetooth", f"{texto}…", "bluetooth-active")
    codigo, salida = bt(*args, timeout=timeout)
    return codigo == 0, salida


def emparejar_y_conectar(d):
    """Emparejar + confiar + conectar, con un solo aviso de progreso."""
    avisar("Bluetooth", f"Conectando {d['nombre']}…", "bluetooth-active")
    if not d["emparejado"]:
        codigo, _ = bt("pair", d["mac"], timeout=40)
        if codigo != 0:
            avisar("Bluetooth", f"No se pudo emparejar {d['nombre']}.\n"
                                "¿Está en modo emparejamiento?", urgente=True)
            return
        bt("trust", d["mac"])
    codigo, _ = bt("connect", d["mac"], timeout=25)
    if codigo == 0:
        avisar("Bluetooth", f"{d['nombre']} conectado", "bluetooth-active")
    else:
        avisar("Bluetooth", f"No se pudo conectar {d['nombre']}", urgente=True)


def buscar_nuevos():
    """Menú que se llena en directo con lo que va apareciendo."""
    escaneo = subprocess.Popen(["bluetoothctl", "--timeout", str(SEGUNDOS_BUSQUEDA), "scan", "on"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    encontrados = []
    conocidos = {d["mac"] for d in dispositivos()}

    def fuente():
        fin = time.time() + SEGUNDOS_BUSQUEDA
        while time.time() < fin:
            for mac, nombre in macs_y_nombres():
                if mac in conocidos:
                    continue
                conocidos.add(mac)
                d = info(mac, nombre)
                encontrados.append(d)
                yield f"{d['icono']}  {escapar(d['nombre'])}"
            time.sleep(1)

    try:
        i, _ = menu_en_vivo(f"{BUSCAR} ", [f"{VOLVER}  Volver"], fuente(),
                            mensaje="<b>Buscando…</b> pon tu dispositivo en modo emparejamiento\n"
                                    "<span alpha='60%'>irán apareciendo aquí; pulsa el tuyo</span>")
    finally:
        escaneo.terminate()
        bt("scan", "off")
    if i is None:
        return None
    if i == 0:
        return "volver"
    emparejar_y_conectar(encontrados[i - 1])
    return None


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
        emparejar_y_conectar(d)
    elif a == "desconectar":
        ok, _ = accion(f"Desconectando {d['nombre']}", "disconnect", mac)
        avisar("Bluetooth", f"{d['nombre']} desconectado" if ok else "No se pudo desconectar")
    elif a == "emparejar":
        ok, _ = accion(f"Emparejando {d['nombre']}", "pair", mac, timeout=40)
        if ok:
            bt("trust", mac)
        avisar("Bluetooth", f"{d['nombre']} emparejado" if ok else "No se pudo emparejar. ¿Está en modo emparejamiento?",
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
            i = menu(f"{BT_OFF} ", [f"{BT_ON}  Encender bluetooth"],
                     mensaje="El bluetooth está <b>apagado</b>")
            if i == 0:
                encender()
                continue
            return

        lista = dispositivos()
        fijas = [f"{BUSCAR}  Conectar un dispositivo nuevo", f"{BT_OFF}  Apagar bluetooth"]
        filas, activos = [], []
        for d in lista:
            texto = f"{d['icono']}  {escapar(d['nombre'])}"
            if d["conectado"]:
                texto += "  <span alpha='70%' size='small'>conectado</span>"
                if d["bateria"] is not None:
                    texto += f"  <span alpha='70%' size='small'>{BATERIA} {d['bateria']}%</span>"
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
            if buscar_nuevos() == "volver":
                continue
            return
        if i == 1:
            bt("power", "off")
            avisar("Bluetooth", "Apagado", "bluetooth-disabled")
            return

        if submenu(lista[i - len(fijas)]) == "volver":
            continue
        return


if __name__ == "__main__":
    main()
