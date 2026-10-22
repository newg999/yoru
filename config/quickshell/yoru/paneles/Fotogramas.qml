// ============================================================================
//  Fotogramas — contador de fps en la esquina, para ver si algo va a tirones
//  Mod+Alt+F lo enseña o lo quita (qs -c yoru ipc call fotogramas alternar)
//
//  Cada segundo: los fotogramas que ha dibujado Quickshell y el peor (en ms).
//  A 240 Hz cada uno tiene 4,2 ms; uno de 8 ms o más ya es un tirón visible.
//  Verde: a la tasa del monitor · amarillo: algo por debajo · rojo: tirones.
//  Mide lo que dibuja Quickshell (barra, paneles, fondos...) y, como Qt solo
//  dibuja cuando niri le da paso, también si niri se retrasa. No mide las
//  apps (Brave, juegos...), que van por su cuenta.
//  No coge clics: se puede dejar puesto mientras pruebas.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    property bool activo: false

    screen: modelData
    visible: activo
    color: "transparent"
    anchors { top: true; right: true }
    margins { top: Tema.hueco + 8; right: 16 }
    implicitWidth: caja.width
    implicitHeight: caja.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "yoru-fotogramas"
    WlrLayershell.layer: WlrLayer.Overlay
    // Que los clics pasen a lo de debajo
    mask: Region {}

    // La tasa de esta pantalla, de niri (en mHz)
    property real hz: 60
    Process {
        running: ventana.activo
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const salida = JSON.parse(text)[ventana.modelData.name];
                    const modo = salida.modes[salida.current_mode];
                    ventana.hz = modo.refresh_rate / 1000;
                } catch (e) {
                    console.warn("Fotogramas: no sé la tasa de la pantalla", e);
                }
            }
        }
    }

    property int cuenta: 0      // fotogramas en este segundo
    property real peorAhora: 0  // el más lento de este segundo (s)
    property int fps: 0
    property real peor: 0       // ms

    // Se ejecuta en cada fotograma que dibuja Qt (y le obliga a dibujar todos)
    FrameAnimation {
        running: ventana.activo
        onTriggered: {
            ventana.cuenta++;
            ventana.peorAhora = Math.max(ventana.peorAhora, frameTime);
        }
    }
    Timer {
        running: ventana.activo
        interval: 1000
        repeat: true
        onTriggered: {
            ventana.fps = ventana.cuenta;
            ventana.peor = ventana.peorAhora * 1000;
            ventana.cuenta = 0;
            ventana.peorAhora = 0;
        }
    }

    // Verde, amarillo o rojo según lo cerca que vaya de la tasa del monitor
    readonly property color estado: fps === 0 ? Tema.gris
        : peor > 2000 / hz || fps < hz * 0.85 ? Tema.rojo
        : fps < hz * 0.97 ? Tema.amarillo
        : "#a3be8c"

    Rectangle {
        id: caja
        width: fila.width + 24
        height: 34
        radius: 10
        color: Tema.sombra(0.85)
        border.width: 1
        border.color: Qt.alpha(ventana.estado, 0.6)

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: ventana.estado
            }
            Texto {
                text: `${ventana.fps} / ${Math.round(ventana.hz)} fps`
                font.pixelSize: 13
                color: Tema.blanco
            }
            Texto {
                text: `peor ${ventana.peor.toFixed(1).replace(".", ",")} ms`
                font.pixelSize: 12
                font.bold: false
                color: Tema.texto
            }
        }
    }
}
