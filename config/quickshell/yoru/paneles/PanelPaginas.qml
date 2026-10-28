// ============================================================================
//  Panel de páginas de las islas y de la barra minimalista: se abre debajo
//  de lo pulsado, con sus páginas (Paginas.qml). Cada botón
//  abre lo suyo (Paneles.abrirPagina):
//
//    la conexión                 centro de control (a la derecha)
//    la hora                     calendario
//    la canción                  multimedia
//    el tiempo                   clima
//
//  Es el panel «pildora» (el nombre es de cuando existía la píldora).
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Panel {
    id: panel
    nombre: "pildora"
    lado: Paneles.origen   // bajo el botón que lo abrió (lo pone la barra)
    ancho: paginas.anchoPedido + 4
    // Bajo la isla pulsada, de su ancho (la música en las píldoras)
    ancla: Paneles.seccion === "musica" ? Paneles.ancla : null
    visible: abierto || progreso > 0

    Column {
        width: parent.width
        spacing: 12

        Paginas {
            id: paginas
            width: parent.width
            pantalla: panel.modelData
            abierta: panel.abierto
        }
    }
}
