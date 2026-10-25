// ============================================================================
//  Página «control»: el centro de control de las tres barras (Islas, Píldora
//  y Minimalista; ver Paginas.qml)
//
//    [󰖩 Wi-Fi      ] [󰂚 No molestar ]     icono = on/off · resto = su lista,
//    [󰂯 Bluetooth  ] [󰊴 Modo juego  ]     desplegada aquí debajo (SeccionWifi/Bluetooth)
//    [󰖔 Luz noct.  ] [󰅶 No suspender]
//    󰕾 ━━━━━━━━━○────────── 45%  󰅀       󰅀 = elegir salida / micrófono (aquí debajo)
//    󰍬 ━━━━━○────────────── 60%  󰅀
//    󰃠 ━━━━━━━━━━━━○─────── 80%           brillo, si alguna pantalla lo permite
//    [Ahorro] [Equilibrado] [Rendimiento]
//    [󰅌] [󰒓] [󰐥]                       portapapeles, ajustes y apagar
//    Notificaciones           Borrar
//    las tres últimas, o «Todo al día»
//
//  Con la barra en píldora (como ChillPill): arriba lo que suena y las
//  baldosas son botones anchos, de tres en tres: clic = encender/apagar ·
//  clic en › (o derecho) = su lista (wifi, bluetooth)
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.comun
import qs.bloqueo

