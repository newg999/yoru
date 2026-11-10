// ============================================================================
//  Página «sonido» de las islas (la ficha del volumen), con el aspecto del
//  panel de sonido del dock (el antiguo estilo Dock):
//
//    ‹ Sonido                                     ⚙   ⚙ = pavucontrol
//    ┌──────────────────────────────────────┐
//    │ (󰕾)  Altavoces                       │     clic en el círculo = silenciar
//    │      Altavoz                          │
//    │ ━━━━━━━━━━━━━━━━━━○──────────   80%  │
//    └──────────────────────────────────────┘
//    [ Salida | Entrada | Apps ]
//    ▌ Altavoces            ━━━━━○── 80%    clic = usar ese · el elegido y
//      Auriculares                            cada app llevan su volumen
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.comun

Item {
    id: pagina

    property bool activa: false
    property int altoMax: 700
    property string pestana: "salida"      // "salida" · "entrada" · "apps"
    onActivaChanged: if (activa) pestana = "salida"

    readonly property color acento: Tema.blanco
    function tinte(a) { return Tema.conAlfa(acento, a); }

    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    readonly property var nodos: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var salidas: nodos.filter(n => !n.isStream && n.isSink)
    readonly property var entradas: nodos.filter(n => !n.isStream && !n.isSink && !(n.name ?? "").endsWith(".monitor"))
    readonly property var apps: nodos.filter(n => n.isStream && n.isSink)
    // Su volumen solo llega si se sigue el nodo
    PwObjectTracker { objects: pagina.activa ? pagina.nodos : [] }

    readonly property real volumen: salida?.audio?.volume ?? 0
    readonly property bool mudo: salida?.audio?.muted ?? true

    function nombre(n) {
        if (!n)
            return "";
        const p = n.properties ?? {};
        if (n.isStream)
            return p["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }
    function tipo(n, deEntrada) {
        const t = ((n.name ?? "") + " " + (n.description ?? "")).toLowerCase();
        if (t.includes("hdmi") || t.includes("displayport")) return "HDMI / DisplayPort";
        if (t.includes("bluez") || t.includes("bluetooth")) return "Bluetooth";
        if (t.includes("headphone") || t.includes("headset") || t.includes("auricular")) return "Auriculares";
        if (t.includes("usb")) return "USB";
        return deEntrada ? "Micrófono" : "Altavoz";
    }
    function glifo(n, deEntrada) {
        const t = tipo(n, deEntrada);
        return t === "HDMI / DisplayPort" ? "󰍹" : t === "Bluetooth" || t === "Auriculares" ? "󰋋"
            : t === "USB" ? "󰕓" : deEntrada ? "󰍬" : "󰓃";
    }
    function iconoApp(n) {
        const p = n?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || p["application.id"] || "";
    }

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
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                MouseArea { id: atrasRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Paneles.cerrar() }
            }
            Texto {
                anchors { left: atras.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: "Sonido"
                font.pixelSize: 16
                color: Tema.blanco
            }
            Texto {
                anchors.right: parent.right
                width: 26; height: 26
                horizontalAlignment: Text.AlignHCenter
                text: "󰒓"
                font.pixelSize: 17
                color: ajustesRaton.containsMouse ? pagina.acento : Tema.gris
                scale: ajustesRaton.pressed ? 0.85 : ajustesRaton.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                MouseArea {
                    id: ajustesRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Paneles.cerrar();
                        Niri.lanzar(["pavucontrol", "-t", pagina.pestana === "entrada" ? "4" : pagina.pestana === "apps" ? "1" : "3"]);
                    }
                }
            }
        }

        // -------------------------------------------- El volumen general
        Rectangle {
            width: parent.width
            height: 112
            radius: Tema.esquina(18)
            color: pagina.mudo ? Tema.caja : pagina.tinte(0.12)
            border.width: 1
            border.color: pagina.mudo ? Tema.claro(0.08) : pagina.tinte(0.35)
            Behavior on color { ColorAnimation { duration: 220 } }

            Rectangle {
                x: 14; y: 14
                width: 44; height: 44; radius: 22
                color: pagina.mudo ? Tema.claro(0.08) : pagina.acento
                Behavior on color { ColorAnimation { duration: 200 } }
                scale: mudoRaton.pressed ? 0.9 : mudoRaton.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                Texto {
                    anchors.centerIn: parent
                    text: pagina.mudo ? "󰖁" : pagina.volumen < 0.34 ? "󰕿" : pagina.volumen < 0.67 ? "󰖀" : "󰕾"
                    font.pixelSize: 22
                    color: pagina.mudo ? Tema.gris : Tema.oscuro
                }
                MouseArea {
                    id: mudoRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (pagina.salida?.audio) pagina.salida.audio.muted = !pagina.mudo
                }
            }
            Column {
                x: 70; y: 16
                width: parent.width - 70 - 14
                spacing: 2
                Texto {
                    width: parent.width
                    elide: Text.ElideRight
                    text: pagina.salida ? pagina.nombre(pagina.salida) : "Sin salida"
                    textFormat: Text.PlainText
                    font.pixelSize: 14
                    color: Tema.blanco
                }
                Texto {
                    text: pagina.mudo ? "Silenciado" : pagina.salida ? pagina.tipo(pagina.salida, false) : ""
                    font.bold: false
                    font.pixelSize: 11
                    color: pagina.mudo ? Tema.rojo : Tema.texto
                }
            }
            BarraVolumen {
                id: general
                x: 16; y: 74
                width: parent.width - 32 - 52
                grueso: 10
                valor: pagina.volumen
                apagado: pagina.mudo
                onMovido: v => {
                    if (!pagina.salida?.audio)
                        return;
                    pagina.salida.audio.muted = false;
                    pagina.salida.audio.volume = v;
                }
            }
            Texto {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: general.verticalCenter }
                text: Math.round(general.v * 100) + "%"
                font.pixelSize: 15
                color: pagina.mudo ? Tema.claro(0.4) : Tema.blanco
            }
        }

        // ------------------------------- Pestañas: Salida · Entrada · Apps
        Rectangle {
            id: pestanas
            width: parent.width
            height: 40
            radius: Tema.esquina(13)
            color: Tema.sombra(0.4)
            border.width: 1
            border.color: Tema.claro(0.08)
            readonly property var claves: ["salida", "entrada", "apps"]
            readonly property int i: Math.max(0, claves.indexOf(pagina.pestana))
            readonly property real tramo: (width - 8) / 3
            Rectangle {
                x: 4 + pestanas.i * pestanas.tramo
                y: 4
                width: pestanas.tramo
                height: parent.height - 8
                radius: Tema.esquina(10)
                color: pagina.tinte(0.2)
                border.width: 1.5
                border.color: pagina.acento
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }
            Repeater {
                model: [["󰓃", "Salida"], ["󰍬", "Entrada"], ["󰀻", "Apps"]]
                Item {
                    id: pes
                    required property var modelData
                    required property int index
                    readonly property bool on: pestanas.i === index
                    x: 4 + index * pestanas.tramo
                    y: 4
                    width: pestanas.tramo
                    height: pestanas.height - 8
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pes.modelData[0]
                            font.pixelSize: 14
                            color: pes.on ? pagina.acento : pesRaton.containsMouse ? Tema.texto : Tema.gris
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pes.modelData[1]
                            font.pixelSize: 11
                            font.bold: pes.on
                            color: pes.on ? Tema.blanco : pesRaton.containsMouse ? Tema.texto : Tema.gris
                        }
                    }
                    MouseArea {
                        id: pesRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pagina.pestana = pestanas.claves[pes.index]
                    }
                }
            }
        }

        // ------------------------------------------------------- La lista
        ListView {
            id: lista
            width: parent.width
            height: Math.min(contentHeight, Math.max(160, pagina.altoMax - 260))
            visible: count > 0
            clip: true
            spacing: 4
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            readonly property bool deEntrada: pagina.pestana === "entrada"
            readonly property bool deApps: pagina.pestana === "apps"
            model: deApps ? pagina.apps : deEntrada ? pagina.entradas : pagina.salidas

            // Al cambiar de pestaña, la lista entra desde un lado
            property real lado: 0
            transform: Translate { x: lista.lado }
            Connections {
                target: pagina
                function onPestanaChanged() { cambio.restart(); }
            }
            SequentialAnimation {
                id: cambio
                PropertyAction { target: lista; property: "lado"; value: 24 }
                NumberAnimation { target: lista; property: "lado"; to: 0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }

            delegate: Item {
                id: fila
                required property var modelData
                required property int index
                readonly property var n: modelData
                readonly property bool app: lista.deApps
                readonly property bool elegida: !app && n === (lista.deEntrada ? pagina.entrada : pagina.salida)
                width: ListView.view.width
                height: app || elegida ? 66 : 52
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                opacity: 0
                property real baja: -8
                transform: Translate { y: fila.baja }
                Component.onCompleted: filaEntra.start()
                SequentialAnimation {
                    id: filaEntra
                    PauseAnimation { duration: Ajustes.animaciones ? Math.min(fila.index, 8) * 35 : 0 }
                    ParallelAnimation {
                        NumberAnimation { target: fila; property: "opacity"; to: 1; duration: Tema.normal }
                        NumberAnimation { target: fila; property: "baja"; to: 0; duration: Tema.rebote * 0.8; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                }

                HoverHandler { id: filaHover }
                Rectangle {
                    anchors.fill: parent
                    radius: Tema.esquina(14)
                    color: fila.elegida ? pagina.tinte(0.14) : filaHover.hovered ? Tema.caja : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                Rectangle {
                    x: 0; y: 16
                    width: 3; height: 20; radius: 1.5
                    color: pagina.acento
                    visible: fila.elegida
                }
                // Clic = usar este dispositivo
                MouseArea {
                    anchors.fill: parent
                    enabled: !fila.app && !fila.elegida
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (lista.deEntrada)
                            Pipewire.preferredDefaultAudioSource = fila.n;
                        else
                            Pipewire.preferredDefaultAudioSink = fila.n;
                    }
                }
                // El icono (en las apps, clic = silenciarla)
                Rectangle {
                    x: 10; y: 11
                    width: 32; height: 32
                    radius: Tema.esquina(10)
                    color: fila.elegida ? pagina.acento : Tema.caja
                    readonly property bool appMuda: fila.app && (fila.n.audio?.muted ?? false)
                    opacity: appMuda ? 0.45 : 1
                    IconImage {
                        id: iconoApp
                        anchors.centerIn: parent
                        implicitSize: 20
                        asynchronous: true
                        visible: fila.app && status === Image.Ready
                        source: fila.app && pagina.iconoApp(fila.n) !== "" ? Quickshell.iconPath(pagina.iconoApp(fila.n), true) : ""
                    }
                    Texto {
                        anchors.centerIn: parent
                        visible: !iconoApp.visible
                        text: fila.app ? (parent.appMuda ? "󰖁" : "󰎆") : pagina.glifo(fila.n, lista.deEntrada)
                        font.pixelSize: 16
                        color: fila.elegida ? Tema.oscuro : Tema.texto
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: fila.app
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (fila.n.audio) fila.n.audio.muted = !fila.n.audio.muted
                    }
                }
                Column {
                    x: 54
                    y: fila.app || fila.elegida ? 8 : 9
                    width: parent.width - 54 - 14
                    spacing: 1
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: pagina.nombre(fila.n)
                        textFormat: Text.PlainText
                        font.pixelSize: 13
                        font.bold: fila.elegida
                        color: fila.elegida ? pagina.acento : Tema.texto
                    }
                    Texto {
                        visible: !fila.app && !fila.elegida
                        text: pagina.tipo(fila.n, lista.deEntrada) + (fila.n.audio ? " · " + Math.round(fila.n.audio.volume * 100) + "%" : "")
                        font.bold: false
                        font.pixelSize: 10
                        color: Tema.gris
                    }
                }
                // El elegido y cada app: su volumen
                BarraVolumen {
                    id: suyo
                    visible: fila.app || fila.elegida
                    x: 54; y: 34
                    width: parent.width - 54 - 56
                    grueso: 6
                    valor: fila.n.audio?.volume ?? 0
                    apagado: fila.n.audio?.muted ?? false
                    onMovido: v => {
                        if (!fila.n.audio)
                            return;
                        if (fila.n.audio.muted && v > 0)
                            fila.n.audio.muted = false;
                        fila.n.audio.volume = v;
                    }
                }
                Texto {
                    visible: suyo.visible
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: suyo.verticalCenter }
                    text: Math.round(suyo.v * 100) + "%"
                    font.pixelSize: 11
                    color: suyo.apagado ? Tema.claro(0.4) : Tema.texto
                }
            }
        }

        // Vacío
        Column {
            visible: lista.count === 0
            width: parent.width
            topPadding: 16
            bottomPadding: 16
            spacing: 8
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lista.deEntrada ? "󰍭" : lista.deApps ? "󰀻" : "󰖁"
                font.pixelSize: 30
                color: Tema.claro(0.2)
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lista.deEntrada ? "No hay micrófono" : lista.deApps ? "Ninguna app está sonando" : "No hay salida de audio"
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
        }
    }
}
