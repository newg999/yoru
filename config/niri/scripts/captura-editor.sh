#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  captura-editor.sh — Captura de una zona y la abre en swappy para editarla
#
#  Arrastra con el ratón para elegir la zona (Esc cancela). Swappy se abre
#  con la imagen para dibujar flechas, texto, rectángulos o difuminar.
#
#  Sustituye a Flameshot: en Niri con dos pantallas, Flameshot falla porque
#  pide la imagen al portal y Niri solo la da si hay una pantalla.
# ----------------------------------------------------------------------------

# Colores de slurp: fondo fuera de la selección, borde y relleno de la zona
zona="$(slurp -b '#1a1b1e80' -c '#e5e9f0ff' -s '#ffffff14' -w 2)" || exit 0

grim -g "$zona" - | swappy -f -
