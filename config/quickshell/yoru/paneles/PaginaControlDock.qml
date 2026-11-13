// ============================================================================
//  Página «control» de las islas (☰ a la derecha), con el aspecto de los
//  paneles del dock (el antiguo estilo Dock), también en la minimalista. La de Windows sigue
//  siendo PaginaControl.qml.
//
//    (夜) don                              󰅌 󰒓      portapapeles y ajustes
//         Fedora · encendido 3 h 20 min
//    [Wi-Fi ●›] [Bluetooth ●›] [No molestar ●]      clic = encender/apagar
//    [Juego ●]  [Luz noct. ●]  [No suspender ●]     › = su panel (red, bt)
//    ┌──────────────────────────────────────┐
//    │ 󰕾 ━━━━━━━━━━━━○──────  92%  ›         │     › = el panel de sonido
//    │ 󰍬 ━━━━━━━━━━━━━━━━━━○  100%           │     clic en el icono = silenciar
//    │ 󰃠 ━━━━━━━━━━━━━━━━━━○  100%           │
//    └──────────────────────────────────────┘
//    [ Ahorro | Equilibrado | Rendimiento ]
//    ENERGÍA     [󰌾] [󰤄] [󰍃] [󰜉] [󰐥]          los peligrosos: otra vez para confirmar
//    NOTIFICACIONES                  Borrar      las dos últimas
//  Basado en QsDock de LeyzS (MIT): ver LICENSES/QsDock-LeyzS.txt
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.comun

