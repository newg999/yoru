// ============================================================================
//  Fondo — el fondo de pantalla, con transición al cambiarlo
//
//  Lo elige niri/scripts/wallpaper.sh (que apunta cuál es en
//  ~/.cache/wallpaper-actual): aquí se ve ese archivo y, al cambiar, el
//  nuevo se descubre con un círculo que crece desde el centro, con el borde
//  suave y un poco de zoom.
//
//  Va en la capa del fondo con el nombre «wallpaper», como swaybg: niri lo
//  pone en el backdrop y se ve también en el overview (niri/rules.kdl).
//  swaybg queda de reserva: wallpaper.sh lo usa si la barra no responde, y
//  aquí se cierra en cuanto se ve el fondo.
// ============================================================================
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: fondo

    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: Tema.oscuro
    mask: Region {}

    // Lo que se ve ahora y lo que entra
    property string actual: ""
    property string entrante: ""

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wallpaper-actual"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: fondo.cambiar(text().trim())
    }

    function cambiar(ruta) {
        if (ruta === "" || ruta === actual || ruta === entrante)
            return;
        // El primero (al arrancar), sin transición
        if (actual === "") {
            actual = ruta;
            return;
        }
        circulo.stop();
        // Si llega otro a media transición, el que entraba ya se queda
        if (entrante !== "")
            actual = entrante;
        entrante = ruta;
        progreso = 0;
    }

    // 0 → 1: el círculo del nuevo, de nada a cubrir toda la pantalla
    property real progreso: 0
    NumberAnimation {
        id: circulo
        target: fondo
        property: "progreso"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.InOutCubic
        // El de abajo pasa a ser el nuevo; el de encima sigue tapando hasta
        // que el de abajo lo tiene cargado (si no, parpadeaba al acabar)
        onFinished: fondo.actual = fondo.entrante
    }

    component Imagen: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(fondo.width * (fondo.screen?.devicePixelRatio ?? 1), fondo.height * (fondo.screen?.devicePixelRatio ?? 1))
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
    }

    Imagen {
        id: debajo
        source: fondo.actual ? "file://" + fondo.actual : ""
        // swaybg (el de reserva) sobra en cuanto esto se ve
        onStatusChanged: {
            if (status !== Image.Ready)
                return;
            if (fondo.entrante !== "" && fondo.entrante === fondo.actual && !circulo.running)
                fondo.entrante = "";
            Quickshell.execDetached(["pkill", "-x", "swaybg"]);
        }
    }

    Imagen {
        id: encima
        source: fondo.entrante ? "file://" + fondo.entrante : ""
        visible: false
        // Cargado: empieza la transición
        onStatusChanged: if (status === Image.Ready && fondo.entrante !== "")
            circulo.restart()
    }

    // La máscara: un círculo en el centro que crece hasta la esquina, con
    // el borde en degradado (blanco dentro, transparente fuera)
    Shape {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        preferredRendererType: Shape.CurveRenderer
        readonly property real diagonal: Math.sqrt(width * width + height * height)
        readonly property real radio: (diagonal / 2 + 160) * fondo.progreso
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: mascara.width / 2
                centerY: mascara.height / 2
                focalX: centerX
                focalY: centerY
                centerRadius: Math.max(1, mascara.radio)
                GradientStop { position: 0; color: "white" }
                GradientStop { position: Math.max(0, 1 - 160 / Math.max(160, mascara.radio)); color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: mascara.width; y: 0 }
            PathLine { x: mascara.width; y: mascara.height }
            PathLine { x: 0; y: mascara.height }
            PathLine { x: 0; y: 0 }
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: fondo.entrante !== "" && encima.status === Image.Ready
        source: encima
        maskEnabled: true
        maskSource: mascara
        // Borde suave
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        // Un poco de zoom: entra de 1.06 a 1
        scale: 1.06 - 0.06 * fondo.progreso
    }
}
