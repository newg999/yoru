// ============================================================================
//  IconoBateria — la pila del dock (el antiguo estilo Dock): contorno, relleno del color
//  por colores hasta la carga (verde, amarillo, naranja, rojo) y un rayo al cargar.
//  Lo usa Ficha.qml.
// ============================================================================
import QtQuick
import qs.comun

Item {
    id: pila
    property real carga: 0              // 0..1
    property bool cargando: false
    property color color: Tema.texto    // el contorno
    readonly property bool baja: !cargando && carga <= 0.15
    // El relleno: verde lleno o cargando, y amarillo, naranja y rojo al bajar
    property color relleno: Tema.bateria(carga, cargando)
    width: 27
    height: 14

    Rectangle {
        width: 24
        height: 14
        radius: 4
        color: "transparent"
        border.width: 1.4
        border.color: pila.color
        Behavior on border.color { ColorAnimation { duration: Tema.rapida } }
        Rectangle {
            x: 2.6
            y: 2.6
            height: parent.height - 5.2
            radius: 1.4
            width: Math.max(1.5, (parent.width - 5.2) * Math.max(0, Math.min(1, pila.carga)))
            color: pila.relleno
            Behavior on color { ColorAnimation { duration: Tema.ms(600) } }
            Behavior on width { NumberAnimation { duration: Tema.ms(600); easing.type: Easing.OutCubic } }
        }
    }
    // El polo
    Rectangle {
        x: 24.8; y: 4.4
        width: 2.4; height: 5.2
        radius: 1.2
        color: pila.color
    }
    // Cargando: un rayo en medio (con borde oscuro: se ve sobre el relleno
    // y sobre lo vacío, sea cual sea el color del tema)
    Text {
        visible: pila.cargando
        x: Math.round((24 - width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        font.family: Tema.mono
        font.pixelSize: 10
        color: Tema.texto
        style: Text.Outline
        styleColor: Tema.oscuro
    }
}
