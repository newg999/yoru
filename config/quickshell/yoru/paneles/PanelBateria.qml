// ============================================================================
//  Batería — su panel, con la barra a la izquierda o la de Windows (con las
//  islas es una página del panel de la derecha: Paginas.qml). Lo de dentro
//  está en PaginaBateria.qml.
// ============================================================================
import QtQuick
import qs.comun

Panel {
    id: ventanaBateria
    nombre: "bateria"
    lado: "derecha"
    ancho: 400

    PaginaBateria {
        width: parent.width
        abierto: ventanaBateria.abierto
    }
}
