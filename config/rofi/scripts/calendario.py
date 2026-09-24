#!/usr/bin/env python3
"""
calendario.py — Calendario mensual con rofi

  · Muestra el mes con el día de hoy resaltado
  · Navega entre meses (también con las flechas ← → del teclado)
  · Abre la app Calendario de GNOME para ver/crear eventos

Atajo: Mod+Alt+C   ·   Clic en el reloj de la barra
"""

import calendar
import datetime
import locale
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from rofimenu import ejecutar  # noqa: E402

# Colores Nord
ACENTO = "#88c0d0"
TENUE = "#4c566a"
FINDE = "#81a1c1"
FONDO = "#2e3440"

ANTERIOR, SIGUIENTE, HOY, APP = "", "", "󰃶", ""

MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
DIAS = ["lu", "ma", "mi", "ju", "vi", "sá", "do"]
DIAS_LARGOS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]


def cuadricula(anio, mes, hoy):
    """Devuelve el mes en marcado Pango (monoespaciado)."""
    cal = calendar.Calendar(firstweekday=0)  # la semana empieza en lunes
    lineas = []

    titulo = f"{MESES[mes - 1].capitalize()} {anio}"
    lineas.append(f"<span weight='bold' foreground='{ACENTO}'>{titulo}</span>")
    lineas.append("")
    lineas.append("<span foreground='{}'>{}</span>".format(
        TENUE, "  ".join(f"{d:>2}" for d in DIAS)))

    for semana in cal.monthdatescalendar(anio, mes):
        celdas = []
        for dia in semana:
            num = f"{dia.day:>2}"
            if dia.month != mes:
                celdas.append(f"<span foreground='{TENUE}' alpha='50%'>{num}</span>")
            elif dia == hoy:
                celdas.append(f"<span background='{ACENTO}' foreground='{FONDO}' weight='bold'>{num}</span>")
            elif dia.weekday() >= 5:
                celdas.append(f"<span foreground='{FINDE}'>{num}</span>")
            else:
                celdas.append(num)
        lineas.append("  ".join(celdas))
    return "\n".join(lineas)


def main():
    try:
        locale.setlocale(locale.LC_TIME, "")
    except locale.Error:
        pass

    hoy = datetime.date.today()
    anio, mes = hoy.year, hoy.month
    tema = ("window { width: 420px; } listview { lines: 4; } "
            "inputbar { enabled: false; } message { padding: 14px 18px; } "
            "textbox { horizontal-align: 0.5; }")
    # Flechas del teclado para cambiar de mes (-kb-custom-1/2 → código 10/11)
    teclas = ["-kb-custom-1", "Left", "-kb-custom-2", "Right",
              "-kb-move-char-back", "", "-kb-move-char-forward", ""]

    while True:
        ahora = datetime.datetime.now()
        cabecera = (f"<span foreground='{ACENTO}' weight='bold'>{ahora:%H:%M}</span>  ·  "
                    f"{DIAS_LARGOS[hoy.weekday()].capitalize()} {hoy.day} de {MESES[hoy.month - 1]}\n\n")
        mensaje = cabecera + cuadricula(anio, mes, hoy)
        opciones = [f"{ANTERIOR}  Mes anterior", f"{SIGUIENTE}  Mes siguiente",
                    f"{HOY}  Volver a hoy", f"{APP}  Abrir Calendario (eventos)"]

        r = subprocess.run(["rofi", "-dmenu", "-i", "-no-custom", "-format", "i",
                            "-p", "", "-mesg", mensaje, "-theme-str", tema,
                            "-selected-row", "1", *teclas],
                           input="\n".join(opciones), capture_output=True, text=True)
        salida = r.stdout.strip()

        if r.returncode == 10:
            eleccion = 0
        elif r.returncode == 11:
            eleccion = 1
        elif r.returncode != 0 or salida == "":
            return
        else:
            eleccion = int(salida)

        if eleccion == 0:
            mes -= 1
            if mes == 0:
                anio, mes = anio - 1, 12
        elif eleccion == 1:
            mes += 1
            if mes == 13:
                anio, mes = anio + 1, 1
        elif eleccion == 2:
            anio, mes = hoy.year, hoy.month
        elif eleccion == 3:
            ejecutar(["setsid", "-f", "gnome-calendar"])
            return


if __name__ == "__main__":
    main()
