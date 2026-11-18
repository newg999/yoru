#!/usr/bin/env python3
# ----------------------------------------------------------------------------
#  gestor-archivos-dbus.py — «Mostrar en la carpeta» → el gestor predeterminado
#
#  Navegadores y otras apps no miran qué gestor de archivos está por defecto:
#  llaman por D-Bus a org.freedesktop.FileManager1 («enséñame este archivo»),
#  y ese nombre solo lo ofrece Nautilus. Este servicio lo ofrece en su lugar
#  y pasa cada petición a archivos.sh, que abre la app de «Carpetas»
#  (Ajustes › Apps). D-Bus lo arranca al hacer falta
#  (system/dbus/org.freedesktop.FileManager1.service) y se cierra solo
#  tras un minuto sin peticiones.
# ----------------------------------------------------------------------------

import os
import signal
import subprocess

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

NOMBRE = "org.freedesktop.FileManager1"
RUTA = "/org/freedesktop/FileManager1"
ARCHIVOS = os.path.expanduser("~/.config/niri/scripts/archivos.sh")
ESPERA = 60   # segundos sin peticiones antes de cerrarse

_ARGS = '<arg type="as" name="URIs" direction="in"/><arg type="s" name="StartupId" direction="in"/>'
XML = f"""<node><interface name="{NOMBRE}">
  <method name="ShowFolders">{_ARGS}</method>
  <method name="ShowItems">{_ARGS}</method>
  <method name="ShowItemProperties">{_ARGS}</method>
</interface></node>"""

bucle = GLib.MainLoop()
temporizador = 0


def rearmar():
    global temporizador
    if temporizador:
        GLib.source_remove(temporizador)
    temporizador = GLib.timeout_add_seconds(ESPERA, bucle.quit)


def ruta(uri):
    return Gio.File.new_for_uri(uri).get_path() or uri


def lanzar(*args):
    subprocess.Popen([ARCHIVOS, *args], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def llamada(_con, _remitente, _ruta, _interfaz, metodo, parametros, invocacion):
    uris, _ = parametros.unpack()
    vistas = set()
    for uri in uris:
        r = ruta(uri)
        if metodo == "ShowFolders":
            lanzar(r)
        else:
            # Varios archivos de la misma carpeta: una sola ventana
            carpeta = os.path.dirname(r)
            if carpeta not in vistas:
                vistas.add(carpeta)
                lanzar("--select", r)
    invocacion.return_value(None)
    rearmar()


def conectado(conexion, _nombre):
    info = Gio.DBusNodeInfo.new_for_xml(XML)
    conexion.register_object(RUTA, info.interfaces[0], llamada, None, None)


signal.signal(signal.SIGCHLD, signal.SIG_IGN)   # sin procesos zombi
Gio.bus_own_name(Gio.BusType.SESSION, NOMBRE, Gio.BusNameOwnerFlags.NONE,
                 conectado, None, lambda *_: bucle.quit())
rearmar()
bucle.run()
