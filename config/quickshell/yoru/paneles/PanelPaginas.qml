// ============================================================================
//  Panel de páginas de las islas y de la barra minimalista: se abre debajo
//  de lo pulsado, con las páginas de la píldora (Paginas.qml). Cada botón
//  abre lo suyo (Paneles.abrirPagina):
//
//    la conexión                 centro de control (a la derecha)
//    la hora                     calendario
//    la canción                  multimedia
//    el tiempo                   clima
//
//  Es el panel «pildora», como la píldora (que lo lleva dentro de sí misma):
//  este se ve con las islas o la minimalista.
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Panel {
    id: panel
    nombre: "pildora"
    lado: Paneles.origen   // bajo el botón que lo abrió (lo pone la barra)
    ancho: paginas.anchoPedido + 4
    visible: !Ajustes.pildora && (abierto || progreso > 0)

    Column {
        width: parent.width
        spacing: 12

        Paginas {
            id: paginas
            width: parent.width
            pantalla: panel.modelData
            abierta: panel.abierto && !Ajustes.pildora
        }
    }
}
