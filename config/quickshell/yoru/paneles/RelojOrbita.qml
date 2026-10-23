// ============================================================================
//  Reloj con órbita — la hora en grande y, alrededor, el tiempo de las
//  próximas 24 h cada 3 horas, sobre una elipse que hace de esfera de 24 h:
//
//                      12:00
//            09:00  ╭╌╌╌╌╌╌╌╌╌╌╮  15:00
//          06:00   ╎  12:45:06  ╎   18:00        el día arriba,
//            03:00  ╰╌╌╌╌╌╌╌╌╌╌╯  21:00         la noche abajo
//                      00:00
//
//  El punto blanco es ahora. Las horas más cercanas van más grandes.
// ============================================================================
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.comun

Item {
    id: orbita

    property bool activo: false   // el reloj con segundos solo corre si se ve

    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var diasSemana: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]

    SystemClock {
        id: reloj
        enabled: orbita.activo
        precision: SystemClock.Seconds
    }

    // Elipse
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real rx: width / 2 - 42
    readonly property real ry: height / 2 - 46

    // Hora del día (0–24) → punto de la elipse: 12 arriba, en el sentido del reloj
    function punto(h) {
        const a = (h - 12) * Math.PI / 12 - Math.PI / 2;
        return Qt.point(cx + rx * Math.cos(a), cy + ry * Math.sin(a));
    }
    readonly property real ahora: reloj.date.getHours() + reloj.date.getMinutes() / 60

    // Al abrirse, las horas aparecen una tras otra
    property real aparecer: 0
    onActivoChanged: {
        if (activo) {
            aparecer = 0;
            entrada.restart();
        }
    }
    NumberAnimation {
        id: entrada
        target: orbita
        property: "aparecer"
        to: 1
        duration: Ajustes.animaciones ? 700 : 0
        easing.type: Easing.OutCubic
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Tema.claro(0.22)
            strokeWidth: 1.5
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 6]
            PathAngleArc {
                centerX: orbita.cx; centerY: orbita.cy
                radiusX: orbita.rx; radiusY: orbita.ry
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // Ahora
    Rectangle {
        readonly property point p: orbita.punto(orbita.ahora)
        x: p.x - width / 2
        y: p.y - height / 2
        width: 10; height: 10; radius: 5
        color: Tema.blanco
        Rectangle {
            anchors.centerIn: parent
            width: 22; height: 22; radius: 11
            color: Tema.claro(0.15)
        }
    }

    // Hora, minutos y segundos · fecha
    Column {
        anchors.centerIn: parent
        spacing: 2
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(reloj.date, "HH:mm:ss")
            font.pixelSize: 58
            color: Tema.blanco
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: orbita.diasSemana[reloj.date.getDay()] + ", " + reloj.date.getDate()
                + " de " + orbita.meses[reloj.date.getMonth()]
            font.bold: false
            font.pixelSize: 15
            color: Tema.gris
        }
    }

    // Las próximas 24 h, cada 3 horas
    Repeater {
        model: Tiempo.cadaTres
        Rectangle {
            id: hora
            required property var modelData
            required property int index
            readonly property point p: orbita.punto(parseInt(modelData.hora))
            readonly property real tam: 1 - index * 0.04

            x: p.x - width / 2
            y: p.y - height / 2
            width: 54 * tam
            height: 70 * tam
            radius: 10
            color: Qt.tint(Tema.oscuro, horaRaton.containsMouse ? Tema.cajaHover : Tema.caja)
            border.width: 1
            border.color: Tema.claro(horaRaton.containsMouse ? 0.3 : 0.08)
            Behavior on border.color { ColorAnimation { duration: Tema.rapida } }

            opacity: Math.max(0, Math.min(1, orbita.aparecer * 9 - index)) * (1 - index * 0.05)
            scale: 0.8 + 0.2 * Math.min(1, Math.max(0, orbita.aparecer * 9 - index))

            Column {
                anchors.centerIn: parent
                spacing: 2 * hora.tam
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: hora.modelData.hora
                    font.pixelSize: Math.round(11 * hora.tam)
                    color: Tema.gris
                }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Tiempo.iconoDe(hora.modelData.codigo, hora.modelData.dia)
                    font.pixelSize: Math.round(20 * hora.tam)
                    color: Tema.blanco
                }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: hora.modelData.temp + "°"
                    font.pixelSize: Math.round(12 * hora.tam)
                }
            }
            MouseArea {
                id: horaRaton
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }
}
