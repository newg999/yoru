// ============================================================================
//  Batería — se abre con la isla de la batería
//
//    ┌──────────────────────────────────────┐
//    │ 󰂄  99 %  Cargando                    │
//    │    +1,2 W · llena en 10 min          │
//    ├──────────────────┬───────────────────┤
//    │ Salud      94 %  │ Capacidad 39,7 Wh │
//    ├──────────────────┴───────────────────┤
//    │ [Ahorro] [Equilibrado] [Rendimiento] │
//    └──────────────────────────────────────┘
//
//  Los datos son de UPower. La salud es la capacidad de ahora frente a la
//  de fábrica: con el tiempo baja y la batería dura menos.
// ============================================================================
import QtQuick
import Quickshell.Services.UPower
import qs.comun

Panel {
    id: panel
    nombre: "bateria"
    lado: "derecha"
    ancho: 400

    // La de conjunto para la carga y los tiempos; la física, para la salud
    readonly property var conjunto: UPower.displayDevice
    readonly property var fisica: UPower.devices.values.find(d => d.isLaptopBattery) ?? null

    readonly property int carga: Math.round((conjunto?.percentage ?? 0) * 100)
    readonly property int estado: conjunto?.state ?? UPowerDeviceState.Unknown
    readonly property bool cargando: estado === UPowerDeviceState.Charging
    readonly property bool llena: estado === UPowerDeviceState.FullyCharged
    readonly property bool enchufada: !UPower.onBattery

    readonly property var iconos: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    function numero(v, decimales) {
        return v.toFixed(decimales).replace(".", ",");
    }
    function duracion(s) {
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    readonly property string titulo: llena ? "Cargada"
        : cargando ? "Cargando"
        : enchufada ? "Enchufada, sin cargar"
        : "Con batería"
    readonly property string detalle: {
        const partes = [];
        const w = Math.abs(conjunto?.changeRate ?? 0);
        if (w >= 0.1 && !llena)
            partes.push((cargando ? "+" : "−") + numero(w, 1) + " W");
        if (cargando && conjunto.timeToFull > 0)
            partes.push("llena en " + duracion(conjunto.timeToFull));
        else if (!enchufada && conjunto?.timeToEmpty > 0)
            partes.push("quedan " + duracion(conjunto.timeToEmpty));
        return partes.join("  ·  ");
    }

    Column {
        width: parent.width
        spacing: 12

        // ------------------------------------------------- Carga y estado
        Item {
            width: parent.width
            height: 52

            Texto {
                id: icono
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: panel.cargando || panel.llena ? "󰂄" : panel.iconos[Math.min(9, Math.floor(panel.carga / 10))]
                font.pixelSize: 30
                color: !panel.enchufada && panel.carga <= 10 ? Tema.rojo
                    : !panel.enchufada && panel.carga <= 25 ? Tema.amarillo : Tema.texto
            }
            Column {
                anchors { left: icono.right; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 2
                Row {
                    spacing: 10
                    Texto {
                        text: panel.carga + "%"
                        font.pixelSize: 22
                    }
                    Texto {
                        anchors.baseline: parent.children[0].baseline
                        text: panel.titulo
                        font.pixelSize: 14
                        color: Tema.gris
                    }
                }
                Texto {
                    visible: text !== ""
                    text: panel.detalle
                    font.pixelSize: 12
                    font.bold: false
                    color: Tema.gris
                }
            }
        }

        // ------------------------------------------- Salud y capacidad
        Row {
            width: parent.width
            spacing: 8

            Repeater {
                model: [
                    {titulo: "Salud", valor: panel.fisica?.healthSupported ? Math.round(panel.fisica.healthPercentage) + "%" : "—"},
                    {titulo: "Capacidad", valor: panel.fisica && panel.fisica.energyCapacity > 0 ? panel.numero(panel.fisica.energyCapacity, 1) + " Wh" : "—"}
                ]
                Tarjeta {
                    required property var modelData
                    width: (parent.width - 8) / 2
                    height: 64
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Texto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.titulo
                            font.pixelSize: 12
                            font.bold: false
                            color: Tema.gris
                        }
                        Texto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.valor
                            font.pixelSize: 17
                        }
                    }
                }
            }
        }

        Texto {
            visible: panel.fisica?.healthSupported && panel.fisica.healthPercentage < 50
            width: parent.width
            leftPadding: 4
            text: "La batería está gastada: aguanta mucho menos que nueva."
            font.pixelSize: 11
            font.bold: false
            color: Tema.amarillo
            wrapMode: Text.Wrap
        }

        // ------------------------------------------- Perfil de energía
        SelectorEnergia {
            width: parent.width
        }
    }
}
