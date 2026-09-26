// Volumen de un dispositivo de audio: [icono = silenciar] ━━━○── 45% [󰅀 elegir]
import QtQuick
import Quickshell.Services.Pipewire
import qs.comun

Item {
    id: fila

    property var nodo: null
    property string iconoOn: "󰕾"
    property string iconoOff: "󰖁"
    property bool elegida: false
    signal elegir()

    PwObjectTracker { objects: [fila.nodo] }
    readonly property real volumen: nodo?.audio?.volume ?? 0
    readonly property bool mudo: !nodo || (nodo.audio?.muted ?? true)

    implicitHeight: 40

    BotonIcono {
        id: silenciar
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 34; height: 34
        icono: fila.mudo ? fila.iconoOff : fila.iconoOn
        colorIcono: fila.mudo ? Tema.tenue : Tema.texto
        onClic: if (fila.nodo?.audio) fila.nodo.audio.muted = !fila.mudo
    }

    Deslizador {
        id: barra
        anchors {
            left: silenciar.right; leftMargin: 8
            right: porcentaje.left; rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        valor: fila.volumen
        apagado: fila.mudo
        onMovido: nuevo => {
            if (!fila.nodo?.audio)
                return;
            fila.nodo.audio.muted = false;
            fila.nodo.audio.volume = nuevo;
        }
    }

    Texto {
        id: porcentaje
        width: 40
        horizontalAlignment: Text.AlignRight
        text: Math.round(fila.volumen * 100) + "%"
        font.pixelSize: 12
        color: fila.mudo ? Tema.tenue : Tema.texto
        anchors { right: elegirBoton.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
    }

    BotonIcono {
        id: elegirBoton
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        icono: "󰅀"
        rotation: fila.elegida ? 180 : 0
        colorIcono: fila.elegida ? Tema.blanco : Tema.gris
        Behavior on rotation { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        onClic: fila.elegir()
    }
}
