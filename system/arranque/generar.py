#!/usr/bin/env python3
# ============================================================================
#  generar.py — Las imágenes del arranque de Yoru (GRUB y Plymouth)
# ----------------------------------------------------------------------------
#  Dibuja el logo 夜 a partir del mismo dibujo que fastfetch
#  (config/fastfetch/yoru.txt), así los tres se ven iguales, y los recuadros
#  del menú de GRUB con el estilo de los paneles. Las imágenes que genera
#  están en el repositorio: solo hace falta volver a ejecutarlo si cambias
#  el dibujo, los colores o las medidas de aquí.
#
#    python3 system/arranque/generar.py
#
#  Necesita ImageMagick (magick).
# ============================================================================

import subprocess
from pathlib import Path

AQUI = Path(__file__).resolve().parent
REPO = AQUI.parent.parent
DIBUJO = REPO / "config/fastfetch/yoru.txt"
PLYMOUTH = REPO / "system/plymouth/yoru"
GRUB = REPO / "system/grub/yoru"
FUENTE = "/usr/share/fonts/jetbrains-mono-fonts/JetBrainsMono-Regular.otf"

# La paleta de tema/blanco.json
BLANCO = "#ffffff"
GRIS = "#8a8f98"
FONDO = "#1a1b1e"
FONDO2 = "#26272b"
VELO = "#111214"

# Los caracteres de bloque del dibujo, por cuartos de celda:
# arriba-izquierda, arriba-derecha, abajo-izquierda, abajo-derecha
CUARTOS = {
    "█": "1111", "▀": "1100", "▄": "0011", "▌": "1010", "▐": "0101",
    "▘": "1000", "▝": "0100", "▖": "0010", "▗": "0001",
    "▙": "1011", "▛": "1110", "▜": "1101", "▟": "0111",
    "▚": "1001", "▞": "0110",
}


def magick(*args, entrada=None):
    subprocess.run(["magick", *args], input=entrada, check=True)


def leer_dibujo():
    """Las líneas del dibujo como [(carácter, color)], sin la de «よ る · yoru»."""
    filas = []
    for linea in DIBUJO.read_text().splitlines():
        if "よ" in linea:
            break
        fila, color = [], BLANCO
        i = 0
        while i < len(linea):
            if linea[i] == "$" and i + 1 < len(linea) and linea[i + 1] in "12":
                color = BLANCO if linea[i + 1] == "1" else GRIS
                i += 2
                continue
            fila.append((linea[i], color))
            i += 1
        filas.append(fila)
    return filas


def logo(destino, celda, texto=True):
    """El 夜 con sus estrellas. celda = ancho de un carácter en píxeles (par);
    el alto es el doble, como en la terminal."""
    filas = leer_dibujo()
    ancho_c, alto_c = celda, celda * 2
    columnas = max(len(f) for f in filas)
    ancho = columnas * ancho_c
    alto_dibujo = len(filas) * alto_c
    hueco_texto = celda * 5 if texto else 0
    alto = alto_dibujo + hueco_texto

    mvg = [f"viewbox 0 0 {ancho} {alto}", "stroke none"]
    for y, fila in enumerate(filas):
        for x, (c, color) in enumerate(fila):
            x0, y0 = x * ancho_c, y * alto_c
            if c in CUARTOS:
                mvg.append(f"fill '{color}'")
                for n, (dx, dy) in enumerate([(0, 0), (1, 0), (0, 1), (1, 1)]):
                    if CUARTOS[c][n] == "1":
                        qx, qy = x0 + dx * ancho_c / 2, y0 + dy * alto_c / 2
                        mvg.append(f"rectangle {qx},{qy} {qx + ancho_c / 2 - 0.01},{qy + alto_c / 2 - 0.01}")
            elif c == "✦":
                # Estrella de cuatro puntas, centrada en la celda
                cx, cy, r, r2 = x0 + ancho_c / 2, y0 + alto_c / 2, celda * 0.8, celda * 0.18
                puntos = [(cx, cy - r), (cx + r2, cy - r2), (cx + r, cy), (cx + r2, cy + r2),
                          (cx, cy + r), (cx - r2, cy + r2), (cx - r, cy), (cx - r2, cy - r2)]
                mvg.append(f"fill '{color}'")
                mvg.append("polygon " + " ".join(f"{px:.2f},{py:.2f}" for px, py in puntos))
            elif c == "·":
                cx, cy = x0 + ancho_c / 2, y0 + alto_c / 2
                mvg.append(f"fill '{color}'")
                mvg.append(f"circle {cx},{cy} {cx + celda * 0.22},{cy}")

    magick("-size", f"{ancho}x{alto}", "xc:none", "-draw", "@-", f"png32:{destino}",
           entrada="\n".join(mvg).encode())
    if texto:
        # «y o r u» debajo, en gris y espaciado, como en fastfetch
        magick(destino, "-font", FUENTE, "-pointsize", str(celda * 2.4), "-fill", GRIS,
               "-kerning", str(celda * 0.9), "-gravity", "south",
               "-annotate", f"+0+{celda * 0.6}", "y o r u", f"png32:{destino}")


