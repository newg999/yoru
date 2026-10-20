#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  discos.py — Memorias USB, tarjetas y discos externos para comun/Discos.qml
#
#    discos.py leer               JSON: [{disco, path, nombre, tamano, montaje}]
#    discos.py montar <path>      lo monta (en /run/media/$USER/...)
#    discos.py expulsar <disco>   desmonta sus particiones y lo apaga
#    discos.py vigilar            se queda escuchando (lo lanza Discos.qml):
#                                 al conectar uno lo monta y avisa con
#                                 «Abrir» y «Expulsar»; escribe «cambio» en
#                                 cada conexión o desconexión
#
#  Todo con udisks (udisksctl), como hace GNOME: no hace falta ser root.
# ----------------------------------------------------------------------------

import json
import os
import subprocess
import sys
import threading
import time

ORDEN_LSBLK = ["lsblk", "-J", "-b", "-o", "NAME,PATH,LABEL,SIZE,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TRAN,MODEL,TYPE"]
MINIMO = 100_000_000   # 100 MB
NO_SE_MONTAN = {"swap", "crypto_LUKS", "LVM2_member", "linux_raid_member", None, ""}


def tamano(b):
    """En unidades de fábrica (1 GB = 1000 MB), como pone en la memoria."""
    for unidad in ("B", "KB", "MB", "GB"):
        if b < 1000:
            break
        b /= 1000
    else:
        unidad = "TB"
    return ("%.0f %s" if b >= 100 or unidad == "B" else "%.1f %s") % (b, unidad)


def volumenes():
    """Las particiones (o discos sin particiones) de los discos extraíbles."""
    datos = json.loads(subprocess.run(ORDEN_LSBLK, capture_output=True, text=True).stdout or "{}")
    lista = []
    for disco in datos.get("blockdevices", []):
        if disco["type"] != "disk" or not (disco["hotplug"] or disco["rm"]):
            continue
        if disco.get("tran") not in ("usb", "mmc", "ieee1394", None) or disco["size"] == 0:
            continue
        modelo = (disco.get("model") or "").strip() or "Disco externo"
        partes = [p for p in disco.get("children") or [disco] if p.get("fstype") not in NO_SE_MONTAN]
        # Las particiones pequeñas de arranque (la EFI de Ventoy, de un
        # instalador...) no interesan si el disco tiene otra de verdad
        if any(int(p["size"]) >= MINIMO for p in partes):
            partes = [p for p in partes if int(p["size"]) >= MINIMO]
        for p in partes:
            lista.append({
                "disco": disco["path"],
                "path": p["path"],
                "nombre": (p.get("label") or modelo).replace("\\x20", " "),
                "modelo": modelo,
                "tamano": tamano(int(p["size"])).replace(".", ","),
                "montaje": p.get("mountpoint") or "",
            })
    return lista


def udisks(*args):
    r = subprocess.run(["udisksctl", *args, "--no-user-interaction"], capture_output=True, text=True)
    if r.returncode != 0:
        error = (r.stderr or r.stdout).strip()
        if "busy" in error.lower() or "ocupado" in error.lower():
            error = "Está en uso: cierra lo que tengas abierto de él y vuelve a probar"
        raise RuntimeError(error.split("\n")[0].removeprefix("Error ") or "udisksctl ha fallado")
    return r.stdout


def montar(path):
    salida = udisks("mount", "-b", path)
    # «Mounted /dev/sdb1 at /run/media/don/USB»
    return salida.strip().split(" at ", 1)[-1].rstrip(".")


def expulsar(disco):
    for v in volumenes():
        if v["disco"] == disco and v["montaje"]:
            udisks("unmount", "-b", v["path"])
    # Apagarlo deja quitarlo con seguridad (algunos lectores no lo permiten:
    # entonces basta con haberlo desmontado)
    try:
        udisks("power-off", "-b", disco)
    except RuntimeError:
        pass


def avisar(titulo, texto, acciones=(), icono="drive-removable-media"):
    orden = ["notify-send", "-a", "Discos", "-i", icono]
    if acciones:
        orden.append("--wait")
        for clave, nombre in acciones:
            orden += ["-A", "%s=%s" % (clave, nombre)]
    r = subprocess.run(orden + [titulo, texto], capture_output=True, text=True)
    return r.stdout.strip()


def conectado(v):
    """Un volumen nuevo: se monta y se avisa (en su hilo: el aviso espera)."""
    try:
        if not v["montaje"]:
            v["montaje"] = montar(v["path"])
        print("cambio", flush=True)
    except RuntimeError as e:
        avisar("No se pudo abrir «%s»" % v["nombre"], str(e), icono="dialog-error")
        return
    eleccion = avisar("%s conectado" % v["nombre"], "%s · %s" % (v["tamano"], v["montaje"]),
                      [("abrir", "Abrir"), ("expulsar", "Expulsar")])
    if eleccion == "abrir":
        subprocess.Popen(["xdg-open", v["montaje"]], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif eleccion == "expulsar":
        try:
            expulsar(v["disco"])
            avisar("Ya puedes quitar «%s»" % v["nombre"], "Se ha expulsado sin perder nada")
        except RuntimeError as e:
            avisar("No se pudo expulsar «%s»" % v["nombre"], str(e), icono="dialog-error")
        print("cambio", flush=True)


def vigilar():
    vistos = {v["path"] for v in volumenes()}
    udev = subprocess.Popen(["udevadm", "monitor", "--udev", "--subsystem-match=block"],
                            stdout=subprocess.PIPE, text=True)
    for linea in udev.stdout:
        if " add " not in linea and " remove " not in linea and " change " not in linea:
            continue
        # Las particiones aparecen un momento después que el disco
        time.sleep(1.5)
        ahora = volumenes()
        nuevos = [v for v in ahora if v["path"] not in vistos]
        vistos = {v["path"] for v in ahora}
        for v in nuevos:
            threading.Thread(target=conectado, args=(v,), daemon=True).start()
        print("cambio", flush=True)


if __name__ == "__main__":
    orden, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    try:
        if orden == "leer":
            print(json.dumps(volumenes(), ensure_ascii=False))
        elif orden == "montar" and args:
            print(montar(args[0]))
        elif orden == "expulsar" and args:
            expulsar(args[0])
        elif orden == "vigilar":
            vigilar()
        else:
            sys.exit("discos.py leer | montar <path> | expulsar <disco> | vigilar")
    except RuntimeError as e:
        sys.exit(str(e))
