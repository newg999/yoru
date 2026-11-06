// ============================================================================
//  Batería — se abre con la isla de la batería, con el aspecto del panel
//  de la batería del dock (yoru-dock):
//
//    ‹ Batería                        [󰚥 Enchufada]
//    ▐████████~~   │  99 %                         la pila, llena de líquido
//                  │  Cargando · llena en 10 min   (con ondas y burbujas al
//    [󱐋 Potencia] [󰣐 Salud] [󰂑 Capacidad]           cargar)
//    PERFIL DE ENERGÍA
//    [ Ahorro | Equilibrado | Rendimiento ]
//    [☕ No suspender                     ●]
//
//  Los datos son de UPower. La salud es la capacidad de ahora frente a la
//  de fábrica: con el tiempo baja y la batería dura menos.
// ============================================================================
import QtQuick
import Quickshell.Widgets
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

    readonly property color acento: Tema.blanco
    function tinte(a) { return Tema.conAlfa(acento, a); }
    readonly property bool baja: !enchufada && carga < 20
    readonly property color liquido: baja ? Tema.rojo : acento
    onLiquidoChanged: nivelCanvas.requestPaint()

    component Titulo: Texto {
        x: 2
        font.pixelSize: 11
        font.letterSpacing: 1.6
        color: Tema.gris
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
                color: atrasRaton.containsMouse ? panel.acento : Tema.texto
                scale: atrasRaton.pressed ? 0.85 : atrasRaton.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                MouseArea { id: atrasRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Paneles.cerrar() }
            }
            Texto {
                anchors { left: atras.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: "Batería"
                font.pixelSize: 16
                color: Tema.blanco
            }
            // Enchufada o con batería
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                height: 22
                radius: 11
                width: enchufe.implicitWidth + 16
                color: panel.enchufada ? panel.tinte(0.18) : Tema.caja
                border.width: 1
                border.color: panel.enchufada ? panel.tinte(0.45) : Tema.claro(0.1)
                Row {
                    id: enchufe
                    anchors.centerIn: parent
                    spacing: 4
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.enchufada ? "󰚥" : "󰁹"
                        font.pixelSize: 12
                        color: panel.enchufada ? panel.acento : Tema.gris
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.enchufada ? "Enchufada" : "Con batería"
                        font.pixelSize: 10
                        color: panel.enchufada ? Tema.blanco : Tema.gris
                    }
                }
            }
        }

        // ------------------------------- La pila, llena de líquido, y el %
        Item {
            width: parent.width
            height: 112
            Item {
                id: pila
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 124; height: 62
                Rectangle {
                    id: cuerpo
                    width: 116; height: 62
                    radius: Tema.esquina(16)
                    color: Tema.sombra(0.6)
                    border.width: 2.5
                    border.color: Tema.claro(0.22)
                    // El líquido: hasta la carga, con el borde ondulado (más
                    // vivo al cargar)
                    ClippingRectangle {
                        x: 5; y: 5
                        width: parent.width - 10
                        height: parent.height - 10
                        radius: Tema.esquina(11)
                        color: "transparent"
                        Canvas {
                            id: nivelCanvas
                            anchors.fill: parent
                            property real fase: 0
                            property real nivel: panel.carga / 100
                            Behavior on nivel { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                            onNivelChanged: requestPaint()
                            onFaseChanged: requestPaint()
                            NumberAnimation on fase {
                                running: panel.abierto && Ajustes.animaciones
                                loops: Animation.Infinite
                                from: 0; to: Math.PI * 2
                                duration: panel.cargando ? 1400 : 3600
                            }
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                const w = width, h = height;
                                const fx = w * Math.max(0.03, nivel);
                                const amp = panel.cargando ? 3.2 : 1.4;
                                c.beginPath();
                                c.moveTo(0, 0);
                                for (let y = 0; y <= h; y += 2)
                                    c.lineTo(Math.min(w, fx + Math.sin(y / h * Math.PI * 2 + fase) * amp), y);
                                c.lineTo(0, h);
                                c.closePath();
                                const fc = panel.liquido;
                                const g = c.createLinearGradient(0, 0, w, 0);
                                g.addColorStop(0, Qt.rgba(fc.r, fc.g, fc.b, 0.55));
                                g.addColorStop(1, Qt.rgba(fc.r, fc.g, fc.b, 1));
                                c.fillStyle = g;
                                c.fill();
                            }
                        }
                        // Burbujas, al cargar
                        Repeater {
                            model: 4
                            Rectangle {
                                id: burbuja
                                required property int index
                                width: 4 + (index % 2) * 2
                                height: width
                                radius: width / 2
                                color: Tema.oscuro
                                visible: panel.cargando
                                property real t: 0
                                x: Math.max(4, nivelCanvas.width * panel.carga / 100 * (0.2 + index * 0.18))
                                y: nivelCanvas.height - t * (nivelCanvas.height + 6)
                                opacity: 0.35 * (1 - t)
                                NumberAnimation on t {
                                    running: panel.cargando && panel.abierto && Ajustes.animaciones
                                    loops: Animation.Infinite
                                    from: 0; to: 1
                                    duration: 1500 + burbuja.index * 380
                                }
                            }
                        }
                    }
                    // El rayo, al cargar
                    Texto {
                        anchors.centerIn: parent
                        visible: panel.cargando
                        text: "󱐋"
                        font.pixelSize: 26
                        color: Tema.oscuro
                        SequentialAnimation on scale {
                            running: panel.cargando && panel.abierto && Ajustes.animaciones
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 1.12; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.12; to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                }
                // El polo
                Rectangle {
                    x: cuerpo.width + 2
                    anchors.verticalCenter: cuerpo.verticalCenter
                    width: 6; height: 22; radius: 3
                    color: Tema.claro(0.22)
                }
            }
            Column {
                x: pila.x + pila.width + 22
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Row {
                    spacing: 2
                    Texto {
                        id: porcentaje
                        text: panel.carga
                        font.pixelSize: 40
                        color: Tema.blanco
                    }
                    Texto {
                        anchors { bottom: porcentaje.bottom; bottomMargin: 8 }
                        text: "%"
                        font.pixelSize: 16
                        color: Tema.gris
                    }
                }
                Texto {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: panel.titulo + (panel.detalle !== "" ? " · " + panel.detalle.replace(/  ·  /g, " · ") : "")
                    font.pixelSize: 12
                    color: panel.baja ? Tema.rojo : Tema.texto
                }
            }
        }

        // --------------------------------------------- Tres datos sueltos
        Row {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    {icono: "󱐋", nombre: "Potencia", valor: panel.numero(Math.abs(panel.conjunto?.changeRate ?? 0), 1) + " W", aviso: false},
                    {icono: "󰣐", nombre: "Salud",
                     valor: panel.fisica?.healthSupported ? Math.round(panel.fisica.healthPercentage) + "%" : "—",
                     aviso: (panel.fisica?.healthSupported ?? false) && panel.fisica.healthPercentage < 70},
                    {icono: "󰂑", nombre: "Capacidad",
                     valor: panel.fisica && panel.fisica.energyCapacity > 0 ? panel.numero(panel.fisica.energyCapacity, 1) + " Wh" : "—", aviso: false}
                ]
                Rectangle {
                    id: dato
                    required property var modelData
                    width: (parent.width - 16) / 3
                    height: 64
                    radius: Tema.esquina(16)
                    color: Tema.caja
                    border.width: 1
                    border.color: Tema.claro(0.08)
                    Texto {
                        x: 10; y: 10
                        text: dato.modelData.icono
                        font.pixelSize: 15
                        color: dato.modelData.aviso ? Tema.rojo : panel.acento
                    }
                    Texto {
                        anchors { right: parent.right; rightMargin: 10 }
                        y: 12
                        text: dato.modelData.nombre
                        font.bold: false
                        font.pixelSize: 9
                        color: Tema.gris
                    }
                    Texto {
                        x: 12; y: 32
                        text: dato.modelData.valor
                        font.pixelSize: 15
                        color: dato.modelData.aviso ? Tema.rojo : Tema.blanco
                    }
                }
            }
        }

        Texto {
            visible: (panel.fisica?.healthSupported ?? false) && panel.fisica.healthPercentage < 50
            width: parent.width
            leftPadding: 4
            text: "La batería está gastada: aguanta mucho menos que nueva."
            font.pixelSize: 11
            font.bold: false
            color: Tema.amarillo
            wrapMode: Text.Wrap
        }

        // ------------------------------------------- Perfil de energía
        Titulo {
            visible: perfiles.lista.length > 0
            text: "PERFIL DE ENERGÍA"
        }
        Rectangle {
            id: perfiles
            visible: lista.length > 0
            width: parent.width
            height: 52
            radius: Tema.esquina(16)
            color: Tema.sombra(0.4)
            border.width: 1
            border.color: Tema.claro(0.08)
            readonly property var lista: [
                {perfil: PowerProfile.PowerSaver, icono: "󰌪", texto: "Ahorro"},
                {perfil: PowerProfile.Balanced, icono: "󰾅", texto: "Equilibrado"},
                {perfil: PowerProfile.Performance, icono: "󱐋", texto: "Rendimiento"}
            ].filter(p => p.perfil !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
            readonly property int i: Math.max(0, lista.findIndex(p => p.perfil === PowerProfiles.profile))
            readonly property real tramo: (width - 8) / Math.max(1, lista.length)
            Rectangle {
                x: 4 + perfiles.i * perfiles.tramo
                y: 4
                width: perfiles.tramo
                height: parent.height - 8
                radius: Tema.esquina(12)
                color: panel.tinte(0.2)
                border.width: 1.5
                border.color: panel.acento
                Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }
            Repeater {
                model: perfiles.lista
                Item {
                    id: perfil
                    required property var modelData
                    required property int index
                    readonly property bool on: perfiles.i === index
                    x: 4 + index * perfiles.tramo
                    y: 4
                    width: perfiles.tramo
                    height: perfiles.height - 8
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: perfil.modelData.icono
                            font.pixelSize: 15
                            color: perfil.on ? panel.acento : perfilRaton.containsMouse ? Tema.blanco : Tema.gris
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: perfil.modelData.texto
                            font.pixelSize: 11
                            font.bold: perfil.on
                            color: perfil.on ? Tema.blanco : perfilRaton.containsMouse ? Tema.texto : Tema.gris
                        }
                    }
                    MouseArea {
                        id: perfilRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = perfil.modelData.perfil
                    }
                }
            }
        }

        // ------------------------------------------------ No suspender
        Rectangle {
            width: parent.width
            height: 44
            radius: Tema.esquina(14)
            color: cafeRaton.containsMouse ? Tema.cajaHover : Tema.caja
            border.width: 1
            border.color: Despierto.activo ? panel.tinte(0.5) : Tema.claro(0.08)
            Behavior on color { ColorAnimation { duration: 150 } }
            Row {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    radius: Tema.esquina(8)
                    color: Despierto.activo ? panel.acento : Tema.claro(0.08)
                    Texto {
                        anchors.centerIn: parent
                        text: "󰅶"
                        font.pixelSize: 14
                        color: Despierto.activo ? Tema.oscuro : Tema.gris
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Texto {
                        text: "No suspender"
                        font.pixelSize: 12
                        color: Tema.texto
                    }
                    Texto {
                        text: Despierto.activo ? "No se bloquea ni se apaga la pantalla" : "Apagado"
                        font.bold: false
                        font.pixelSize: 10
                        color: Tema.gris
                    }
                }
            }
            Rectangle {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: 38; height: 22; radius: 11
                color: Despierto.activo ? panel.acento : Tema.claro(0.15)
                Behavior on color { ColorAnimation { duration: 160 } }
                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: Despierto.activo ? parent.width - width - 3 : 3
                    color: Despierto.activo ? Tema.oscuro : Tema.gris
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
            }
            MouseArea {
                id: cafeRaton
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Despierto.activo = !Despierto.activo
            }
        }
    }
}
