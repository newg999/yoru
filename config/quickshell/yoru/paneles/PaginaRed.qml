// ============================================================================
//  Página «red» de las islas (la ficha del wifi), con el aspecto del panel
//  de red del dock (el antiguo estilo Dock):
//
//    ‹ Red                                   ⟳     ‹ cerrar · ⟳ buscar redes
//    ┌──────────────────────────────────────┐
//    │ (󰖩)  TP-Link_6310_5G                 │     la conexión de ahora
//    │      Wi-Fi · 81% · 192.168.1.32      │
//    └──────────────────────────────────────┘
//    [Wi-Fi ●] [Ethernet ●] [Bluetooth ●] [VPN ●]   clic = encender/apagar
//                                                   › = su lista aquí debajo
//    REDES                              7 redes     (o DISPOSITIVOS / VPN)
//    ▌ılll TP-Link_6310_5G   [Desconectar]
//      ıll  MOVISTAR_C7A3            󰌾           clic = conectar (contraseña
//                                                si es nueva y con candado)
//  La lógica de las redes es la de SeccionWifi.qml; la de Bluetooth, la de
//  SeccionBluetooth.qml; las VPN, comun/Vpn.qml.
//  La página «bt» de las islas es esta misma en modo Bluetooth (esBt): su
//  propia cabecera, una tarjeta con el estado (clic = encender/apagar) y la
//  lista de dispositivos, sin las teclas de Wi-Fi/Ethernet/VPN. Y la de red
//  ya no lleva Bluetooth: cada una va por su lado.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.comun

