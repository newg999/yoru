// ============================================================================
//  CPU o memoria — se abre con su isla de la barra (sección "cpu" o "memoria")
//
//    󰘚  14%                    8 hilos · 52 °C
//    ╭──────── gráfica de los últimos 2 min ────────╮
//    Lo que más gasta
//      Brave          6,2%     (los procesos de una app, sumados)
//      ...
//    [ Abrir el monitor del sistema ]
//
//  Los procesos salen de scripts/monitor.py (el mismo del monitor), que
//  solo corre con el panel abierto.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "uso"
    lado: "derecha"
    ancho: 380

    readonly property bool cpu: Paneles.seccion !== "memoria"
    property var datos: null

    Process {
        running: panel.abierto
        command: ["python3", Quickshell.shellPath("scripts/monitor.py")]
        stdout: SplitParser {
            onRead: linea => {
                try {
                    panel.datos = JSON.parse(linea);
                } catch (e) {}
            }
        }
    }
    onAbiertoChanged: if (!abierto) datos = null

    function tamano(bytes) {
        if (bytes >= 1024 ** 3) return (bytes / 1024 ** 3).toFixed(1).replace(".", ",") + " GB";
        if (bytes >= 1024 ** 2) return Math.round(bytes / 1024 ** 2) + " MB";
        return Math.round(bytes / 1024) + " KB";
    }

    // Las 5 apps que más gastan, con sus procesos sumados (Brave son decenas)
    readonly property var primeros: {
        if (!datos)
            return [];
        const campo = cpu ? "cpu" : "mem";
        const suma = {};
        for (const p of datos.procesos)
            suma[p.nombre] = (suma[p.nombre] ?? 0) + p[campo];
        return Object.entries(suma)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([nombre, v]) => ({nombre: nombre, valor: v}));
    }

    Column {
        width: parent.width
        spacing: 12

        // ------------------------------------------------------- Cabecera
        Item {
            width: parent.width
            height: 36
            Row {
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 12
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.cpu ? "󰘚" : "󰍛"
                    font.pixelSize: 24
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (panel.cpu ? Sistema.cpu : Sistema.memoria) + "%"
                    font.pixelSize: 22
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.cpu ? "Procesador" : "Memoria"
                    font.pixelSize: 14
                    color: Tema.gris
                }
            }
            Texto {
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                text: panel.cpu
                    ? (panel.datos ? panel.datos.nucleos + " hilos" : "") + (Sistema.temperatura > 0 ? `  ·  ${Sistema.temperatura} °C` : "")
                    : Sistema.memUsada.toFixed(1).replace(".", ",") + " de " + Sistema.memTotal.toFixed(1).replace(".", ",") + " GiB"
                font.pixelSize: 12
                font.bold: false
                color: Tema.gris
            }
        }

        // ------------------------------------------------------- Gráfica
        Tarjeta {
            width: parent.width
            height: 100
            Grafica {
                anchors { fill: parent; margins: 12 }
                valores: panel.cpu ? Sistema.historialCpu : Sistema.historialMem
            }
        }

        // --------------------------------------------- Lo que más gasta
        Column {
            width: parent.width
            spacing: 2

            Texto {
                leftPadding: 4
                bottomPadding: 4
                text: "Lo que más gasta"
                font.pixelSize: 12
                color: Tema.gris
            }
            Texto {
                visible: panel.primeros.length === 0
                leftPadding: 4
                text: "Midiendo…"
                font.pixelSize: 12
                font.bold: false
                color: Tema.gris
            }
            Repeater {
                model: panel.primeros
                Item {
                    required property var modelData
                    width: parent.width
                    height: 28
                    Texto {
                        anchors { left: parent.left; leftMargin: 4; right: valor.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        text: modelData.nombre
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        font.bold: false
                    }
                    Texto {
                        id: valor
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        text: panel.cpu ? modelData.valor.toFixed(1).replace(".", ",") + "%" : panel.tamano(modelData.valor)
                        font.pixelSize: 13
                    }
                }
            }
        }

        Opciones {
            width: parent.width
            opciones: [{id: "monitor", icono: "󰨇", texto: "Abrir el monitor del sistema"}]
            onElegir: Paneles.alternar("monitor", panel.modelData, panel.cpu ? "rendimiento" : "procesos")
        }
    }
}