Column {
    id: pagina

    required property var pantalla
    property bool activa: false
    // La lista desplegada: "wifi" · "bluetooth" · "audio" · "micro" · ""
    // (al abrir con Mod+Alt+N, B o A, Paneles.seccion trae la que toca)
    property string lista: ""
    onActivaChanged: lista = activa && ["wifi", "bluetooth", "audio", "micro"].includes(Paneles.seccion) ? Paneles.seccion : ""
    function elegir(l) { lista = lista === l ? "" : l; }
    spacing: 10

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var btConectados: Bluetooth.devices.values.filter(d => d.connected)

    component Redondo: Rectangle {
        id: redondo
        property string icono
        property string titulo
        property bool encendida: false
        property bool conLista: false
        property bool elegida: false
        signal alternar()
        signal elegir()
        height: 46
        radius: Tema.esquina(23)
        color: redondo.encendida ? Tema.claro(redondoRaton.containsMouse ? 0.20 : 0.15)
            : redondoRaton.containsMouse ? Tema.cajaHover : Tema.caja
        Behavior on color { ColorAnimation { duration: Tema.rapida } }
        border.width: redondo.elegida ? 1 : 0
        border.color: Tema.claro(0.5)
        scale: redondoRaton.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

        MouseArea {
            id: redondoRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => e.button === Qt.RightButton && redondo.conLista ? redondo.elegir() : redondo.alternar()
        }
        Texto {
            id: redondoIcono
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: redondo.icono
            font.pixelSize: 16
            color: redondo.encendida ? Tema.blanco : Tema.gris
        }
        Texto {
            anchors { left: redondoIcono.right; leftMargin: 10; right: flecha.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            text: redondo.titulo
            font.pixelSize: 12
            color: redondo.encendida ? Tema.texto : Tema.gris
        }
        // › = su lista
        Texto {
            id: flecha
            anchors { right: parent.right; rightMargin: redondo.conLista ? 14 : 0; verticalCenter: parent.verticalCenter }
            visible: redondo.conLista
            width: redondo.conLista ? implicitWidth : 0
            text: "󰅂"
            font.pixelSize: 14
            color: flechaRaton.containsMouse ? Tema.blanco : Tema.gris
            MouseArea {
                id: flechaRaton
                anchors { fill: parent; margins: -8 }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: redondo.elegir()
            }
        }
    }

    // Lo que suena, arriba (como ChillPill; solo con la píldora)
    Loader {
        width: parent.width
        active: Ajustes.pildora
        visible: item?.visible ?? false
        sourceComponent: MusicaBloqueo {
            width: pagina.width
            color: Tema.caja
            border.width: 0
        }
    }

    // ------------------------------------- Botones anchos (píldora)
    Grid {
        visible: Ajustes.pildora
        width: parent.width
        columns: 3
        spacing: 8
        readonly property real ancho: (width - 2 * spacing) / 3
        Redondo {
            width: parent.ancho
            icono: Networking.wifiEnabled ? "󰖩" : "󰖪"
            titulo: pagina.redWifi ? pagina.redWifi.name : "Wi-Fi"
            encendida: Networking.wifiEnabled
            conLista: true
            elegida: pagina.lista === "wifi"
            onAlternar: Networking.wifiEnabled = !Networking.wifiEnabled
            onElegir: pagina.elegir("wifi")
        }
        Redondo {
            width: parent.ancho
            icono: pagina.adaptador?.enabled ? "󰂯" : "󰂲"
            titulo: pagina.btConectados.length === 1 ? pagina.btConectados[0].name : "Bluetooth"
            encendida: pagina.adaptador?.enabled ?? false
            conLista: true
            elegida: pagina.lista === "bluetooth"
            onAlternar: Radios.alternarBluetooth()
            onElegir: pagina.elegir("bluetooth")
        }
        Redondo {
            width: parent.ancho
            icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
            titulo: "No molestar"
            encendida: Notificaciones.noMolestar
            onAlternar: Notificaciones.noMolestar = !Notificaciones.noMolestar
        }
        Redondo {
            width: parent.ancho
            icono: "󰊴"
            titulo: "Juego"
            encendida: Juego.activo
            onAlternar: Juego.activo ? Juego.terminar() : Juego.empezar()
        }
        Redondo {
            width: parent.ancho
            icono: "󰖔"
            titulo: "Luz noct."
            encendida: LuzNocturna.encendida
            property string ultimo: "auto"
            onAlternar: {
                if (LuzNocturna.encendida) {
                    ultimo = Ajustes.luzNocturna;
                    Ajustes.luzNocturna = "apagada";
                } else {
                    Ajustes.luzNocturna = ultimo;
                }
            }
        }
        Redondo {
            width: parent.ancho
            icono: "󰅶"
            titulo: "Despierto"
            encendida: Despierto.activo
            onAlternar: Despierto.activo = !Despierto.activo
        }
    }

    // ------------------------------------------------------------ Baldosas
    Grid {
        visible: !Ajustes.pildora
        width: parent.width
        columns: 2
        spacing: 8
        readonly property real ancho: (width - spacing) / 2

        Baldosa {
            width: parent.ancho
            conFlecha: false
            icono: Networking.wifiEnabled ? "󰖩" : "󰖪"
            titulo: "Wi-Fi"
            detalle: pagina.redWifi ? pagina.redWifi.name : Networking.wifiEnabled ? "Sin conectar" : "Apagado"
            encendida: Networking.wifiEnabled
            onAlternar: Networking.wifiEnabled = !Networking.wifiEnabled
            elegida: pagina.lista === "wifi"
            onElegir: pagina.elegir("wifi")
        }
        Baldosa {
            width: parent.ancho
            conFlecha: false
            icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
            titulo: "No molestar"
            detalle: Notificaciones.noMolestar ? "Solo urgentes" : "Apagado"
            encendida: Notificaciones.noMolestar
            onAlternar: Notificaciones.noMolestar = !Notificaciones.noMolestar
            onElegir: Notificaciones.noMolestar = !Notificaciones.noMolestar
        }
        Baldosa {
            width: parent.ancho
            conFlecha: false
            icono: pagina.adaptador?.enabled ? "󰂯" : "󰂲"
            titulo: "Bluetooth"
            detalle: !pagina.adaptador ? "No disponible"
                : !pagina.adaptador.enabled ? "Apagado"
                : pagina.btConectados.length === 1 ? pagina.btConectados[0].name
                : pagina.btConectados.length > 1 ? pagina.btConectados.length + " conectados"
                : "Encendido"
            encendida: pagina.adaptador?.enabled ?? false
            onAlternar: Radios.alternarBluetooth()
            elegida: pagina.lista === "bluetooth"
            onElegir: pagina.elegir("bluetooth")
        }
        // A mano: sin avisos y con el mando en la barra (la CPU la pone a
        // tope gamemode al abrir un juego, ver comun/Juego.qml)
        Baldosa {
            width: parent.ancho
            conFlecha: false
            icono: "󰊴"
            titulo: "Modo juego"
            detalle: Juego.activo ? "Sin avisos" : "Apagado"
            encendida: Juego.activo
            onAlternar: Juego.activo ? Juego.terminar() : Juego.empezar()
            onElegir: alternar()
        }
        Baldosa {
            width: parent.ancho
            conFlecha: false
            icono: "󰖔"
            titulo: "Luz nocturna"
            detalle: !LuzNocturna.instalada ? "Falta wlsunset"
                : Ajustes.luzNocturna === "auto" ? "Al anochecer"
                : Ajustes.luzNocturna === "siempre" ? "Siempre" : "Apagada"
            encendida: LuzNocturna.encendida
            property string ultimo: "auto"     // el modo al que vuelve al encenderla
            onAlternar: {
                if (LuzNocturna.encendida) {
                    ultimo = Ajustes.luzNocturna;
                    Ajustes.luzNocturna = "apagada";
                } else {
                    Ajustes.luzNocturna = ultimo;
                }
            }
            onElegir: alternar()
        }
        Baldosa {
            width: parent.ancho
            conFlecha: false
            icono: "󰅶"
            titulo: "No suspender"
            detalle: Despierto.activo ? "Activado" : "Apagado"
            encendida: Despierto.activo
            onAlternar: Despierto.activo = !Despierto.activo
            onElegir: alternar()
        }
    }

    // Lista de redes o de dispositivos, desplegada aquí mismo (clic en el
    // resto de su baldosa; otra vez = recogerla)
    SeccionWifi {
        visible: pagina.lista === "wifi"
        width: parent.width
        activa: pagina.activa && pagina.lista === "wifi"
    }
    SeccionBluetooth {
        visible: pagina.lista === "bluetooth"
        width: parent.width
        activa: pagina.activa && pagina.lista === "bluetooth"
    }

    // ------------------------------------------- Volumen, micro y brillo
    Column {
        width: parent.width
        FilaVolumen {
            width: parent.width
            nodo: Pipewire.defaultAudioSink
            elegida: pagina.lista === "audio"
            onElegir: pagina.elegir("audio")
        }
        SeccionAudio {
            visible: pagina.lista === "audio"
            width: parent.width
        }
        FilaVolumen {
            width: parent.width
            nodo: Pipewire.defaultAudioSource
            iconoOn: "󰍬"
            iconoOff: "󰍭"
            elegida: pagina.lista === "micro"
            onElegir: pagina.elegir("micro")
        }
        SeccionAudio {
            visible: pagina.lista === "micro"
            width: parent.width
            entrada: true
        }
        Repeater {
            model: Brillo.pantallas
            FilaBrillo {
                required property var modelData
                width: parent.width
                pantalla: modelData
                conNombre: Brillo.pantallas.length > 1
            }
        }
    }

    SelectorEnergia {
        width: parent.width
    }

    // ------------------------------------------------- Accesos rápidos
    Row {
        width: parent.width
        spacing: 6
        Repeater {
            model: [
                {icono: "󰅌", texto: "Copiado", accion: () => Paneles.alternar("portapapeles", pagina.pantalla, "")},
                {icono: "󰒓", texto: "Ajustes", accion: () => Paneles.alternar("ajustes", pagina.pantalla, "")},
                {icono: "󰐥", texto: "Apagar", accion: () => Paneles.alternar("apagado", pagina.pantalla, "")}
            ]
            Rectangle {
                id: acceso
                required property var modelData
                width: (pagina.width - 2 * 6) / 3
                height: 54
                radius: Tema.esquina(12)
                color: accesoRaton.containsMouse ? Tema.cajaHover : Tema.caja
                Behavior on color { ColorAnimation { duration: Tema.rapida } }
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: acceso.modelData.icono
                        font.pixelSize: 17
                        color: Tema.blanco
                    }
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: acceso.modelData.texto
                        font.bold: false
                        font.pixelSize: 10
                        color: Tema.gris
                    }
                }
                MouseArea {
                    id: accesoRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: acceso.modelData.accion()
                }
            }
        }
    }

    // ------------------------------------------------------ Notificaciones
    Rectangle {
        width: parent.width
        height: avisos.implicitHeight + 16
        radius: Tema.esquina(12)
        color: Tema.caja

        Column {
            id: avisos
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 4

            Item {
                width: parent.width
                height: 22
                Texto {
                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    text: "Notificaciones"
                    font.pixelSize: 11
                    color: Tema.gris
                }
                Texto {
                    visible: Notificaciones.cuantas > 0
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: "Borrar"
                    font.pixelSize: 11
                    color: borrarRaton.containsMouse ? Tema.blanco : Tema.gris
                    MouseArea {
                        id: borrarRaton
                        anchors { fill: parent; margins: -4 }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notificaciones.borrarTodas()
                    }
                }
            }

            Texto {
                visible: Notificaciones.cuantas === 0
                width: parent.width
                height: 34
                horizontalAlignment: Text.AlignHCenter
                text: "󰄬  Todo al día"
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }

            Repeater {
                model: Notificaciones.lista.slice(0, 3)
                Rectangle {
                    id: aviso
                    required property var modelData
                    width: avisos.width
                    height: 44
                    radius: Tema.esquina(8)
                    color: avisoRaton.containsMouse ? Tema.cajaHover : "transparent"

                    Rectangle {
                        id: letra
                        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                        width: 28; height: 28; radius: 14
                        color: Tema.claro(0.10)
                        Texto {
                            anchors.centerIn: parent
                            text: (Notificaciones.app(aviso.modelData.n) || "?").charAt(0).toUpperCase()
                            font.pixelSize: 12
                        }
                    }
                    Column {
                        anchors { left: letra.right; leftMargin: 10; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        Texto {
                            width: parent.width
                            text: aviso.modelData.n.summary
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: Tema.blanco
                        }
                        Texto {
                            width: parent.width
                            text: Notificaciones.app(aviso.modelData.n) + " · " + Notificaciones.hace(aviso.modelData.hora)
                            elide: Text.ElideRight
                            font.bold: false
                            font.pixelSize: 10
                            color: Tema.gris
                        }
                    }
                    MouseArea {
                        id: avisoRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: e => e.button === Qt.MiddleButton
                            ? Notificaciones.descartar(aviso.modelData) : Notificaciones.abrir(aviso.modelData)
                    }
                }
            }
        }
    }
}
