#!/usr/bin/env python3
# ============================================================================
#  generar.py — Las imágenes del arranque de Yoru (GRUB y Plymouth)
# ----------------------------------------------------------------------------
#  El logo es el 夜 de pincel con su sello, el mismo que fastfetch en kitty
#  (config/fastfetch/yoru-pincel.png y yoru-sello.png), y los recuadros
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
PINCEL = REPO / "config/fastfetch/yoru-pincel.png"
SELLO = REPO / "config/fastfetch/yoru-sello.png"
PLYMOUTH = REPO / "system/plymouth/yoru"
GRUB = REPO / "system/grub/yoru"
# Los iconos del menú de GRUB salen de la Nerd Font (la instala install.sh)
NERD = Path.home() / ".local/share/fonts/JetBrainsMonoNerd/JetBrainsMonoNerdFont-Regular.ttf"

# La paleta de tema/blanco.json
BLANCO = "#ffffff"
FONDO = "#1a1b1e"
FONDO2 = "#26272b"
VELO = "#111214"

def magick(*args, entrada=None):
    # Sin fechas ni metadatos: si la imagen no cambia, el archivo tampoco
    # (install.sh compara los de Plymouth para no rehacer el initramfs)
    *resto, salida = args
    subprocess.run(["magick", *resto, "-strip", "-define", "png:exclude-chunks=date,time", salida],
                   input=entrada, check=True)


def logo(destino, ancho=246, alto=222):
    """El 夜 de pincel en blanco con su sello rojo, como el de fastfetch en
    kitty (tema/aplicar.py), centrado en un lienzo de ancho×alto"""
    magick(PINCEL, SELLO, "-gravity", "southeast", "-geometry", "+4+8",
           "-compose", "over", "-composite",
           "-resize", f"{ancho}x{alto}", "-background", "none", "-gravity", "center",
           "-extent", f"{ancho}x{alto}", f"png32:{destino}")


def caja(destino, prefijo, lado, radio, relleno, borde=None, grosor=0):
    """Un recuadro redondeado partido en 9 trozos, como los pide GRUB
    (prefijo_nw.png, prefijo_n.png... prefijo_c.png): las esquinas se
    quedan como están y los lados se estiran. Se dibuja a 4 veces el tamaño
    y se reduce, para que las esquinas salgan suaves."""
    total, x4 = lado * 3, 4
    tmp = destino / f"{prefijo}_entero.png"
    m = grosor * x4 / 2
    dibujo = ["-fill", relleno]
    dibujo += ["-stroke", borde, "-strokewidth", str(grosor * x4)] if borde else ["-stroke", "none"]
    fin = total * x4 - 1 - m
    magick("-size", f"{total * x4}x{total * x4}", "xc:none", *dibujo,
           "-draw", f"roundrectangle {m},{m} {fin},{fin} {radio * x4},{radio * x4}",
           "-resize", f"{total}x{total}", f"png32:{tmp}")
    trozos = {"nw": (0, 0), "n": (1, 0), "ne": (2, 0),
              "w": (0, 1), "c": (1, 1), "e": (2, 1),
              "sw": (0, 2), "s": (1, 2), "se": (2, 2)}
    for nombre, (cx, cy) in trozos.items():
        magick(tmp, "-crop", f"{lado}x{lado}+{cx * lado}+{cy * lado}", "+repage",
               f"png32:{destino / f'{prefijo}_{nombre}.png'}")
    tmp.unlink()


def icono(destino, glifo, lado=32):
    """Un icono de la Nerd Font, blanco y centrado en un cuadrado"""
    magick("-background", "none", "-fill", "#e5e9f0", "-font", str(NERD),
           "-pointsize", str(lado * 0.8), f"label:{glifo}",
           "-gravity", "center", "-extent", f"{lado}x{lado}", f"png32:{destino}")


def main():
    PLYMOUTH.mkdir(parents=True, exist_ok=True)
    GRUB.mkdir(parents=True, exist_ok=True)

    # --- Plymouth: el logo, el punto que late debajo y la caja de la contraseña
    logo(PLYMOUTH / "logo.png")
    magick("-size", "12x12", "xc:none", "-fill", BLANCO, "-draw", "circle 6,6 6,1.5",
           f"png32:{PLYMOUTH / 'punto.png'}")
    magick("-size", "320x48", "xc:none", "-fill", "rgba(255,255,255,0.06)",
           "-stroke", "rgba(255,255,255,0.80)", "-strokewidth", "2",
           "-draw", "roundrectangle 1,1 318,46 10,10", f"png32:{PLYMOUTH / 'caja.png'}")

    # --- GRUB: logo más pequeño, fondo y recuadros
    logo(GRUB / "logo.png")
    # Degradado suave de arriba abajo, igual que el de Plymouth. GRUB lo estira
    # a la pantalla, así que da igual su tamaño
    magick("-size", "64x360", f"gradient:{FONDO}-{VELO}", f"png24:{GRUB / 'fondo.png'}")
    # El menú: como las islas de la barra (oscuro translúcido, borde tenue)
    caja(GRUB, "menu", 20, 18, "rgba(26,27,30,0.60)", "rgba(255,255,255,0.12)", 1)
    # La opción elegida: una fila resaltada, como en los paneles. GRUB la
    # dibuja por FUERA de la fila, tanto como miden las esquinas: si crecen,
    # hay que subir item_spacing en theme.txt (o tapa la fila de al lado)
    caja(GRUB, "select", 8, 8, "rgba(255,255,255,0.12)")
    # La consola (teclas c y e): sin recuadro. GRUB también la saca unos
    # segundos al arrancar un sistema, y así solo se ve el fondo (el mismo
    # que el de Plymouth) en vez de un recuadro vacío
    caja(GRUB, "terminal_box", 16, 14, "none")

    # Iconos de cada entrada: GRUB elige por la «clase» de la entrada
    # (Fedora pone «kernel» o «fedora»; os-prober, «windows»; la de la BIOS, «efi»)
    iconos = GRUB / "icons"
    iconos.mkdir(exist_ok=True)
    for nombre, glifo in {"fedora": "\uf30a", "kernel": "\uf30a", "windows": "\uf17a",
                          "gnu-linux": "\uf17c", "efi": "\uf013"}.items():
        icono(iconos / f"{nombre}.png", glifo)
    print("Imágenes generadas en", PLYMOUTH.relative_to(REPO), "y", GRUB.relative_to(REPO))


if __name__ == "__main__":
    main()
