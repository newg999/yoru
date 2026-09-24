"""
rofimenu.py — Utilidades compartidas por los menús (wifi, bluetooth, calendario)

No se ejecuta solo: los otros scripts lo importan.
"""

import subprocess

# Tamaño de los menús pequeños (se suma al tema nord.rasi)
TEMA_MENU = "window { width: 460px; } listview { lines: 9; } inputbar { children: [ prompt ]; }"


def ejecutar(cmd, timeout=None):
    """Ejecuta un comando y devuelve (código, salida). Nunca lanza excepción."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except FileNotFoundError:
        return 127, f"No encontrado: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return 124, "Tiempo de espera agotado"


def menu(prompt, opciones, mensaje=None, activos=(), urgentes=(), tema=TEMA_MENU,
         buscar=False, fila=0):
    """
    Muestra un menú de rofi y devuelve el ÍNDICE elegido (o None si se cancela).

    opciones : lista de textos (admiten marcado Pango: <b>, <span>...)
    mensaje  : texto opcional encima de la lista
    activos  : índices que se pintan en verde (conectado, encendido...)
    urgentes : índices que se pintan en rojo
    buscar   : muestra el cuadro de búsqueda
    """
    cmd = ["rofi", "-dmenu", "-i", "-markup-rows", "-no-custom",
           "-format", "i", "-p", prompt, "-selected-row", str(fila)]
    if not buscar:
        tema += " inputbar { enabled: false; }"
    cmd += ["-theme-str", tema]
    if mensaje:
        cmd += ["-mesg", mensaje]
    if activos:
        cmd += ["-a", ",".join(str(i) for i in activos)]
    if urgentes:
        cmd += ["-u", ",".join(str(i) for i in urgentes)]

    r = subprocess.run(cmd, input="\n".join(opciones), capture_output=True, text=True)
    salida = r.stdout.strip()
    if r.returncode != 0 or salida == "":
        return None
    try:
        return int(salida)
    except ValueError:
        return None


def pedir_texto(prompt, mensaje=None, contrasena=False):
    """Pide un texto (o una contraseña) con rofi. Devuelve None si se cancela."""
    cmd = ["rofi", "-dmenu", "-p", prompt, "-theme-str",
           "window { width: 460px; } listview { enabled: false; } entry { placeholder: \"\"; }"]
    if contrasena:
        cmd.append("-password")
    if mensaje:
        cmd += ["-mesg", mensaje]
    r = subprocess.run(cmd, input="", capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return r.stdout.rstrip("\n")


def avisar(titulo, texto="", icono=None, urgente=False):
    """Notificación de escritorio (mako)."""
    cmd = ["notify-send", "-a", "Menús", titulo, texto]
    if icono:
        cmd += ["-i", icono]
    if urgente:
        cmd += ["-u", "critical"]
    ejecutar(cmd)


def escapar(texto):
    """Escapa &, < y > para que Pango no se rompa con nombres raros."""
    return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
