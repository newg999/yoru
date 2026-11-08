// ============================================================================
//  MEGA — se abre con el icono de MEGA de la bandeja, colgando de su isla
//  como los demás paneles (en vez de la ventana de MEGAsync, que es de otra
//  app y no se puede fundir con la barra):
//
//    ‹ MEGA                              [✓ Actualizado]
//    ┌──────────────────────────────────────────────┐
//    │ ( 24 % )  Almacenamiento                      │
//    │           12,26 GB de 50 GB · quedan 37,74 GB │
//    └──────────────────────────────────────────────┘
//    󰉋 Abrir la carpeta          /home/don/Descargas/Mega
//    󰖟 MEGA en el navegador
//    󰋽 Transferencias y avisos   (la ventana de MEGA)
//    󰒓 Ajustes de MEGA
//    󰐥 Salir de MEGA
//
//  El estado sale del tooltip de su icono; el espacio y la carpeta, de su
//  configuración (scripts/mega.py); las tres últimas son las entradas de su
//  menú de la bandeja (las mismas que el clic derecho).
// ============================================================================
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.comun

Panel {
    id: panel
    nombre: "mega"
    lado: "derecha"
    ancho: 400

    readonly property var item: SystemTray.items.values.find(i => i.id === "MEGAsync") ?? null
    // Su tooltip: «MEGA 6.7.0» y «Actualizado» (o «Sincronizando…», «En
    // pausa»...). MEGA pone las dos líneas en el título; por si acaso, se
    // juntan título y descripción y se toma una línea cada uno
    readonly property var lineas: `${item?.tooltipTitle ?? ""}\n${item?.tooltipDescription ?? ""}`
        .split("\n").map(l => l.trim()).filter(l => l !== "")
    readonly property string version: lineas.length > 1 ? lineas[0] : ""
    readonly property string estado: lineas.length > 1 ? lineas[1] : lineas[0] ?? "Conectado"
    readonly property bool alDia: /actualizado|up to date/i.test(estado)

    property var datos: ({usado: null, total: null, carpeta: null})
    readonly property bool hayEspacio: datos.total > 0 && datos.usado !== null
    readonly property real parte: hayEspacio ? Math.min(1, datos.usado / datos.total) : 0
    function gb(bytes) {
        return (bytes / 1073741824).toFixed(2).replace(/\.?0+$/, "").replace(".", ",") + " GB";
    }

    onAbiertoChanged: if (abierto) lector.running = true
    Process {
        id: lector
        command: [Quickshell.shellPath("scripts/mega.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    panel.datos = JSON.parse(text);
                } catch (e) {
                    console.warn("mega.py:", e);
                }
            }
        }
    }

    // Su menú de la bandeja: Mostrar estado, Ajustes, Salir (en tu idioma)
    QsMenuOpener {
        id: menu
        menu: panel.item?.menu ?? null
    }
    function entrada(patron) {
        return menu.children.values.find(e => patron.test(e.text ?? "")) ?? null;
    }
    function pulsar(patron) {
        const e = entrada(patron);
        Paneles.cerrar();
        e?.triggered();
    }

    Column {
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
                color: atrasRaton.containsMouse ? Tema.blanco : Tema.texto
                scale: atrasRaton.pressed ? 0.85 : atrasRaton.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                MouseArea { id: atrasRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Paneles.cerrar() }
            }
            Texto {
                anchors { left: atras.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: "MEGA"
                font.pixelSize: 16
                color: Tema.blanco
            }
            // El estado, en una ficha
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                height: 22
                radius: 11
                width: Math.min(ficha.implicitWidth + 16, parent.width - 120)
                color: panel.alDia ? Tema.claro(0.12) : Tema.caja
                border.width: 1
                border.color: panel.alDia ? Tema.claro(0.35) : Tema.claro(0.1)
                Row {
                    id: ficha
                    anchors.centerIn: parent
                    spacing: 4
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.alDia ? "󰄬" : "󰓦"
                        font.pixelSize: 12
                        color: panel.alDia ? Tema.blanco : Tema.gris
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.estado
                        font.pixelSize: 10
                        color: panel.alDia ? Tema.blanco : Tema.gris
                    }
                }
            }
        }

        // --------------------------------------- Almacenamiento (anillo)
        Rectangle {
            width: parent.width
            height: 96
            radius: Tema.esquina(16)
            color: Tema.caja
            border.width: 1
            border.color: Tema.claro(0.08)

            Item {
                id: anillo
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64
                // Se llena al abrir el panel
                property real lleno: panel.abierto ? panel.parte : 0
                Behavior on lleno { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Tema.claro(0.12)
                        strokeWidth: 6
                        fillColor: "transparent"
                        PathAngleArc { centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: panel.parte > 0.9 ? Tema.rojo : Tema.blanco
                        strokeWidth: 6
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 32; centerY: 32; radiusX: 28; radiusY: 28; startAngle: -90; sweepAngle: 360 * anillo.lleno }
                    }
                }
                Texto {
                    anchors.centerIn: parent
                    text: panel.hayEspacio ? Math.round(panel.parte * 100) + "%" : "–"
                    font.pixelSize: 14
                    color: Tema.blanco
                }
            }

            Column {
                anchors { left: anillo.right; leftMargin: 16; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 4
                Texto {
                    text: "Almacenamiento"
                    font.pixelSize: 15
                    color: Tema.blanco
                }
                Texto {
                    width: parent.width
                    text: panel.hayEspacio ? panel.gb(panel.datos.usado) + " de " + panel.gb(panel.datos.total)
                        : "Abre MEGA una vez para ver tu espacio"
                    font.pixelSize: 12
                    font.bold: false
                    color: Tema.texto
                    elide: Text.ElideRight
                }
                Texto {
                    visible: panel.hayEspacio
                    text: "Quedan " + panel.gb(Math.max(0, panel.datos.total - panel.datos.usado))
                    font.pixelSize: 11
                    font.bold: false
                    color: Tema.gris
                }
            }
        }

        // ------------------------------------------------------ Acciones
        Column {
            width: parent.width
            spacing: 2

            Fila {
                width: parent.width
                visible: panel.datos.carpeta !== null
                icono: "󰉋"
                titulo: "Abrir la carpeta"
                detalle: (panel.datos.carpeta ?? "").replace(Quickshell.env("HOME"), "~")
                formato: Text.PlainText
                onClic: {
                    Paneles.cerrar();
                    Quickshell.execDetached(["xdg-open", panel.datos.carpeta]);
                }
            }
            Fila {
                width: parent.width
                icono: "󰖟"
                titulo: "MEGA en el navegador"
                detalle: "mega.nz: tus archivos en la nube"
                onClic: {
                    Paneles.cerrar();
                    Qt.openUrlExternally("https://mega.nz/fm");
                }
            }
            Fila {
                width: parent.width
                visible: panel.entrada(/estado|status/i) !== null
                icono: "󰋽"
                titulo: "Transferencias y avisos"
                detalle: "La ventana de MEGA"
                onClic: panel.pulsar(/estado|status/i)
            }
            Fila {
                width: parent.width
                visible: panel.entrada(/ajustes|settings|preferenc/i) !== null
                icono: "󰒓"
                titulo: "Ajustes de MEGA"
                detalle: "Sincronizaciones, cuenta y velocidad"
                onClic: panel.pulsar(/ajustes|settings|preferenc/i)
            }
            Fila {
                width: parent.width
                visible: panel.entrada(/salir|exit|quit/i) !== null
                icono: "󰐥"
                titulo: "Salir de MEGA"
                detalle: "Deja de sincronizar hasta que vuelvas a abrirlo"
                onClic: panel.pulsar(/salir|exit|quit/i)
            }
        }

        Texto {
            visible: panel.version !== ""
            x: 4
            text: panel.version
            font.pixelSize: 10
            font.bold: false
            color: Tema.tenue
        }
    }
}