Item {
    id: pagina

    required property var pantalla
    property bool activa: false
    onActivaChanged: if (!activa) armado = -1

    readonly property color acento: Tema.blanco
    function tinte(a) { return Tema.conAlfa(acento, a); }

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redWifi: wifi?.networks.values.find(r => r.connected) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property var btConectados: Bluetooth.devices.values.filter(d => d.connected)
    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [pagina.salida, pagina.entrada] }

    function encendido(seg) {
        const min = Math.floor(seg / 60), h = Math.floor(min / 60), d = Math.floor(h / 24);
        return d > 0 ? d + " d " + (h % 24) + " h" : h > 0 ? h + " h " + (min % 60) + " min" : min + " min";
    }

    // Apagar y compañía: los peligrosos, dos veces (el primero los «arma»)
    property int armado: -1
    Timer { id: desarmar; interval: 3000; onTriggered: pagina.armado = -1 }
    function sesion(i) {
        const o = Sesion.opciones[i];
        if (o.peligrosa && armado !== i) {
            armado = i;
            desarmar.restart();
            return;
        }
        armado = -1;
        Sesion.elegir(o);
    }

    implicitHeight: columna.implicitHeight

    component Caja: Rectangle {
        radius: Tema.esquina(16)
        color: Tema.caja
        border.width: 1
        border.color: Tema.claro(0.08)
    }
    component Titulo: Texto {
        x: 2
        font.pixelSize: 11
        font.letterSpacing: 1.6
        color: Tema.gris
    }
    // Un icono que se pulsa (cabecera)
    component Icono: Texto {
        id: ic
        signal clic()
        width: 28; height: 28
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 17
        color: icRaton.containsMouse ? pagina.acento : Tema.gris
        scale: icRaton.pressed ? 0.85 : icRaton.containsMouse ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: Tema.rapida } }
        MouseArea { id: icRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ic.clic() }
    }
    // Interruptor como los del panel de red del dock
    component Tecla: Rectangle {
        id: tecla
        property string icono: ""
        property string nombre: ""
        property string detalle: ""
        property bool on: false
        property bool hay: true
        property bool conFlecha: false
        signal alternar()
        signal abrir()
        height: 80
        radius: Tema.esquina(16)
        color: on ? pagina.tinte(teclaRaton.containsMouse ? 0.28 : 0.2)
            : teclaRaton.containsMouse ? Tema.cajaHover : Tema.caja
        border.width: 1
        border.color: on ? pagina.tinte(0.5) : Tema.claro(0.08)
        opacity: hay ? 1 : 0.35
        scale: teclaRaton.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: Tema.normal } }
        MouseArea {
            id: teclaRaton
            anchors.fill: parent
            hoverEnabled: true
            enabled: tecla.hay
            cursorShape: Qt.PointingHandCursor
            onClicked: tecla.alternar()
        }
        Texto {
            x: 10; y: 9
            text: tecla.icono
            font.pixelSize: 18
            color: tecla.on ? pagina.acento : Tema.gris
        }
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
        Column {
            x: 10; y: 38
            width: parent.width - 20 - (tecla.conFlecha ? 18 : 0)
            spacing: 1
            Texto {
                width: parent.width
                elide: Text.ElideRight
                text: tecla.nombre
                font.pixelSize: 11
                color: tecla.on ? Tema.blanco : Tema.texto
            }
            Texto {
                width: parent.width
                elide: Text.ElideRight
                text: tecla.detalle
                textFormat: Text.PlainText
                font.bold: false
                font.pixelSize: 9
                color: Tema.gris
            }
        }
        Texto {
            visible: tecla.conFlecha
            x: parent.width - width - 8
            y: parent.height - height - 8
            width: 18; height: 18
            horizontalAlignment: Text.AlignHCenter
            text: "󰅂"
            font.pixelSize: 16
            color: flechaRaton.containsMouse ? Tema.blanco : Tema.gris
            scale: flechaRaton.pressed ? 0.88 : flechaRaton.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
            MouseArea {
                id: flechaRaton
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tecla.abrir()
            }
        }
    }
    // Una barra de volumen o brillo: icono · barra · %  (· ›)
    component FilaBarra: Item {
        id: fb
        property string icono: ""
        property real valor: 0
        property bool apagado: false
        property bool conFlecha: false
        signal movido(real v)
        signal icono_()
        signal abrir()
        width: parent?.width ?? 0
        height: 34
        Texto {
            id: fbIcono
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            horizontalAlignment: Text.AlignHCenter
            text: fb.icono
            font.pixelSize: 16
            color: fb.apagado ? Tema.claro(0.35) : fbRaton.containsMouse ? pagina.acento : Tema.texto
            MouseArea { id: fbRaton; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fb.icono_() }
        }
        BarraVolumen {
            id: fbBarra
            anchors { left: fbIcono.right; leftMargin: 10; right: fbPor.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            grueso: 8
            valor: fb.valor
            apagado: fb.apagado
            onMovido: v => fb.movido(v)
        }
        Texto {
            id: fbPor
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            width: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(fbBarra.v * 100) + "%"
            font.pixelSize: 12
            color: fb.apagado ? Tema.claro(0.4) : Tema.blanco
        }
        Texto {
            visible: fb.conFlecha
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 20
            horizontalAlignment: Text.AlignHCenter
            text: "󰅂"
            font.pixelSize: 16
            color: fbFlecha.containsMouse ? Tema.blanco : Tema.gris
            MouseArea { id: fbFlecha; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fb.abrir() }
        }
    }

    Column {
        id: columna
        width: parent.width
        spacing: 12

        // ------------------------------------------------- Quién eres
        Item {
            width: parent.width
            height: 48
            Row {
                spacing: 12
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: Tema.sombra(0.6)
                    border.width: 2
                    border.color: pagina.acento
                    Texto {
                        anchors.centerIn: parent
                        text: "夜"
                        font.pixelSize: 22
                        color: pagina.acento
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Texto {
                        text: Quickshell.env("USER") ?? ""
                        font.pixelSize: 17
                        color: Tema.blanco
                    }
                    Texto {
                        text: "Fedora · encendido " + pagina.encendido(Sistema.encendido)
                        font.bold: false
                        font.pixelSize: 11
                        color: Tema.gris
                    }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                Icono { text: "󰅌"; onClic: Paneles.alternar("portapapeles", pagina.pantalla, "") }
                Icono { text: "󰒓"; onClic: Paneles.alternar("ajustes", pagina.pantalla, "") }
            }
        }

        // ------------------------------------------------- Interruptores
        Grid {
            id: teclas
            width: parent.width
            columns: 3
            spacing: 8
            readonly property real ancho: (width - 2 * spacing) / 3

            Tecla {
                width: teclas.ancho
                icono: Networking.wifiEnabled ? "󰖩" : "󰖪"
                nombre: "Wi-Fi"
                detalle: pagina.redWifi ? pagina.redWifi.name : Networking.wifiEnabled ? "Sin conectar" : "Apagado"
                on: Networking.wifiEnabled
                conFlecha: true
                onAlternar: Networking.wifiEnabled = !Networking.wifiEnabled
                onAbrir: Paneles.abrirPagina(pagina.pantalla, "red", "derecha")
            }
            Tecla {
                width: teclas.ancho
                icono: pagina.adaptador?.enabled ? "󰂯" : "󰂲"
                nombre: "Bluetooth"
                hay: pagina.adaptador !== null
                detalle: !pagina.adaptador ? "No hay" : !pagina.adaptador.enabled ? "Apagado"
                    : pagina.btConectados.length === 1 ? pagina.btConectados[0].name
                    : pagina.btConectados.length > 1 ? pagina.btConectados.length + " conectados" : "Encendido"
                on: pagina.adaptador?.enabled ?? false
                conFlecha: true
                onAlternar: Radios.alternarBluetooth()
                onAbrir: Paneles.abrirPagina(pagina.pantalla, "bt", "derecha")
            }
            Tecla {
                width: teclas.ancho
                icono: Notificaciones.noMolestar ? "󰂛" : "󰂚"
                nombre: "No molestar"
                detalle: Notificaciones.noMolestar ? "Solo urgentes" : "Apagado"
                on: Notificaciones.noMolestar
                onAlternar: Notificaciones.noMolestar = !Notificaciones.noMolestar
            }
            // A mano: sin avisos y con el mando en la barra (ver comun/Juego.qml)
            Tecla {
                width: teclas.ancho
                icono: "󰊴"
                nombre: "Modo juego"
                detalle: Juego.activo ? "Sin avisos" : "Apagado"
                on: Juego.activo
                onAlternar: Juego.activo ? Juego.terminar() : Juego.empezar()
            }
            Tecla {
                width: teclas.ancho
                icono: "󰖔"
                nombre: "Luz nocturna"
                hay: LuzNocturna.instalada
                detalle: !LuzNocturna.instalada ? "Falta wlsunset"
                    : Ajustes.luzNocturna === "auto" ? "Al anochecer"
                    : Ajustes.luzNocturna === "siempre" ? "Siempre" : "Apagada"
                on: LuzNocturna.encendida
                property string ultimo: "auto"     // el modo al que vuelve al encenderla
                onAlternar: {
                    if (LuzNocturna.encendida) {
                        ultimo = Ajustes.luzNocturna;
                        Ajustes.luzNocturna = "apagada";
                    } else {
                        Ajustes.luzNocturna = ultimo;
                    }
                }
            }
            Tecla {
                width: teclas.ancho
                icono: "󰅶"
                nombre: "No suspender"
                detalle: Despierto.activo ? "Activado" : "Apagado"
                on: Despierto.activo
                onAlternar: Despierto.activo = !Despierto.activo
            }
        }

        // ------------------------------------ Volumen, micro y brillo
        Caja {
            width: parent.width
            height: barras.implicitHeight + 16
            Column {
                id: barras
                x: 12; y: 8
                width: parent.width - 24
                FilaBarra {
                    icono: (pagina.salida?.audio?.muted ?? true) ? "󰖁" : "󰕾"
                    valor: pagina.salida?.audio?.volume ?? 0
                    apagado: pagina.salida?.audio?.muted ?? true
                    conFlecha: true
                    onMovido: v => {
                        if (!pagina.salida?.audio)
                            return;
                        pagina.salida.audio.muted = false;
                        pagina.salida.audio.volume = v;
                    }
                    onIcono_: if (pagina.salida?.audio) pagina.salida.audio.muted = !pagina.salida.audio.muted
                    onAbrir: Paneles.abrirPagina(pagina.pantalla, "sonido", "derecha")
                }
                FilaBarra {
                    icono: (pagina.entrada?.audio?.muted ?? true) ? "󰍭" : "󰍬"
                    valor: pagina.entrada?.audio?.volume ?? 0
                    apagado: pagina.entrada?.audio?.muted ?? true
                    onMovido: v => {
                        if (!pagina.entrada?.audio)
                            return;
                        pagina.entrada.audio.muted = false;
                        pagina.entrada.audio.volume = v;
                    }
                    onIcono_: if (pagina.entrada?.audio) pagina.entrada.audio.muted = !pagina.entrada.audio.muted
                }
                Repeater {
                    model: Brillo.pantallas
                    FilaBarra {
                        required property var modelData
                        icono: modelData.valor < 0.35 ? "󰃞" : modelData.valor < 0.7 ? "󰃟" : "󰃠"
                        valor: modelData.valor
                        onMovido: v => Brillo.poner(modelData.id, v)
                    }
                }
            }
        }

        // ------------------------------------------- Perfil de energía
        Rectangle {
            id: perfiles
            visible: lista.length > 0
            width: parent.width
            height: 40
            radius: Tema.esquina(13)
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
                radius: Tema.esquina(10)
                color: pagina.tinte(0.2)
                border.width: 1.5
                border.color: pagina.acento
                Behavior on x { NumberAnimation { duration: Tema.ms(300); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
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
                            font.pixelSize: 14
                            color: perfil.on ? pagina.acento : Tema.gris
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

        // ------------------------------------------------------ Energía
        Titulo {
            text: pagina.armado >= 0 ? "¿SEGURO? PULSA OTRA VEZ" : "ENERGÍA"
            color: pagina.armado >= 0 ? Tema.rojo : Tema.gris
        }
        Row {
            id: energia
            width: parent.width
            spacing: 8
            Repeater {
                model: Sesion.opciones
                Column {
                    id: boton
                    required property var modelData
                    required property int index
                    readonly property bool armado: pagina.armado === index
                    readonly property bool ultimo: index === Sesion.opciones.length - 1
                    spacing: 6
                    Rectangle {
                        width: (energia.width - 4 * energia.spacing) / 5
                        height: 52
                        radius: Tema.esquina(17)
                        color: boton.armado ? Tema.conAlfa(Tema.rojo, 0.3)
                            : boton.ultimo ? Tema.conAlfa(Tema.rojo, botonRaton.containsMouse ? 0.22 : 0.12)
                            : botonRaton.containsMouse ? Tema.cajaHover : Tema.caja
                        border.width: 1
                        border.color: boton.armado ? Tema.rojo : botonRaton.containsMouse ? pagina.tinte(0.4) : Tema.claro(0.08)
                        scale: botonRaton.pressed ? 0.92 : botonRaton.containsMouse ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Texto {
                            anchors.centerIn: parent
                            text: boton.modelData.icono
                            font.pixelSize: 20
                            color: boton.armado || boton.ultimo ? Tema.rojo : Tema.texto
                        }
                        MouseArea {
                            id: botonRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pagina.sesion(boton.index)
                        }
                    }
                    Texto {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: boton.armado ? "¿Seguro?" : boton.modelData.titulo.replace("Cerrar sesión", "Salir")
                        font.bold: false
                        font.pixelSize: 10
                        color: boton.armado ? Tema.rojo : Tema.gris
                    }
                }
            }
        }

        // ----------------------------------------------- Notificaciones
        Item {
            width: parent.width
            height: 16
            Titulo { text: "NOTIFICACIONES" }
            Texto {
                visible: Notificaciones.cuantas > 0
                anchors.right: parent.right
                text: "Borrar"
                font.pixelSize: 11
                color: borrarRaton.containsMouse ? pagina.acento : Tema.gris
                MouseArea {
                    id: borrarRaton
                    anchors { fill: parent; margins: -4 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notificaciones.borrarTodas()
                }
            }
        }
        Caja {
            width: parent.width
            height: avisos.implicitHeight + 12
            Column {
                id: avisos
                x: 6; y: 6
                width: parent.width - 12
                spacing: 2
                Texto {
                    visible: Notificaciones.cuantas === 0
                    width: parent.width
                    height: 36
                    horizontalAlignment: Text.AlignHCenter
                    text: "󰄬  Todo al día"
                    font.bold: false
                    font.pixelSize: 12
                    color: Tema.gris
                }
                Repeater {
                    model: Notificaciones.lista.slice(0, 2)
                    Rectangle {
                        id: aviso
                        required property var modelData
                        width: avisos.width
                        height: 44
                        radius: Tema.esquina(12)
                        color: avisoRaton.containsMouse ? Tema.cajaHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        Rectangle {
                            id: letra
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                            width: 30; height: 30
                            radius: Tema.esquina(10)
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
                                textFormat: Text.PlainText
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
}
