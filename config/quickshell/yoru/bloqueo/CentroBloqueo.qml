// ============================================================================
//  CentroBloqueo — entre la hora y la contraseña: la música y las
//  notificaciones, una al lado de la otra (una sobre otra si no caben)
//  Llena el hueco «abajo» de Cerradura; cerrar() cierra las notificaciones.
// ============================================================================
import QtQuick
import qs.comun

Item {
    id: centro
    anchors.fill: parent
    function cerrar() { avisos.cerrar(); }

    readonly property bool lado: width >= musica.width + avisos.width + 60

    Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        columns: centro.lado ? 2 : 1
        columnSpacing: 20
        rowSpacing: 14
        horizontalItemAlignment: Grid.AlignHCenter

        MusicaBloqueo { id: musica }
        AvisosBloqueo {
            id: avisos
            altoMax: centro.lado || !musica.visible ? centro.height : centro.height - musica.height - 14
        }
    }
}
