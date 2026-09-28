// ============================================================================
//  OSD — aviso abajo en el centro al cambiar el volumen, el micrófono o el
//  brillo (teclas, rueda sobre la barra, otra app...). Se va solo.
//
//    ┌──────────────────────────────┐
//    │ 󰕾  ━━━━━━━━━━━○──────  45%  │
//    └──────────────────────────────┘
//
//  Sale en la pantalla que tiene el foco. Con el centro de control abierto
//  no sale: ahí ya se ven las barras.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.comun

PanelWindow {
    id: osd

    required property ShellScreen modelData
    screen: modelData

    readonly property bool enfocada: (Niri.escritorios.find(e => e.is_focused)?.output ?? modelData.name) === modelData.name

    // Qué se enseña: "volumen", "micro" o "brillo"
    property string tipo: "volumen"
    property bool mostrar: false

    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.salida, osd.entrada] }

    readonly property var nodo: tipo === "micro" ? entrada : salida
    readonly property bool mudo: tipo !== "brillo" && (nodo?.audio?.muted ?? true)
    readonly property real valor: tipo === "brillo" ? (Brillo.pantallas[0]?.valor ?? 0) : (nodo?.audio?.volume ?? 0)
    readonly property string icono: tipo === "brillo" ? (valor < 0.35 ? "󰃞" : valor < 0.7 ? "󰃟" : "󰃠")
        : tipo === "micro" ? (mudo ? "󰍭" : "󰍬")
        : mudo ? "󰖁" : valor < 0.34 ? "󰕿" : valor < 0.67 ? "󰖀" : "󰕾"

    function avisar(que) {
        // Al arrancar, Pipewire «cambia» todo de golpe: eso no cuenta
        if (!listo || !enfocada || Paneles.abierto === "conexion")
            return;
        tipo = que;
        mostrar = true;
        adios.restart();
    }

    property bool listo: false
    Timer {
        interval: 2000
        running: true
        onTriggered: osd.listo = true
    }
    Timer {
        id: adios
        interval: 1500
        onTriggered: osd.mostrar = false
    }

    Connections {
        target: osd.salida?.audio ?? null
        function onVolumeChanged() { osd.avisar("volumen"); }
        function onMutedChanged() { osd.avisar("volumen"); }
    }
    Connections {
        target: osd.entrada?.audio ?? null
        function onVolumeChanged() { osd.avisar("micro"); }
        function onMutedChanged() { osd.avisar("micro"); }
    }
    Connections {
        target: Brillo
        function onCambiadoConTecla() { osd.avisar("brillo"); }
    }

    // 0 = escondido · 1 = a la vista
    property real progreso: mostrar ? 1 : 0
    Behavior on progreso { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

    visible: progreso > 0
    anchors.bottom: true
    margins.bottom: 60
    implicitWidth: 320
    implicitHeight: 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // No se puede pulsar: los clics pasan a lo que haya debajo
    mask: Region {}

    BackgroundEffect.blurRegion: Region {
        item: osd.progreso > 0.97 ? caja : null
        radius: Tema.radioPanel
    }

    Rectangle {
        id: caja
        anchors.fill: parent
        radius: Tema.radioPanel
        color: Tema.panel
        border.width: 2
        border.color: Tema.panelBorde
        opacity: osd.progreso
        scale: 0.94 + 0.06 * osd.progreso
        transform: Translate { y: (1 - osd.progreso) * 12 }

        Texto {
            id: icono
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            width: 24
            horizontalAlignment: Text.AlignHCenter
            text: osd.icono
            font.pixelSize: 20
            color: osd.mudo ? Tema.tenue : Tema.blanco
        }

        // Barra (solo para ver, no se arrastra)
        Rectangle {
            id: carril
            anchors {
                left: icono.right; leftMargin: 14
                right: porcentaje.left; rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            height: 6
            radius: 3
            color: Tema.claro(0.18)

            Rectangle {
                width: Math.max(carril.height, Math.min(1, osd.valor) * carril.width)
                height: parent.height
                radius: parent.radius
                color: osd.mudo ? Tema.tenue : Tema.blanco
                Behavior on width { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
            }
        }

        Texto {
            id: porcentaje
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            width: 44
            horizontalAlignment: Text.AlignRight
            text: osd.mudo ? "mudo" : Math.round(osd.valor * 100) + "%"
            font.pixelSize: 13
            color: osd.mudo ? Tema.tenue : Tema.texto
        }
    }
}
