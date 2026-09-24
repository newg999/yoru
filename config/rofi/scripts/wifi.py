#!/usr/bin/env python3
"""
wifi.py — Menú de redes wifi con rofi + NetworkManager (nmcli)

  · Lista las redes con su señal; la conectada sale en verde
  · Conecta a redes nuevas pidiendo la contraseña
  · Desconectar, olvidar una red, buscar de nuevo, encender/apagar el wifi

Atajo: Mod+Alt+N   ·   Clic en el icono de red de la barra
"""

import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from rofimenu import ejecutar, menu, pedir_texto, avisar, escapar  # noqa: E402

# Iconos (JetBrainsMono Nerd Font)
SENAL = ["\U000f092f", "\U000f091f", "\U000f0922", "\U000f0925", "\U000f0928"]
CANDADO = ""
BUSCAR = ""
WIFI_ON = "\U000f05a9"
WIFI_OFF = "\U000f05aa"
AJUSTES = ""
VOLVER = ""
DESCONECTAR = ""
OLVIDAR = ""


def dividir(linea):
    """nmcli -t separa campos con ':' y escapa los ':' reales como '\\:'."""
    campos = re.split(r"(?<!\\):", linea)
    return [c.replace("\\:", ":").replace("\\\\", "\\") for c in campos]


def wifi_encendido():
    _, salida = ejecutar(["nmcli", "radio", "wifi"])
    return salida.strip() == "enabled"


def redes(reescanear="auto"):
    """Devuelve lista de dicts {ssid, senal, segura, conectada}, sin repetidas."""
    _, salida = ejecutar(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                          "device", "wifi", "list", "--rescan", reescanear], timeout=20)
    vistas = {}
    for linea in salida.splitlines():
        campos = dividir(linea)
        if len(campos) < 4 or not campos[1]:
            continue
        en_uso, ssid, senal, seguridad = campos[0], campos[1], campos[2], campos[3]
        red = {
            "ssid": ssid,
            "senal": int(senal) if senal.isdigit() else 0,
            "segura": seguridad not in ("", "--"),
            "conectada": en_uso.strip() == "*",
        }
        previa = vistas.get(ssid)
        if previa is None or red["conectada"] or (red["senal"] > previa["senal"] and not previa["conectada"]):
            vistas[ssid] = red
    return sorted(vistas.values(), key=lambda r: (not r["conectada"], -r["senal"]))


