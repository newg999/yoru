// ============================================================================
//  Ficha — botón redondo dentro de una píldora (BarraIslas.qml)
//  Gris oscuro normal, del color del tema con activa: true (wifi conectado,
//  bluetooth encendido...). Con carga (0 a 1), se llena de color solo hasta
//  ahí, como una batería; con ola: true, ese relleno ondea como agua
//  (la batería mientras carga).
//
//    Ficha {
//        icono: "󰖩"; texto: "Casa"; activa: true
//        onClic: boton => ...      // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
//        onRueda: pasos => ...     // +1 arriba, -1 abajo
//    }
//
//  Con los iconos del dock (Ajustes.iconosDock), como los botones de
//  yoru-dock: sin ficha de fondo, el icono suelto y más grande, del color
//  del tema si está encendida o con el ratón encima, y al pasar el ratón
//  crece con un muelle. La batería, el volumen (volumen: 0..1) y el cable
//  (cable: true) se dibujan como allí (IconoBateria, IconoVolumen, IconoCable).
// ============================================================================
import QtQuick
import Quickshell.Widgets
import qs.comun

// ClippingRectangle: lo de dentro (el agua) sigue las esquinas redondas
ClippingRectangle {
    id: ficha

    property string icono: ""
    property string texto: ""
    property bool activa: false
    property real carga: -1             // 0..1: llena hasta ahí (-1 = no)
    property bool ola: false            // el relleno ondea
    property bool pulsable: true
    property bool apagada: false        // gris (sin reproductor...)
    property color colorIcono: tinta
    property int tamIcono: Tema.letra + 2
    property int anchoTexto: 0          // > 0 = recorta el texto con "…"
    readonly property alias hover: raton.containsMouse
    // Iconos del dock
    readonly property bool comoDock: Ajustes.iconosDock
    property real volumen: -1           // 0..1: el altavoz dibujado (-1 = no)
    property bool mudo: false
    property bool cable: false          // el ethernet dibujado
    property bool cargando: false       // el rayo en la pila dibujada
    property string insignia: ""        // un iconito en la esquina del icono (VPN: 󰦝)
    readonly property string dibujo: !comoDock ? ""
        : cable ? "cable" : carga >= 0 ? "bateria" : volumen >= 0 ? "volumen" : ""
    readonly property int tamDock: tamIcono + 5

    signal clic(int boton)
    signal rueda(int pasos)

    readonly property color tinta: comoDock
        ? (apagada ? Tema.tenue : (hover && pulsable) || activa ? Tema.blanco : Tema.texto)
        : apagada ? Tema.tenue : activa ? Tema.oscuro : (hover && pulsable ? Tema.blanco : Tema.texto)
    // Con los del dock el texto no cambia al encenderse, solo con el ratón
    readonly property color tintaTexto: comoDock
        ? (apagada ? Tema.tenue : hover && pulsable ? Tema.blanco : Tema.texto)
        : tinta

    implicitHeight: comoDock ? 26 : 22
    implicitWidth: comoDock
        ? (texto === "" ? Math.max(implicitHeight, fila.implicitWidth + 8) : fila.implicitWidth + 2 * 6)
        : texto === "" ? implicitHeight : fila.implicitWidth + 2 * (icono === "" ? 10 : 9)
    radius: height / 2
    color: comoDock ? "transparent"
        : activa ? (hover && pulsable ? Qt.lighter(Tema.blanco, 1.1) : Tema.blanco)
        : hover && pulsable ? Tema.claro(0.14) : Tema.claro(0.07)
    Behavior on color { ColorAnimation { duration: Tema.rapida } }

    // Como en el dock: al pulsar se encoge y vuelve con rebote; con el ratón
    // encima, crece un poco. Y al aparecer (wifi que se conecta, bluetooth
    // que se enciende...), sale con un «pop» en vez de de golpe
    // Con los del dock, igual que allí: con el ratón encima crece en su sitio
    // con un muelle, y al pulsar no se encoge
    property real aparecer: 1
    scale: aparecer * (!pulsable ? 1
        : comoDock ? (hover ? 1.14 : 1)
        : raton.pressed ? 0.88 : hover ? 1.06 : 1)
    Behavior on scale {
        enabled: !entrada.running
        NumberAnimation {
            duration: ficha.comoDock ? Tema.rebote * 0.62 : Tema.rebote * 0.8
            easing.type: Easing.OutBack
            easing.overshoot: ficha.comoDock ? 2 : 2.6
        }
    }
    onVisibleChanged: if (visible && Tema.rebote > 0) entrada.restart()
    ParallelAnimation {
        id: entrada
        NumberAnimation { target: ficha; property: "aparecer"; from: 0.4; to: 1; duration: Tema.rebote; easing.type: Easing.OutBack; easing.overshoot: 2 }
        NumberAnimation { target: ficha; property: "opacity"; from: 0; to: 1; duration: Tema.normal; easing.type: Easing.OutCubic }
    }

    // Lo cargado: del color del tema, de la izquierda hasta «carga»
    Agua {
        visible: ficha.carga >= 0 && !ficha.activa && !ficha.comoDock
        anchors.fill: parent
        horizontal: true
        nivel: ficha.carga
        color: Tema.blanco
        inclinacion: 1.5
        vaiven: 1600
        moviendo: ficha.ola
    }

    // El iconito de la esquina de abajo a la derecha, sobre un círculo del
    // color del fondo (así se recorta sobre el icono)
    component Insignia: Rectangle {
        property color tinta
        visible: ficha.insignia !== ""
        readonly property int tam: Math.round((ficha.comoDock ? ficha.tamDock : ficha.tamIcono) * 0.55)
        width: tam + 3
        height: tam + 3
        radius: width / 2
        x: parent.width - width * 0.75
        y: parent.height - height * 0.85
        color: ficha.comoDock || !ficha.activa ? Tema.oscuro : Tema.blanco
        Text {
            anchors.centerIn: parent
            text: ficha.insignia
            color: parent.tinta
            font.family: Tema.mono
            font.pixelSize: parent.tam
        }
    }

    // Icono y texto
    component Contenido: Row {
        id: contenido
        property color tintaIcono
        property color tintaTexto
        spacing: ficha.comoDock ? 5 : 6
        Text {
            visible: ficha.icono !== "" && ficha.dibujo === ""
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.icono
            color: parent.tintaIcono
            font.family: Tema.mono
            font.pixelSize: ficha.comoDock ? ficha.tamDock : ficha.tamIcono
            Behavior on color { enabled: ficha.comoDock; ColorAnimation { duration: Tema.normal * 0.8 } }
            Insignia { tinta: contenido.tintaIcono }
        }
        IconoBateria {
            visible: ficha.dibujo === "bateria"
            anchors.verticalCenter: parent.verticalCenter
            carga: ficha.carga
            cargando: ficha.cargando
            color: contenido.tintaIcono
        }
        IconoVolumen {
            visible: ficha.dibujo === "volumen"
            anchors.verticalCenter: parent.verticalCenter
            tam: ficha.tamDock
            volumen: ficha.volumen
            mudo: ficha.mudo
            color: contenido.tintaIcono
        }
        IconoCable {
            visible: ficha.dibujo === "cable"
            anchors.verticalCenter: parent.verticalCenter
            tam: ficha.tamDock - 2
            color: contenido.tintaIcono
            Insignia { tinta: contenido.tintaIcono }
        }
        Text {
            visible: ficha.texto !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: ficha.texto
            color: parent.tintaTexto
            font.family: Tema.mono
            font.pixelSize: Tema.letra
            font.bold: true
            elide: Text.ElideRight
            width: ficha.anchoTexto > 0 ? Math.min(implicitWidth, ficha.anchoTexto) : implicitWidth
        }
    }

    Contenido {
        id: fila
        anchors.centerIn: parent
        tintaIcono: ficha.colorIcono
        tintaTexto: ficha.tintaTexto
    }
    // Con carga: encima de lo lleno, el mismo texto en oscuro (claro sobre lo
    // vacío y oscuro sobre el color: se lee entero a cualquier carga)
    Item {
        visible: ficha.carga >= 0 && !ficha.activa && !ficha.comoDock
        width: ficha.width * Math.max(0, Math.min(1, ficha.carga))
        height: ficha.height
        clip: true
        Contenido {
            x: fila.x
            y: fila.y
            tintaIcono: Tema.oscuro
            tintaTexto: Tema.oscuro
        }
    }

    MouseArea {
        id: raton
        anchors.fill: parent
        enabled: ficha.pulsable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => ficha.clic(e.button)
        onWheel: e => {
            if (e.angleDelta.y !== 0)
                ficha.rueda(e.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
