#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  vpn.py — Las VPN de NetworkManager para comun/Vpn.qml
#
#    vpn.py leer                  JSON: [{nombre, uuid, tipo, estado}]
#    vpn.py conectar <uuid>
#    vpn.py desconectar <uuid>
#    vpn.py borrar <uuid>
#    vpn.py buscar                JSON: archivos de VPN en tu carpeta personal
#    vpn.py importar <ruta> <nombre>
#
#  Vale para WireGuard (.conf) y OpenVPN (.ovpn). Al importar, la VPN queda
#  sin conexión automática, y si manda TODO el tráfico por el túnel
#  (AllowedIPs con 0.0.0.0/0), también manda por él las preguntas de DNS: si
#  no, seguirían yendo al router de la red en la que estés.
# ----------------------------------------------------------------------------

import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

TIPOS = {"wireguard": "WireGuard", "vpn": "VPN"}   # «vpn» = plugins (OpenVPN...)


def nmcli(*args):
    r = subprocess.run(["nmcli", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit((r.stderr or r.stdout).strip().removeprefix("Error: ") or "nmcli ha fallado")
    return r.stdout


def campos(linea):
    """Separa una línea de «nmcli -t» (los «:» de dentro van como «\\:»)."""
    return [c.replace("\\:", ":").replace("\\\\", "\\") for c in re.split(r"(?<!\\):", linea)]


def leer():
    activas = {}
    for linea in nmcli("-t", "-f", "UUID,STATE", "connection", "show", "--active").splitlines():
        uuid, estado = campos(linea)[:2]
        activas[uuid] = "activa" if estado == "activated" else "activando"
    lista = []
    for linea in nmcli("-t", "-f", "NAME,UUID,TYPE", "connection", "show").splitlines():
        nombre, uuid, tipo = campos(linea)[:3]
        if tipo in TIPOS:
            lista.append({"nombre": nombre, "uuid": uuid, "tipo": TIPOS[tipo],
                          "estado": activas.get(uuid, "")})
    print(json.dumps(sorted(lista, key=lambda v: v["nombre"].lower()), ensure_ascii=False))


def tipo_de(ruta):
    if ruta.lower().endswith(".ovpn"):
        return "openvpn"
    try:
        with open(ruta, errors="replace") as f:
            texto = f.read(20000)
    except OSError:
        return None
    if "[Interface]" in texto and "[Peer]" in texto:
        return "wireguard"
    if re.search(r"^\s*(client|remote)\b", texto, re.M):
        return "openvpn"
    return None


def buscar():
    casa = os.path.expanduser("~")
    vistos, archivos = set(), []
    for patron in ("*.conf", "*.ovpn", "*/*.conf", "*/*.ovpn"):
        for ruta in glob.glob(os.path.join(casa, patron)):
            if ruta in vistos or os.path.getsize(ruta) > 200000:
                continue
            vistos.add(ruta)
            tipo = tipo_de(ruta)
            if tipo:
                archivos.append({"ruta": ruta, "archivo": os.path.basename(ruta),
                                 "carpeta": os.path.dirname(ruta).replace(casa, "~", 1),
                                 "tipo": "WireGuard" if tipo == "wireguard" else "OpenVPN",
                                 "fecha": os.path.getmtime(ruta)})
    archivos.sort(key=lambda a: -a["fecha"])
    print(json.dumps(archivos[:8], ensure_ascii=False))


def importar(ruta, nombre):
    ruta = os.path.expanduser(ruta.strip())
    nombre = nombre.strip()
    if not os.path.isfile(ruta):
        sys.exit("No encuentro ese archivo")
    tipo = tipo_de(ruta)
    if not tipo:
        sys.exit("No parece una VPN de WireGuard (.conf) ni de OpenVPN (.ovpn)")
    if not nombre:
        sys.exit("Ponle un nombre")
    existentes = [campos(l)[0] for l in nmcli("-t", "-f", "NAME", "connection", "show").splitlines()]
    if nombre in existentes:
        sys.exit("Ya hay una conexión llamada «%s»" % nombre)

    # NetworkManager toma el nombre del archivo como nombre de la interfaz
    # (máx. 15 letras y números), así que se importa una copia bien llamada
    interfaz = re.sub(r"[^a-z0-9]", "", nombre.lower())[:15] or "vpn"
    extension = ".conf" if tipo == "wireguard" else ".ovpn"
    temporal = tempfile.mkdtemp(dir=os.environ.get("XDG_RUNTIME_DIR"))
    try:
        copia = os.path.join(temporal, interfaz + extension)
        shutil.copyfile(ruta, copia)
        os.chmod(copia, 0o600)
        salida = nmcli("connection", "import", "type", tipo, "file", copia)
    finally:
        shutil.rmtree(temporal, ignore_errors=True)
    m = re.search(r"\(([0-9a-f-]{36})\)", salida)
    if not m:
        sys.exit("Importada, pero no sé con qué nombre: mírala en nm-connection-editor")
    uuid = m.group(1)

    cambios = ["connection.id", nombre, "connection.autoconnect", "no"]
    if tipo == "wireguard":
        with open(ruta, errors="replace") as f:
            permitidas = " ".join(re.findall(r"^\s*AllowedIPs\s*=\s*(.*)$", f.read(), re.M))
        if "0.0.0.0/0" in permitidas or "::/0" in permitidas:
            for familia in ("ipv4", "ipv6"):
                dominios = nmcli("-g", familia + ".dns-search", "connection", "show", uuid).strip()
                dominios = [d for d in dominios.split(",") if d] + ["~."]
                cambios += [familia + ".dns-search", ",".join(dominios), familia + ".dns-priority", "-50"]
    nmcli("connection", "modify", uuid, *cambios)
    print(uuid)


if __name__ == "__main__":
    orden, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    if orden == "leer":
        leer()
    elif orden == "buscar":
        buscar()
    elif orden == "conectar" and args:
        nmcli("connection", "up", args[0])
    elif orden == "desconectar" and args:
        nmcli("connection", "down", args[0])
    elif orden == "borrar" and args:
        nmcli("connection", "delete", args[0])
    elif orden == "importar" and len(args) == 2:
        importar(*args)
    else:
        sys.exit("vpn.py leer | buscar | conectar|desconectar|borrar <uuid> | importar <ruta> <nombre>")
