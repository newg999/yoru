// ============================================================================
//  WidgetsBloqueo — bajo la hora del bloqueo, como los widgets del iPhone
//
//    ┌──────────────────┐
//    │ (󱐋) 80%          │
//    │     quedan 3 h   │
//    └──────────────────┘
//
//  La batería, con el anillo por colores (Tema.bateria: verde llena o
//  cargando, amarillo, naranja y rojo al bajar). Sin batería, no sale.
// ============================================================================
import QtQuick
import Quickshell.Services.UPower
import qs.comun

Row {
    id: fila
    spacing: 12

    component Tarjeta: Rectangle {
        height: 54
        radius: Tema.esquina(20)
        color: Tema.claro(0.1)
        border.width: 1
        border.color: Tema.claro(0.12)
    }
    component Letra: Text {
        color: Tema.texto
        font.family: Tema.fuente
        font.pixelSize: 13
        font.features: { "tnum": 1 }
    }
    component Icono: Text {
        color: Tema.texto
        font.family: Tema.mono
    }

    // -------------------------------------------------------- Batería
    Tarjeta {
        id: bateria
        readonly property var dispositivo: UPower.displayDevice
        readonly property bool hay: dispositivo?.isLaptopBattery ?? false
        readonly property real carga: dispositivo?.percentage ?? 0
        readonly property int estado: dispositivo?.state ?? UPowerDeviceState.Unknown
        readonly property bool cargando: estado === UPowerDeviceState.Charging
        readonly property bool llena: estado === UPowerDeviceState.FullyCharged
        readonly property color tinta: Tema.bateria(carga, cargando || llena)
        visible: hay
        width: bateriaFila.width + 30

        function duracion(s) {
            const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
            return h > 0 ? `${h} h ${m} min` : `${m} min`;
        }

        Row {
            id: bateriaFila
            anchors.centerIn: parent
            spacing: 12
            // El anillo: lo que queda, del color de la carga
            Item {
                width: 38
                height: 38
                anchors.verticalCenter: parent.verticalCenter
                Canvas {
                    id: anillo
                    anchors.fill: parent
                    property real nivel: bateria.carga
                    property color tinta: bateria.tinta
                    Behavior on nivel { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                    onNivelChanged: requestPaint()
                    onTintaChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        const r = width / 2 - 3;
                        c.lineWidth = 4;
                        c.lineCap = "round";
                        c.strokeStyle = Qt.rgba(1, 1, 1, 0.14);
                        c.beginPath();
                        c.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                        c.stroke();
                        c.strokeStyle = tinta;
                        c.beginPath();
                        c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.02, nivel));
                        c.stroke();
                    }
                }
                Icono {
                    anchors.centerIn: parent
                    text: bateria.cargando || bateria.llena ? "󱐋" : "󰁹"
                    color: bateria.tinta
                    font.pixelSize: 14
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Letra {
                    text: Math.round(bateria.carga * 100) + "%"
                    font.pixelSize: 17
                    font.bold: true
                }
                Letra {
                    text: bateria.llena ? "Cargada"
                        : bateria.cargando ? (bateria.dispositivo.timeToFull > 0 ? "Llena en " + bateria.duracion(bateria.dispositivo.timeToFull) : "Cargando")
                        : bateria.dispositivo?.timeToEmpty > 0 ? "Quedan " + bateria.duracion(bateria.dispositivo.timeToEmpty)
                        : "Batería"
                    color: Tema.gris
                    font.pixelSize: 12
                }
            }
        }
    }
}