Item {
    id: pagina

    property var pantalla: null
    property bool activa: false
    property int altoMax: 700
    // La lista de abajo: "wifi", "bt" o "vpn" (al abrir, la de «inicial»)
    property string inicial: "wifi"
    property string vista: "wifi"
    // Página de Bluetooth (sola) en vez de la de red
    readonly property bool esBt: inicial === "bt"
    onInicialChanged: if (activa) vista = inicial
    onActivaChanged: {
        if (activa) {
            vista = inicial;
            ip.running = true;
            Vpn.leer();
        } else {
            pidiendo = "";
        }
    }

    readonly property color acento: Tema.blanco
    function tinte(a) { return Tema.conAlfa(acento, a); }

    // ------------------------------------------------------------ Estado
    readonly property var dispositivos: Networking.devices.values
    readonly property var wifi: dispositivos.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var cable: dispositivos.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool conCable: cable?.connected ?? false
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property int senalWifi: redWifi ? Math.round(redWifi.signalStrength * 100) : 0
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property bool btOn: adaptador?.enabled ?? false
    readonly property var btConectados: aparatos.filter(d => d.connected)
    readonly property var aparatos: {
        if (!adaptador)
            return [];
        // Los que no tienen nombre (solo la dirección) no dicen nada: fuera
        return adaptador.devices.values
            .filter(d => d.paired || (d.name && d.name.replace(/[-:]/g, "") !== d.address.replace(/[-:]/g, "")))
            .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
    }
    // Buscar aparatos solo mientras se ve su lista
    Binding {
        when: pagina.adaptador !== null
        target: pagina.adaptador
        property: "discovering"
        value: pagina.activa && pagina.vista === "bt" && pagina.btOn
    }
    function iconoBt(d) {
        const i = d?.icon ?? "";
        if (i.includes("headset")) return "󰋎";
        if (i.includes("headphone") || i.includes("audio")) return "󰋋";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("gaming")) return "󰊴";
        if (i.includes("phone")) return "󰏲";
        if (i.includes("computer")) return "󰟀";
        return "󰂯";
    }

    readonly property var redes: {
        if (!wifi)
            return [];
        // La misma red puede salir varias veces (varios puntos de acceso)
        const vistas = new Map();
        for (const r of wifi.networks.values) {
            if (!r.name)
                continue;
            const previa = vistas.get(r.name);
            if (!previa || r.connected || (!previa.connected && r.signalStrength > previa.signalStrength))
                vistas.set(r.name, r);
        }
        return [...vistas.values()].sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }
    function segura(red) {
        return red.security !== WifiSecurityType.Open && red.security !== WifiSecurityType.Owe;
    }

    property string pidiendo: ""       // red a la que se está escribiendo la contraseña

    // Buscar redes solo mientras se ve (gasta batería)
    Binding {
        when: pagina.wifi !== null
        target: pagina.wifi
        property: "scannerEnabled"
        value: pagina.activa && Networking.wifiEnabled
    }
    // «buscando…» un rato tras pedirlo (el escáner no dice cuándo acaba)
    Timer { id: buscando; interval: 3000 }
    function buscar() {
        if (!wifi || !Networking.wifiEnabled)
            return;
        wifi.scannerEnabled = false;
        wifi.scannerEnabled = true;
        buscando.restart();
    }

    // La IP de la conexión de ahora
    property var ips: ({})             // interfaz → IP
    Process {
        id: ip
        command: ["ip", "-4", "-br", "addr"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.split("\n")) {
                    const p = l.trim().split(/\s+/);
                    if (p.length >= 3)
                        m[p[0]] = p[2].split("/")[0];
                }
                pagina.ips = m;
            }
        }
    }
    onConCableChanged: ip.running = true
    onRedWifiChanged: ip.running = true

    // Cada caja aparece subiendo un poco, una detrás de otra
    property real entrada: 0
    onVisibleChanged: if (visible) animEntrada.restart()
    NumberAnimation {
        id: animEntrada
        target: pagina; property: "entrada"
        from: 0; to: 1; duration: Tema.rebote * 1.2
        easing.type: Easing.OutCubic
    }

    implicitHeight: columna.implicitHeight

    // ---------------------------------------------------- Piezas sueltas
    // Barras de señal (4, se llenan según la fuerza)
    component Barras: Row {
        id: barras
        property int senal: 0
        property color on: Tema.texto
        property color off: Tema.claro(0.15)
        height: 14
        spacing: 2
        // Cuántas se encienden: una por cada cuarto de señal (con algo, una)
        readonly property int encendidas: senal <= 0 ? 0 : Math.min(4, Math.ceil(senal / 25))
        Repeater {
            model: 4
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 2.5
                height: barras.height * (index + 1) / 4
                radius: width / 2
                color: index < barras.encendidas ? barras.on : barras.off
                Behavior on color { ColorAnimation { duration: Tema.normal } }
            }
        }
    }
    // Un icono que se puede pulsar
    component Icono: Item {
        id: ic
        property string texto: ""
        property int tam: 18
        property color color: Tema.gris
        property bool girando: false
        signal clic()
        width: 26; height: 26
        Texto {
            id: glifo
            anchors.centerIn: parent
            text: ic.texto
            font.pixelSize: ic.tam
            color: icRaton.containsMouse || ic.girando ? pagina.acento : ic.color
            scale: icRaton.pressed ? 0.85 : icRaton.containsMouse ? 1.12 : 1
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
            Behavior on scale { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
            RotationAnimation on rotation { running: ic.girando; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }
        Connections {
            target: ic
            function onGirandoChanged() { if (!ic.girando) glifo.rotation = 0; }
        }
        MouseArea {
            id: icRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ic.clic()
        }
    }

    Column {
        id: columna
        width: parent.width
        spacing: 12

        // ------------------------------------------------------ Cabecera
        Item {
            width: parent.width
            height: 26
            opacity: Math.min(1, pagina.entrada * 3)
            Icono {
                id: atras
                texto: "󰅁"
                tam: 20
                color: Tema.texto
                onClic: Paneles.cerrar()
            }
            Texto {
                anchors { left: atras.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: pagina.esBt ? "Bluetooth" : "Red"
                font.pixelSize: 16
                color: Tema.blanco
            }
            Icono {
                anchors.right: parent.right
                texto: "󰑐"
                girando: pagina.vista === "bt" ? (pagina.adaptador?.discovering ?? false)
                    : buscando.running || (pagina.vista === "vpn" && Vpn.ocupada !== "")
                opacity: pagina.vista === "vpn" || (pagina.vista === "bt" ? pagina.btOn : Networking.wifiEnabled) ? 1 : 0.3
                onClic: {
                    if (pagina.vista === "vpn") {
                        Vpn.leer();
                    } else if (pagina.vista === "bt") {
                        if (pagina.adaptador && pagina.btOn) {
                            pagina.adaptador.discovering = false;
                            pagina.adaptador.discovering = true;
                        }
                    } else {
                        pagina.buscar();
                    }
                }
            }
        }

        // ------------------------------------- La conexión de ahora
        Rectangle {
            id: actual
            readonly property bool bt: pagina.esBt
            readonly property bool eth: !bt && pagina.conCable
            readonly property bool wifi: !bt && !eth && pagina.redWifi !== null
            readonly property bool online: bt ? pagina.btOn : eth || wifi
            readonly property var btPrimero: pagina.btConectados[0] ?? null
            width: parent.width
            height: 78
            radius: Tema.esquina(18)
            color: online ? pagina.tinte(bt && tarjetaRaton.containsMouse ? 0.2 : 0.13)
                : bt && tarjetaRaton.containsMouse ? Tema.cajaHover : Tema.caja
            border.width: 1
            border.color: online ? pagina.tinte(0.35) : Tema.claro(0.08)
            Behavior on color { ColorAnimation { duration: Tema.normal } }
            opacity: Math.min(1, pagina.entrada * 2)
            transform: Translate { y: -(1 - pagina.entrada) * 16 }

            // En Bluetooth la tarjeta entera enciende/apaga
            MouseArea {
                id: tarjetaRaton
                anchors.fill: parent
                enabled: actual.bt && pagina.adaptador !== null
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Radios.alternarBluetooth()
            }
            Rectangle {
                visible: actual.bt
                opacity: pagina.adaptador ? 1 : 0.35
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                width: 34; height: 20; radius: 10
                color: pagina.btOn ? pagina.acento : Tema.claro(0.15)
                Behavior on color { ColorAnimation { duration: Tema.normal } }
                Rectangle {
                    width: 14; height: 14; radius: 7
                    y: 3
                    x: pagina.btOn ? parent.width - width - 3 : 3
                    color: pagina.btOn ? Tema.oscuro : Tema.gris
                    Behavior on x { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
                }
            }

            // El icono, con una onda que se expande mientras hay conexión
            Item {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 46; height: 46
                // Un aro que se abre y se apaga, una y otra vez
                Rectangle {
                    id: aro
                    anchors.centerIn: parent
                    width: parent.width; height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: pagina.acento
                    visible: actual.online
                    property real abre: 0
                    scale: 1 + 0.45 * abre
                    opacity: 0.6 * (1 - abre) * (1 - abre)
                    SequentialAnimation on abre {
                        running: actual.online && pagina.activa && Ajustes.animaciones
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 1; duration: 2000; easing.type: Easing.OutQuad }
                        PauseAnimation { duration: 300 }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: actual.online ? pagina.acento : Tema.claro(0.08)
                    Behavior on color { ColorAnimation { duration: Tema.normal } }
                    Texto {
                        anchors.centerIn: parent
                        text: actual.bt ? (!pagina.btOn ? "󰂲" : actual.btPrimero ? "󰂱" : "󰂯")
                            : actual.eth ? "󰈀"
                            : actual.wifi ? ["󰤟", "󰤢", "󰤥", "󰤨"][Math.min(3, Math.floor(pagina.senalWifi / 25))]
                            : "󰤭"
                        font.pixelSize: 22
                        color: actual.online ? Tema.oscuro : Tema.gris
                    }
                }
            }
            Column {
                x: 72
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 72 - (actual.bt ? 64 : 14)
                spacing: 3
                Texto {
                    width: parent.width
                    elide: Text.ElideRight
                    text: actual.bt ? (!pagina.adaptador ? "Sin Bluetooth" : !pagina.btOn ? "Bluetooth apagado"
                            : actual.btPrimero ? actual.btPrimero.name : "Bluetooth encendido")
                        : actual.eth ? "Ethernet" : actual.wifi ? pagina.redWifi.name : "Sin conexión"
                    textFormat: Text.PlainText
                    font.pixelSize: 15
                    color: Tema.blanco
                }
                Texto {
                    width: parent.width
                    elide: Text.ElideRight
                    readonly property string dir: actual.eth ? (pagina.ips[pagina.cable?.name] ?? "")
                        : (pagina.ips[pagina.wifi?.name] ?? "")
                    text: actual.bt ? (!pagina.adaptador ? "No hay adaptador en este equipo"
                            : !pagina.btOn ? "Pulsa para encenderlo"
                            : actual.btPrimero ? "Conectado"
                                + (actual.btPrimero.batteryAvailable ? " · " + Math.round(actual.btPrimero.battery * 100) + "%" : "")
                                + (pagina.btConectados.length > 1 ? " · y " + (pagina.btConectados.length - 1) + " más" : "")
                            : "Ningún dispositivo conectado")
                        : actual.eth ? "Por cable" + (dir ? " · " + dir : "")
                        : actual.wifi ? "Wi-Fi · " + pagina.senalWifi + "%" + (dir ? " · " + dir : "")
                        : Networking.wifiEnabled ? "Elige una red aquí debajo" : "El wifi está apagado"
                    font.bold: false
                    font.pixelSize: 11
                    color: actual.online ? Tema.texto : Tema.gris
                }
            }
        }

        // ------------------------------------- Wi-Fi · Ethernet · VPN
        Row {
            id: interruptores
            visible: !pagina.esBt
            width: parent.width
            spacing: 8
            opacity: Math.min(1, Math.max(0, pagina.entrada * 2 - 0.2))
            transform: Translate { y: -(1 - pagina.entrada) * 22 }

            Repeater {
                model: [
                    {nombre: "Wi-Fi", hay: pagina.wifi !== null, on: Networking.wifiEnabled,
                     icono: Networking.wifiEnabled ? "󰖩" : "󰖪", lista: "wifi"},
                    {nombre: "Ethernet", hay: pagina.cable !== null, on: pagina.conCable,
                     icono: "󰈀", lista: ""},
                    {nombre: "VPN", hay: true, on: Vpn.conectadas.length > 0,
                     icono: "󰦝", lista: "vpn"}
                ]

                Rectangle {
                    id: tecla
                    required property var modelData
                    required property int index
                    readonly property bool on: modelData.on
                    readonly property bool elegida: modelData.lista !== "" && modelData.lista === pagina.vista
                    width: (interruptores.width - 2 * interruptores.spacing) / 3
                    height: 80
                    radius: Tema.esquina(16)
                    color: on ? pagina.tinte(teclaRaton.containsMouse ? 0.28 : 0.2)
                        : teclaRaton.containsMouse ? Tema.cajaHover : Tema.caja
                    border.width: 1
                    border.color: on ? pagina.tinte(0.5) : Tema.claro(0.08)
                    opacity: modelData.hay ? 1 : 0.35
                    scale: teclaRaton.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Tema.normal } }

                    function alternar() {
                        switch (modelData.nombre) {
                        case "Wi-Fi":
                            Networking.wifiEnabled = !Networking.wifiEnabled;
                            break;
                        case "Ethernet":
                            Quickshell.execDetached(["nmcli", "device", on ? "disconnect" : "connect", pagina.cable.name]);
                            break;
                        case "VPN":
                            if (Vpn.conectadas.length > 0)
                                Vpn.conectadas.forEach(v => Vpn.alternar(v));
                            else if (Vpn.lista.length === 1)
                                Vpn.alternar(Vpn.lista[0]);
                            else
                                pagina.vista = "vpn";
                            break;
                        }
                    }

                    MouseArea {
                        id: teclaRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: tecla.modelData.hay
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tecla.alternar()
                    }

                    Texto {
                        x: 10; y: 9
                        text: tecla.modelData.icono
                        font.pixelSize: 18
                        color: tecla.on ? pagina.acento : Tema.gris
                        opacity: tecla.modelData.lista === "vpn" && Vpn.ocupada !== "" ? 0.4 : 1
                        SequentialAnimation on opacity {
                            running: tecla.modelData.lista === "vpn" && Vpn.ocupada !== ""
                            loops: Animation.Infinite
                            NumberAnimation { to: 1; duration: Tema.ms(520); easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.35; duration: Tema.ms(520); easing.type: Easing.InOutQuad }
                        }
                    }
                    // El interruptor pequeño
                    Rectangle {
                        x: parent.width - width - 10; y: 13
                        width: 24; height: 14; radius: 7
                        color: tecla.on ? pagina.acento : Tema.claro(0.15)
                        Behavior on color { ColorAnimation { duration: Tema.normal } }
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            y: 2
                            x: tecla.on ? parent.width - width - 2 : 2
                            color: tecla.on ? Tema.oscuro : Tema.gris
                            Behavior on x { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
                        }
                    }
                    Texto {
                        x: 10; y: 40
                        text: tecla.modelData.nombre
                        font.pixelSize: 10
                        color: tecla.on ? Tema.blanco : Tema.gris
                    }
                    // › su lista aquí debajo
                    Rectangle {
                        visible: tecla.modelData.lista !== ""
                        x: parent.width - width - 7
                        y: parent.height - height - 8
                        width: 18; height: 18; radius: 6
                        color: "transparent"
                        scale: flechaRaton.pressed ? 0.88 : flechaRaton.containsMouse ? 1.1 : 1
                        Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
                        Texto {
                            anchors.centerIn: parent
                            text: "󰅂"
                            font.pixelSize: 16
                            color: tecla.elegida ? pagina.acento : flechaRaton.containsMouse ? Tema.blanco : Tema.gris
                            rotation: tecla.elegida ? 90 : 0
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            Behavior on rotation { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
                        }
                        MouseArea {
                            id: flechaRaton
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pagina.vista = tecla.modelData.lista
                        }
                    }
                }
            }
        }

        // --------------------------------------------- Título de la lista
        Item {
            width: parent.width
            height: 16
            opacity: Math.min(1, Math.max(0, pagina.entrada * 2 - 0.4))
            Texto {
                x: 2
                text: pagina.vista === "vpn" ? "VPN" : pagina.vista === "bt" ? "DISPOSITIVOS" : "REDES"
                font.pixelSize: 11
                font.letterSpacing: 1.6
                color: Tema.gris
            }
            Texto {
                anchors.right: parent.right
                anchors.rightMargin: 2
                readonly property bool busca: pagina.vista === "wifi" ? buscando.running
                    : pagina.vista === "bt" && (pagina.adaptador?.discovering ?? false)
                text: busca ? "buscando…"
                    : pagina.vista === "vpn" ? (Vpn.lista.length > 0 ? Vpn.lista.length + " VPN" : "")
                    : pagina.vista === "bt" ? (pagina.btOn && pagina.aparatos.length > 0 ? pagina.aparatos.length + (pagina.aparatos.length === 1 ? " dispositivo" : " dispositivos") : "")
                    : Networking.wifiEnabled && pagina.redes.length > 0 ? pagina.redes.length + (pagina.redes.length === 1 ? " red" : " redes") : ""
                font.bold: false
                font.pixelSize: 10
                color: busca ? pagina.acento : Tema.claro(0.4)
            }
        }

        // Sin aparatos / Bluetooth apagado (un icono grande y el aviso)
        Column {
            visible: pagina.vista === "bt" && (!pagina.btOn || pagina.aparatos.length === 0)
            width: parent.width
            topPadding: 16
            bottomPadding: 16
            spacing: 8
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pagina.btOn ? "󰂯" : "󰂲"
                font.pixelSize: 30
                color: Tema.claro(0.2)
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !pagina.adaptador ? "No hay Bluetooth en este equipo"
                    : !pagina.btOn ? "El Bluetooth está apagado"
                    : pagina.adaptador.discovering ? "Buscando dispositivos…" : "No hay dispositivos"
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
        }

        // Sin redes / wifi apagado / sin VPN
        Texto {
            readonly property string aviso: pagina.vista === "bt" ? ""
                : pagina.vista === "vpn"
                ? (Vpn.lista.length === 0 ? "No hay VPN guardadas" : "")
                : !Networking.wifiEnabled ? "El wifi está apagado"
                : pagina.redes.length === 0 ? "Buscando redes…" : ""
            visible: aviso !== ""
            width: parent.width
            height: 44
            horizontalAlignment: Text.AlignHCenter
            text: aviso
            font.bold: false
            font.pixelSize: 12
            color: Tema.gris
        }
        Texto {
            visible: pagina.vista === "vpn" && Vpn.error !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: Vpn.error
            font.bold: false
            font.pixelSize: 11
            color: Tema.rojo
        }

        // ------------------------------------------------- Las redes / VPN
        ListView {
            id: lista
            width: parent.width
            // Lo que quepa en la pantalla (lo de arriba ocupa unos 250)
            height: Math.min(contentHeight, Math.max(160, pagina.altoMax - 250))
            visible: count > 0
            clip: true
            spacing: 4
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: pagina.vista === "vpn" ? Vpn.lista : pagina.vista === "wifi" && Networking.wifiEnabled ? pagina.redes : []

            delegate: Item {
                id: fila
                required property var modelData
                required property int index
                readonly property bool esVpn: pagina.vista === "vpn"
                readonly property var red: modelData
                readonly property bool enUso: esVpn ? red.estado === "activa" : red.connected
                readonly property bool ocupada: esVpn ? Vpn.ocupada === red.uuid : red.stateChanging
                readonly property bool escribiendo: !esVpn && pagina.pidiendo === red.name
                width: ListView.view.width
                height: escribiendo ? 98 : 50
                Behavior on height { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

                // Entran una detrás de otra
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

                Connections {
                    target: fila.esVpn ? null : fila.red
                    ignoreUnknownSignals: true
                    // Contraseña incorrecta o que falta: se pide otra vez
                    function onConnectionFailed(motivo) {
                        if (pagina.segura(fila.red))
                            pagina.pidiendo = fila.red.name;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Tema.esquina(14)
                    color: fila.enUso ? pagina.tinte(0.14) : filaHover.hovered || fila.escribiendo ? Tema.caja : "transparent"
                    border.width: fila.escribiendo ? 1 : 0
                    border.color: pagina.tinte(0.4)
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                }
                // La rayita de la que está en uso
                Rectangle {
                    x: 0; y: 15
                    width: 3; height: 20; radius: 1.5
                    color: pagina.acento
                    visible: fila.enUso
                }
                HoverHandler { id: filaHover }
                MouseArea {
                    id: filaRaton
                    width: parent.width
                    height: 50
                    hoverEnabled: true
                    cursorShape: fila.enUso ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        const r = fila.red;
                        if (fila.esVpn) {
                            Vpn.alternar(r);
                        } else if (!r.connected) {
                            if (r.known || !pagina.segura(r))
                                r.connect();
                            else
                                pagina.pidiendo = fila.escribiendo ? "" : r.name;
                        }
                    }
                }

                Barras {
                    visible: !fila.esVpn
                    x: 14; y: 18
                    senal: fila.esVpn ? 0 : Math.round(fila.red.signalStrength * 100)
                    on: fila.enUso ? pagina.acento : Tema.texto
                }
                Texto {
                    visible: fila.esVpn
                    x: 14; y: 14
                    text: "󰦝"
                    font.pixelSize: 17
                    color: fila.enUso ? pagina.acento : Tema.texto
                }
                Column {
                    x: 44; y: 9
                    width: parent.width - 44 - derecha.width - 20
                    spacing: 2
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: fila.esVpn ? fila.red.nombre : fila.red.name
                        textFormat: Text.PlainText
                        font.pixelSize: 13
                        font.bold: fila.enUso
                        color: fila.enUso ? pagina.acento : Tema.texto
                    }
                    Texto {
                        text: fila.ocupada ? (fila.esVpn && fila.enUso ? "Desconectando…" : "Conectando…")
                            : fila.enUso ? "Conectado"
                            : fila.esVpn ? (fila.red.tipo === "wireguard" ? "WireGuard" : fila.red.tipo || "VPN")
                            : fila.red.known ? "Guardada"
                            : pagina.segura(fila.red) ? "Con contraseña" : "Abierta"
                        font.bold: false
                        font.pixelSize: 10
                        color: fila.ocupada ? pagina.acento : Tema.gris
                    }
                }

                // A la derecha: candado / desconectar / olvidar
                Row {
                    id: derecha
                    anchors { right: parent.right; rightMargin: 12 }
                    y: 13
                    height: 24
                    spacing: 6
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !fila.esVpn && pagina.segura(fila.red) && !fila.enUso && !fila.ocupada
                            && !(filaHover.hovered && fila.red.known)
                        text: "󰌾"
                        font.pixelSize: 13
                        color: Tema.claro(0.4)
                    }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: fila.ocupada
                        text: "󰑓"
                        font.pixelSize: 14
                        color: pagina.acento
                        RotationAnimation on rotation { running: fila.ocupada; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
                    }
                    // Olvidar (guardada, con el ratón encima)
                    Icono {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !fila.esVpn && fila.red.known && !fila.enUso && filaHover.hovered
                        width: 22; height: 22
                        texto: "󰆴"
                        tam: 14
                        onClic: fila.red.forget()
                    }
                    Rectangle {
                        visible: fila.enUso && !fila.ocupada
                        anchors.verticalCenter: parent.verticalCenter
                        width: textoDesc.implicitWidth + 18
                        height: 24
                        radius: Tema.esquina(8)
                        color: descRaton.containsMouse ? Tema.cajaHover : Tema.sombra(0.6)
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        scale: descRaton.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
                        Texto {
                            id: textoDesc
                            anchors.centerIn: parent
                            text: "Desconectar"
                            font.pixelSize: 11
                            color: Tema.blanco
                        }
                        MouseArea {
                            id: descRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fila.esVpn ? Vpn.alternar(fila.red) : fila.red.disconnect()
                        }
                    }
                }

                // Contraseña
                Rectangle {
                    visible: fila.escribiendo
                    x: 10
                    y: 54
                    width: parent.width - 20
                    height: 36
                    radius: Tema.esquina(10)
                    color: Tema.sombra(0.5)
                    border.width: 1
                    border.color: clave.activeFocus ? pagina.tinte(0.5) : Tema.claro(0.1)

                    TextInput {
                        id: clave
                        anchors { fill: parent; leftMargin: 12; rightMargin: 40 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: verClave.ver ? TextInput.Normal : TextInput.Password
                        color: Tema.texto
                        selectionColor: Tema.claro(0.3)
                        font.family: Tema.fuente
                        font.pixelSize: 13
                        clip: true
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                        onAccepted: {
                            if (text.length === 0)
                                return;
                            fila.red.connectWithPsk(text);
                            pagina.pidiendo = "";
                        }
                        Keys.onEscapePressed: pagina.pidiendo = ""

                        Texto {
                            visible: clave.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Contraseña (Enter para conectar)"
                            font.bold: false
                            font.pixelSize: 12
                            color: Tema.gris
                        }
                    }
                    Icono {
                        id: verClave
                        property bool ver: false
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        texto: ver ? "󰈈" : "󰈉"
                        tam: 15
                        onClic: ver = !ver
                    }
                }
            }
        }

        // ------------------------------------------- Los de Bluetooth
        ListView {
            id: listaBt
            width: parent.width
            height: Math.min(contentHeight, Math.max(160, pagina.altoMax - 160))
            visible: count > 0
            clip: true
            spacing: 4
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: pagina.vista === "bt" && pagina.btOn ? pagina.aparatos : []

            delegate: Item {
                id: aparato
                required property var modelData
                required property int index
                readonly property var d: modelData
                readonly property bool ocupado: d.pairing || d.state === BluetoothDeviceState.Connecting
                    || d.state === BluetoothDeviceState.Disconnecting
                property bool conectarTrasEmparejar: false
                width: ListView.view.width
                height: 50

                opacity: 0
                property real baja: -8
                transform: Translate { y: aparato.baja }
                Component.onCompleted: aparatoEntra.start()
                SequentialAnimation {
                    id: aparatoEntra
                    PauseAnimation { duration: Ajustes.animaciones ? Math.min(aparato.index, 8) * 35 : 0 }
                    ParallelAnimation {
                        NumberAnimation { target: aparato; property: "opacity"; to: 1; duration: Tema.normal }
                        NumberAnimation { target: aparato; property: "baja"; to: 0; duration: Tema.rebote * 0.8; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                }

                Connections {
                    target: aparato.d
                    function onPairedChanged() {
                        if (aparato.d.paired && aparato.conectarTrasEmparejar) {
                            aparato.conectarTrasEmparejar = false;
                            aparato.d.connect();
                        }
                    }
                }

                HoverHandler { id: aparatoHover }
                Rectangle {
                    anchors.fill: parent
                    radius: Tema.esquina(14)
                    color: aparato.d.connected ? pagina.tinte(0.14) : aparatoHover.hovered ? Tema.caja : "transparent"
                    Behavior on color { ColorAnimation { duration: Tema.rapida } }
                }
                Rectangle {
                    x: 0; y: 15
                    width: 3; height: 20; radius: 1.5
                    color: pagina.acento
                    visible: aparato.d.connected
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: aparato.d.connected ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        const d = aparato.d;
                        if (d.connected)
                            return;
                        if (d.paired) {
                            d.connect();
                        } else {
                            d.trusted = true;
                            aparato.conectarTrasEmparejar = true;
                            d.pair();
                        }
                    }
                }
                Rectangle {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30
                    radius: Tema.esquina(10)
                    color: aparato.d.connected ? pagina.acento : Tema.caja
                    Texto {
                        anchors.centerIn: parent
                        text: pagina.iconoBt(aparato.d)
                        font.pixelSize: 16
                        color: aparato.d.connected ? Tema.oscuro : Tema.texto
                    }
                }
                Column {
                    x: 50; y: 9
                    width: parent.width - 50 - derechaBt.width - 20
                    spacing: 2
                    Texto {
                        width: parent.width
                        elide: Text.ElideRight
                        text: aparato.d.name
                        textFormat: Text.PlainText
                        font.pixelSize: 13
                        font.bold: aparato.d.connected
                        color: aparato.d.connected ? pagina.acento : Tema.texto
                    }
                    Texto {
                        text: aparato.d.pairing ? "Emparejando…"
                            : aparato.d.state === BluetoothDeviceState.Connecting ? "Conectando…"
                            : aparato.d.state === BluetoothDeviceState.Disconnecting ? "Desconectando…"
                            : aparato.d.connected ? "Conectado" + (aparato.d.batteryAvailable ? " · " + Math.round(aparato.d.battery * 100) + "%" : "")
                            : aparato.d.paired ? "Emparejado" : "Nuevo"
                        font.bold: false
                        font.pixelSize: 10
                        color: aparato.ocupado ? pagina.acento : Tema.gris
                    }
                }
                Row {
                    id: derechaBt
                    anchors { right: parent.right; rightMargin: 12 }
                    y: 13
                    height: 24
                    spacing: 6
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: aparato.ocupado
                        text: "󰑓"
                        font.pixelSize: 14
                        color: pagina.acento
                        RotationAnimation on rotation { running: aparato.ocupado; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
                    }
                    // Olvidar (emparejado, con el ratón encima)
                    Rectangle {
                        visible: aparato.d.paired && !aparato.d.connected && aparatoHover.hovered && !aparato.ocupado
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22
                        radius: Tema.esquina(7)
                        color: olvidarRaton.containsMouse ? Tema.conAlfa(Tema.rojo, 0.25) : Tema.caja
                        Texto {
                            anchors.centerIn: parent
                            text: "󰆴"
                            font.pixelSize: 13
                            color: olvidarRaton.containsMouse ? Tema.rojo : Tema.gris
                        }
                        MouseArea {
                            id: olvidarRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: aparato.d.forget()
                        }
                    }
                    Rectangle {
                        visible: aparato.d.connected && !aparato.ocupado
                        anchors.verticalCenter: parent.verticalCenter
                        width: textoDescBt.implicitWidth + 18
                        height: 24
                        radius: Tema.esquina(8)
                        color: descBtRaton.containsMouse ? Tema.conAlfa(Tema.rojo, 0.25) : Tema.sombra(0.6)
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Texto {
                            id: textoDescBt
                            anchors.centerIn: parent
                            text: "Desconectar"
                            font.pixelSize: 11
                            color: descBtRaton.containsMouse ? Tema.rojo : Tema.blanco
                        }
                        MouseArea {
                            id: descBtRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: aparato.d.disconnect()
                        }
                    }
                }
            }
        }
    }
}
