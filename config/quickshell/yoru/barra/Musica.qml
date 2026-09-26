// ============================================================================
//  Música/vídeo que suena (Spotify, YouTube en Brave, mpv...)
//  Visualizador · canción · anterior · play/pausa · siguiente
//  Sin reproductor (o parado), la isla desaparece.
//  En la canción: clic = pestaña Multimedia · clic dcho = siguiente · clic central = pausa
// ============================================================================
import QtQuick
import qs.comun

Isla {
    id: isla
    required property var pantalla
    property int maximo: 300     // ancho máximo del título (la barra lo sube en monitores grandes)

    readonly property var reproductor: Reproductor.actual
    readonly property string cancion: {
        if (!reproductor)
            return "";
        const artista = reproductor.trackArtist ?? "";
        const titulo = reproductor.trackTitle ?? "";
        return artista && titulo ? `${titulo} · ${artista}` : (titulo || artista);
    }

    relleno: 7

    // Visualizador: barritas que bailan con el audio
    Item {
        visible: isla.reproductor !== null
        implicitWidth: barras.implicitWidth + 12
        implicitHeight: Tema.altoBarra

        Row {
            id: barras
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 2
            Repeater {
                model: Cava.niveles.length
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 3 + 13 * (Cava.niveles[index] ?? 0)
                    radius: 1.5
                    color: isla.reproductor?.isPlaying ? Tema.texto : Tema.tenue
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }

    Modulo {
        visible: isla.reproductor !== null && isla.cancion !== ""
        texto: isla.cancion
        anchoTexto: isla.maximo
        relleno: 5
        apagado: !isla.reproductor?.isPlaying
        onClic: boton => {
            if (boton === Qt.RightButton)
                isla.reproductor.next();
            else if (boton === Qt.MiddleButton)
                isla.reproductor.togglePlaying();
            else
                Paneles.alternar("centro", isla.pantalla, "multimedia");
        }
    }
    Modulo {
        visible: isla.reproductor !== null
        icono: "󰒮"
        tamIcono: 15
        relleno: 5
        onClic: isla.reproductor.previous()
    }
    // Play/pausa en un círculo blanco, como en DMS
    Item {
        visible: isla.reproductor !== null
        implicitWidth: 34
        implicitHeight: Tema.altoBarra

        Rectangle {
            anchors.centerIn: parent
            width: 24; height: 24; radius: 12
            color: playRaton.containsMouse ? Tema.blanco : Tema.texto
            scale: playRaton.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: Tema.rapida } }

            Texto {
                anchors.centerIn: parent
                text: isla.reproductor?.isPlaying ? "󰏤" : "󰐊"
                font.pixelSize: 14
                color: Tema.oscuro
            }
        }
        MouseArea {
            id: playRaton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: isla.reproductor.togglePlaying()
        }
    }
    Modulo {
        visible: isla.reproductor !== null
        icono: "󰒭"
        tamIcono: 15
        relleno: 5
        onClic: isla.reproductor.next()
    }
}