def guardadas():
    """Nombres de las conexiones wifi que ya tienen contraseña guardada."""
    _, salida = ejecutar(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"])
    nombres = set()
    for linea in salida.splitlines():
        campos = dividir(linea)
        if len(campos) >= 2 and campos[1] == "802-11-wireless":
            nombres.add(campos[0])
    return nombres


def icono_senal(senal):
    return SENAL[min(4, senal // 20)]


def conectar(red):
    ssid = red["ssid"]
    ya_guardada = ssid in guardadas()
    if ya_guardada:
        avisar("Wifi", f"Conectando a {ssid}…", "network-wireless")
        codigo, salida = ejecutar(["nmcli", "connection", "up", "id", ssid], timeout=45)
    elif red["segura"]:
        clave = pedir_texto(f"{CANDADO} ", mensaje=f"Contraseña de <b>{escapar(ssid)}</b>",
                            contrasena=True)
        if not clave:
            return
        avisar("Wifi", f"Conectando a {ssid}…", "network-wireless")
        codigo, salida = ejecutar(["nmcli", "device", "wifi", "connect", ssid,
                                   "password", clave], timeout=45)
    else:
        avisar("Wifi", f"Conectando a {ssid}…", "network-wireless")
        codigo, salida = ejecutar(["nmcli", "device", "wifi", "connect", ssid], timeout=45)

    if codigo == 0:
        avisar("Wifi", f"Conectado a {ssid}", "network-wireless")
        return

    if not ya_guardada and ssid in guardadas():
        # Contraseña incorrecta: NetworkManager deja creado un perfil que
        # fallaría siempre. Lo borramos para que la próxima vez la vuelva a pedir.
        ejecutar(["nmcli", "connection", "delete", "id", ssid])
        detalle = "¿Contraseña incorrecta? Inténtalo de nuevo."
    elif ya_guardada:
        # Quizá cambió la contraseña: ofrecemos volver a escribirla
        i = menu(f"{WIFI_OFF} ", [f"{CANDADO}  Escribir la contraseña de nuevo", f"{VOLVER}  Cancelar"],
                 mensaje=f"No se pudo conectar a <b>{escapar(ssid)}</b>")
        if i == 0:
            ejecutar(["nmcli", "connection", "delete", "id", ssid])
            conectar(red)
        return
    else:
        detalle = salida[-200:]
    avisar("Wifi", f"No se pudo conectar a {ssid}\n{detalle}",
           "network-wireless-offline", urgente=True)


def submenu_conectada(red):
    ssid = red["ssid"]
    opciones = [f"{DESCONECTAR}  Desconectar", f"{OLVIDAR}  Olvidar esta red", f"{VOLVER}  Volver"]
    i = menu(f"{WIFI_ON} ", opciones, mensaje=f"Conectado a <b>{escapar(ssid)}</b>")
    if i == 0:
        codigo, salida = ejecutar(["nmcli", "connection", "down", "id", ssid])
        avisar("Wifi", "Desconectado" if codigo == 0 else salida, "network-wireless-offline")
    elif i == 1:
        codigo, salida = ejecutar(["nmcli", "connection", "delete", "id", ssid])
        avisar("Wifi", f"Red {ssid} olvidada" if codigo == 0 else salida)
    elif i == 2:
        return "volver"
    return None


def main():
    reescanear = "auto"
    while True:
        if not wifi_encendido():
            i = menu(f"{WIFI_OFF} ", [f"{WIFI_ON}  Encender wifi", f"{AJUSTES}  Ajustes avanzados"],
                     mensaje="El wifi está <b>apagado</b>")
            if i == 0:
                ejecutar(["nmcli", "radio", "wifi", "on"])
                avisar("Wifi", "Encendido. Buscando redes…", "network-wireless")
                time.sleep(3)
                continue
            if i == 1:
                ejecutar(["setsid", "-f", "nm-connection-editor"])
            return

        lista = redes(reescanear)
        reescanear = "auto"
        fijas = [f"{BUSCAR}  Buscar redes", f"{WIFI_OFF}  Apagar wifi", f"{AJUSTES}  Ajustes avanzados"]
        filas = []
        activos = []
        for red in lista:
            texto = f"{icono_senal(red['senal'])}  {escapar(red['ssid'])}"
            if red["segura"]:
                texto += f"  <span alpha='55%'>{CANDADO}</span>"
            if red["conectada"]:
                texto += "  <span alpha='70%' size='small'>conectado</span>"
                activos.append(len(fijas) + len(filas))
            filas.append(texto)

        actual = next((r["ssid"] for r in lista if r["conectada"]), None)
        mensaje = (f"Conectado a <b>{escapar(actual)}</b>" if actual
                   else "Sin conexión · elige una red")
        i = menu(f"{WIFI_ON} ", fijas + filas, mensaje=mensaje, activos=activos,
                 buscar=True, fila=len(fijas) if filas else 0)

        if i is None:
            return
        if i == 0:
            avisar("Wifi", "Buscando redes…", "network-wireless")
            ejecutar(["nmcli", "device", "wifi", "rescan"])
            time.sleep(3)
            reescanear = "no"
            continue
        if i == 1:
            ejecutar(["nmcli", "radio", "wifi", "off"])
            avisar("Wifi", "Apagado", "network-wireless-offline")
            return
        if i == 2:
            ejecutar(["setsid", "-f", "nm-connection-editor"])
            return

        red = lista[i - len(fijas)]
        if red["conectada"]:
            if submenu_conectada(red) == "volver":
                continue
            return
        conectar(red)
        return


if __name__ == "__main__":
    main()
