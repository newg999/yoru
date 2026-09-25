"""
rofimenu.py — Utilidades compartidas por los menús (wifi, bluetooth, audio, calendario)

No se ejecuta solo: los otros scripts lo importan.
"""

import subprocess
import threading

# Los menús de la barra se abren arriba a la derecha, justo debajo de ella.
# Son los botones invisibles de tema.rasi los que lo colocan:
# barra 8 + 36 px + 8 de hueco (el mismo que entre islas) = 52 por arriba,
# y 12 por la derecha para alinearlo con el borde de la barra.
# (los botones son cajas de texto: su alto sale de la letra, no de height;
# por eso tienen letra diminuta en tema.rasi y el alto se da con padding)
ARRIBA_CENTRO = "button-arriba { expand: false; padding: 50px 0 0 0; } "
ARRIBA = ARRIBA_CENTRO + "button-derecha { expand: false; width: 12px; } "

# Tamaño de los menús pequeños (se suma al tema tema.rasi)
TEMA_MENU_CENTRO = "columna { width: 460px; } inputbar { children: [ prompt ]; }"
TEMA_MENU = ARRIBA + TEMA_MENU_CENTRO


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
         buscar=False, fila=0, max_lineas=9):
    """
    Muestra un menú de rofi y devuelve el ÍNDICE elegido (o None si se cancela).

    opciones : lista de textos (admiten marcado Pango: <b>, <span>...)
    mensaje  : texto opcional encima de la lista
    activos  : índices que se pintan en verde (conectado, encendido...)
    urgentes : índices que se pintan en rojo
    buscar   : muestra el cuadro de búsqueda
    max_lineas : filas visibles como mucho (la lista mide justo lo que ocupa)
    """
    cmd = ["rofi", "-dmenu", "-i", "-markup-rows", "-no-custom",
           "-format", "i", "-p", prompt, "-selected-row", str(fila)]
    tema += f" listview {{ lines: {max(1, min(len(opciones), max_lineas))}; }}"
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


def menu_en_vivo(prompt, fijas, fuente, mensaje=None, tema=TEMA_MENU, lineas=9):
    """
    Como menu(), pero la lista se va llenando mientras está abierta.

    fijas  : opciones que salen desde el principio (Volver...)
    fuente : generador que va dando textos nuevos; se para al cerrar el menú
    Devuelve (índice, lista de todos los textos mostrados) o (None, lista).
    """
    # Ojo: sin -no-custom ni -selected-row. Cualquiera de los dos hace que
    # rofi espere a leerlo todo antes de enseñar la ventana
    cmd = ["rofi", "-dmenu", "-i", "-markup-rows", "-format", "i",
           "-p", prompt, "-theme-str", tema + f" listview {{ lines: {lineas}; }}"
           " inputbar { enabled: false; }"]
    if mensaje:
        cmd += ["-mesg", mensaje]
    rofi = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    mostrados = list(fijas)

    def alimentar():
        try:
            rofi.stdin.write("".join(t + "\n" for t in fijas))
            rofi.stdin.flush()
            for texto in fuente:
                if rofi.poll() is not None:
                    break
                mostrados.append(texto)
                rofi.stdin.write(texto + "\n")
                rofi.stdin.flush()
        except (BrokenPipeError, ValueError):
            pass
        finally:
            try:
                rofi.stdin.close()
            except (BrokenPipeError, ValueError):
                pass

    hilo = threading.Thread(target=alimentar, daemon=True)
    hilo.start()
    salida = rofi.stdout.read().strip()
    rofi.wait()
    if rofi.returncode != 0 or not salida.isdigit():
        return None, mostrados
    return int(salida), mostrados


def pedir_texto(prompt, mensaje=None, contrasena=False, posicion=ARRIBA):
    """
    Pide un texto (o una contraseña) con rofi. Devuelve None si se cancela.
    posicion: ARRIBA (bajo la barra) o "" (centrado)
    """
    cmd = ["rofi", "-dmenu", "-p", prompt, "-theme-str",
           posicion + " columna { width: 460px; } listview { enabled: false; } entry { placeholder: \"\"; }"]
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
        # Categoría "error": borde rojo pero se va sola (ver mako/config).
        # "critical" se queda fija hasta hacer clic: solo para la batería y cosas así
        cmd += ["-c", "error"]
    ejecutar(cmd)


def escapar(texto):
    """Escapa &, < y > para que Pango no se rompa con nombres raros."""
    return texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