def caja(destino, prefijo, lado, radio, relleno, borde=None, grosor=0):
    """Un recuadro redondeado partido en 9 trozos, como los pide GRUB
    (prefijo_nw.png, prefijo_n.png... prefijo_c.png): las esquinas se
    quedan como están y los lados se estiran."""
    total = lado * 3
    tmp = destino / f"{prefijo}_entero.png"
    m = grosor / 2
    dibujo = ["-fill", relleno]
    dibujo += ["-stroke", borde, "-strokewidth", str(grosor)] if borde else ["-stroke", "none"]
    magick("-size", f"{total}x{total}", "xc:none", *dibujo,
           "-draw", f"roundrectangle {m},{m} {total - 1 - m},{total - 1 - m} {radio},{radio}",
           f"png32:{tmp}")
    trozos = {"nw": (0, 0), "n": (1, 0), "ne": (2, 0),
              "w": (0, 1), "c": (1, 1), "e": (2, 1),
              "sw": (0, 2), "s": (1, 2), "se": (2, 2)}
    for nombre, (cx, cy) in trozos.items():
        magick(tmp, "-crop", f"{lado}x{lado}+{cx * lado}+{cy * lado}", "+repage",
               f"png32:{destino / f'{prefijo}_{nombre}.png'}")
    tmp.unlink()


def main():
    PLYMOUTH.mkdir(parents=True, exist_ok=True)
    GRUB.mkdir(parents=True, exist_ok=True)

    # --- Plymouth: el logo, el punto que late debajo y la caja de la contraseña
    logo(PLYMOUTH / "logo.png", 6)
    magick("-size", "12x12", "xc:none", "-fill", BLANCO, "-draw", "circle 6,6 6,1.5",
           f"png32:{PLYMOUTH / 'punto.png'}")
    magick("-size", "320x48", "xc:none", "-fill", "rgba(255,255,255,0.06)",
           "-stroke", "rgba(255,255,255,0.80)", "-strokewidth", "2",
           "-draw", "roundrectangle 1,1 318,46 10,10", f"png32:{PLYMOUTH / 'caja.png'}")

    # --- GRUB: logo más pequeño, fondo y recuadros
    logo(GRUB / "logo.png", 6)
    # Degradado suave de arriba abajo, igual que el de Plymouth. GRUB lo estira
    # a la pantalla, así que da igual su tamaño
    magick("-size", "64x360", f"gradient:{FONDO}-{VELO}", f"png24:{GRUB / 'fondo.png'}")
    # El menú: como los paneles (oscuro, borde blanco de 2 px, esquinas de 14)
    caja(GRUB, "menu", 16, 14, FONDO2, "rgba(255,255,255,0.80)", 2)
    # La opción elegida: como una fila resaltada de los paneles
    caja(GRUB, "select", 12, 10, "rgba(255,255,255,0.12)")
    # La consola de edición (tecla e): el mismo recuadro que el menú
    caja(GRUB, "terminal_box", 16, 14, FONDO2, "rgba(255,255,255,0.80)", 2)
    print("Imágenes generadas en", PLYMOUTH.relative_to(REPO), "y", GRUB.relative_to(REPO))


if __name__ == "__main__":
    main()
