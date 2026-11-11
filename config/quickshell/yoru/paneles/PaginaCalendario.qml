// ============================================================================
//  Página «calendario» de las islas (la hora), con el aspecto del panel del
//  calendario del dock (el antiguo estilo Dock):
//
//    ‹ Calendario
//    ┌──────────────────────────────────────┐
//    │ (6)  Viernes                         │     hoy, en grande
//    │      6 de noviembre de 2026          │
//    └──────────────────────────────────────┘
//    ┌ ‹      Noviembre 2026      › ┐            ‹ › rueda o ← → = cambiar
//    │ L  M  X  J  V  S  D          │            de mes · clic en el título
//    │ …                            │            o Inicio = hoy
//    └──────────────────────────────┘
//    [󰃶 Hoy] [󰃭 Abrir Calendario]                 (gnome-calendar)
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

FocusScope {
    id: pagina

    property bool activa: false

    readonly property color acento: Tema.blanco
    function tinte(a) { return Tema.conAlfa(acento, a); }

    readonly property var dias: ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    SystemClock {
        id: reloj
        precision: SystemClock.Minutes
    }

    property int anio: 2000
    property int mes: 0
    readonly property bool enHoy: anio === reloj.date.getFullYear() && mes === reloj.date.getMonth()
    function hoy() {
        const d = new Date();
        anio = d.getFullYear();
        mes = d.getMonth();
    }
    function mover(n) {
        const d = new Date(anio, mes + n, 1);
        anio = d.getFullYear();
        mes = d.getMonth();
    }
    // 42 casillas (6 semanas) empezando en lunes: {dia, delMes, hoy, finde}
    readonly property var casillas: {
        const ahora = reloj.date;
        const primero = new Date(anio, mes, 1);
        const desde = new Date(anio, mes, 1 - (primero.getDay() + 6) % 7);
        const r = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(desde.getFullYear(), desde.getMonth(), desde.getDate() + i);
            r.push({dia: d.getDate(), delMes: d.getMonth() === mes,
                    hoy: d.toDateString() === ahora.toDateString(), finde: i % 7 >= 5});
        }
        return r;
    }

    onActivaChanged: {
        if (activa) {
            hoy();
            forceActiveFocus();
        }
    }
    Keys.onLeftPressed: mover(-1)
    Keys.onRightPressed: mover(1)
    Keys.onPressed: e => { if (e.key === Qt.Key_Home) hoy(); }

    implicitHeight: columna.implicitHeight

    Column {
        id: columna
        width: parent.width
        spacing: 12

        // ------------------------------------------------------ Cabecera
        Item {
            width: parent.width
            height: 26
            Texto {
                id: atras
                width: 26; height: 26
                horizontalAlignment: Text.AlignHCenter
                text: "󰅁"
                font.pixelSize: 20
                color: atrasRaton.containsMouse ? pagina.acento : Tema.texto
                scale: atrasRaton.pressed ? 0.85 : atrasRaton.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
                MouseArea { id: atrasRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Paneles.cerrar() }
            }
            Texto {
                anchors { left: atras.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: "Calendario"
                font.pixelSize: 16
                color: Tema.blanco
            }
        }

        // ----------------------------------------------- Hoy, en grande
        Rectangle {
            width: parent.width
            height: 84
            radius: Tema.esquina(18)
            color: pagina.tinte(0.13)
            border.width: 1
            border.color: pagina.tinte(0.35)
            Rectangle {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 52; height: 52; radius: 26
                color: pagina.acento
                Texto {
                    anchors.centerIn: parent
                    text: reloj.date.getDate()
                    font.pixelSize: 22
                    color: Tema.oscuro
                }
            }
            Column {
                x: 80
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80 - 14
                spacing: 2
                Texto {
                    text: pagina.dias[reloj.date.getDay()]
                    font.pixelSize: 16
                    color: Tema.blanco
                }
                Texto {
                    text: reloj.date.getDate() + " de " + pagina.meses[reloj.date.getMonth()] + " de " + reloj.date.getFullYear()
                    font.bold: false
                    font.pixelSize: 11
                    color: Tema.texto
                }
            }
        }

        // -------------------------------------------------------- El mes
        Rectangle {
            id: caja
            width: parent.width
            height: 318
            radius: Tema.esquina(18)
            color: Tema.caja
            border.width: 1
            border.color: Tema.claro(0.08)
            readonly property real celda: (width - 16) / 7

            // La rueda cambia de mes
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => pagina.mover(e.angleDelta.y > 0 ? -1 : 1)
            }

            // ‹ noviembre 2026 ›
            Item {
                x: 8; y: 8
                width: parent.width - 16
                height: 34
                Repeater {
                    model: [-1, 1]
                    Rectangle {
                        required property int modelData
                        x: modelData < 0 ? 0 : parent.width - width
                        width: 34; height: 34
                        radius: Tema.esquina(12)
                        color: navRaton.containsMouse ? Tema.cajaHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Texto {
                            anchors.centerIn: parent
                            text: parent.modelData < 0 ? "󰅁" : "󰅂"
                            font.pixelSize: 18
                            color: navRaton.containsMouse ? pagina.acento : Tema.gris
                        }
                        MouseArea {
                            id: navRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pagina.mover(parent.modelData)
                        }
                    }
                }
                // Clic en el mes: volver a hoy
                Texto {
                    anchors.centerIn: parent
                    text: pagina.meses[pagina.mes].charAt(0).toUpperCase() + pagina.meses[pagina.mes].slice(1) + " " + pagina.anio
                    font.pixelSize: 14
                    color: mesRaton.containsMouse && !pagina.enHoy ? pagina.acento : Tema.blanco
                    MouseArea {
                        id: mesRaton
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: pagina.enHoy ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: pagina.hoy()
                    }
                }
            }

            Grid {
                id: rejilla
                x: 8; y: 50
                columns: 7

                // Al cambiar de mes, los días entran desde un lado
                property real lado: 0
                transform: Translate { x: rejilla.lado }
                Connections {
                    target: pagina
                    function onMesChanged() { cambioMes.restart(); }
                }
                SequentialAnimation {
                    id: cambioMes
                    PropertyAction { target: rejilla; property: "lado"; value: 14 }
                    NumberAnimation { target: rejilla; property: "lado"; to: 0; duration: Tema.ms(300); easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                }

                Repeater {
                    model: ["L", "M", "X", "J", "V", "S", "D"]
                    Texto {
                        required property var modelData
                        required property int index
                        width: caja.celda
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: index >= 5 ? pagina.tinte(0.8) : Tema.claro(0.4)
                    }
                }
                Repeater {
                    model: pagina.casillas
                    Item {
                        id: casilla
                        required property var modelData
                        width: caja.celda
                        height: 40
                        Rectangle {
                            anchors.centerIn: parent
                            width: 34; height: 34; radius: 17
                            color: casilla.modelData.hoy ? pagina.acento
                                : casillaRaton.containsMouse && casilla.modelData.delMes ? Tema.cajaHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        }
                        Texto {
                            anchors.centerIn: parent
                            text: casilla.modelData.dia
                            font.pixelSize: 12
                            font.bold: casilla.modelData.hoy
                            color: casilla.modelData.hoy ? Tema.oscuro
                                : !casilla.modelData.delMes ? Tema.claro(0.2)
                                : casilla.modelData.finde ? Tema.gris : Tema.texto
                        }
                        MouseArea { id: casillaRaton; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }
        }

        // ------------------------------- Abajo: hoy y la app de Calendario
        Row {
            spacing: 8
            Repeater {
                model: [{icono: "󰃶", nombre: "Hoy"}, {icono: "󰃭", nombre: "Abrir Calendario"}]
                Rectangle {
                    id: boton
                    required property var modelData
                    required property int index
                    readonly property bool apagado: index === 0 && pagina.enHoy
                    width: index === 0 ? 96 : columna.width - 96 - 8
                    height: 44
                    radius: Tema.esquina(14)
                    color: botonRaton.containsMouse && !apagado ? pagina.tinte(0.2) : Tema.caja
                    border.width: 1
                    border.color: botonRaton.containsMouse && !apagado ? pagina.tinte(0.5) : Tema.claro(0.08)
                    opacity: apagado ? 0.45 : 1
                    scale: botonRaton.pressed && !apagado ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                    Behavior on opacity { NumberAnimation { duration: Tema.rapida } }
                    Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: boton.modelData.icono
                            font.pixelSize: 16
                            color: pagina.acento
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: boton.modelData.nombre
                            font.pixelSize: 12
                            color: Tema.blanco
                        }
                    }
                    MouseArea {
                        id: botonRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: boton.apagado ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (boton.index === 0) {
                                pagina.hoy();
                            } else {
                                Paneles.cerrar();
                                Niri.lanzar(["gnome-calendar"]);
                            }
                        }
                    }
                }
            }
        }
    }
}
