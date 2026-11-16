#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#  archivos.sh — Abre el gestor de archivos que esté por defecto
#
#    archivos.sh [carpeta]       abre la carpeta (sin nada: la carpeta personal)
#    archivos.sh --select RUTA   abre la carpeta de RUTA con RUTA marcada
#
#  No se nombra ninguna app: manda la de «Carpetas» en Ajustes › Apps
#  (inode/directory en ~/.config/mimeapps.list). Si se cambia allí, Mod+E,
#  «Mostrar en Archivos» y «Abrir carpeta» de las grabaciones la siguen solos.
#  Marcar un archivo solo lo saben hacer algunas apps; con las demás se abre
#  la carpeta que lo contiene.
# ----------------------------------------------------------------------------

app=$(xdg-mime query default inode/directory)

if [ "$1" = "--select" ] && [ -n "$2" ]; then
    ruta=$2
    case "$app" in
        org.gnome.Nautilus.desktop|nautilus.desktop) exec nautilus --select "$ruta" ;;
        org.kde.dolphin.desktop)                    exec dolphin --select "$ruta" ;;
        nemo.desktop)                               exec nemo "$ruta" ;;
    esac
    [ -d "$ruta" ] || ruta=$(dirname "$ruta")
    set -- "$ruta"
fi

exec gio open "${1:-$HOME}"
