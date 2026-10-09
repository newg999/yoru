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
    property int maximo: 160     // ancho máximo del título (la barra lo sube en monitores grandes)

    readonly property var reproductor: Reproductor.actual
    readonly property string cancion: {
        if (!reproductor)
            return "";
        const artista = reproductor.trackArtist ?? "";
        const titulo = reproductor.trackTitle ?? "";
        return artista && titulo ? `${titulo} · ${artista}` : (titulo || artista);
    }

    relleno: 7

    ayuda: {
        const r = reproductor;
        if (!r)
            return "";
        const lineas = [`<b>${Tema.html(r.trackTitle || "Sin título")}</b>`];
        if (r.trackArtist)
            lineas.push(Tema.html(r.trackArtist));
        if (r.trackAlbum)
            lineas.push(Tema.suave(Tema.html(r.trackAlbum)));
        lineas.push(Tema.suave((r.isPlaying ? "󰐊 " : "󰏤 ") + Tema.html(r.identity)
            + "  ·  clic: multimedia · clic central: pausa"));
        return lineas.join("<br>");
    }

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
                }
            }
        }
    }

    // Canción: letra pequeña y, si no cabe, se desplaza una vez al cambiar
    // de canción y mientras tienes el ratón encima. (Antes se desplazaba sin
    // parar: la barra se redibujaba a 120 fps y la gráfica no descansaba)
    Item {
        id: titulo
        visible: isla.reproductor !== null && isla.cancion !== ""
        readonly property bool cabe: texto.implicitWidth <= isla.maximo
        implicitWidth: Math.min(texto.implicitWidth, isla.maximo) + 16
        implicitHeight: Tema.altoBarra
        clip: true

        Texto {
            id: texto
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            text: isla.cancion
            font.pixelSize: 12
            font.bold: false
            color: tituloRaton.containsMouse ? Tema.blanco
                : isla.reproductor?.isPlaying ? Tema.texto : Tema.tenue

            // Va y vuelve despacio, con una pausa en cada extremo
            SequentialAnimation on x {
                id: desplazar
                running: false
                loops: tituloRaton.containsMouse ? Animation.Infinite : 1
                onRunningChanged: if (!running) texto.x = 5
                PauseAnimation { duration: 1500 }
                NumberAnimation {
                    from: 5; to: isla.maximo - texto.implicitWidth + 5
                    duration: Math.max(1, texto.implicitWidth - isla.maximo) * 25
                }
                PauseAnimation { duration: 2000 }
                NumberAnimation {
                    from: isla.maximo - texto.implicitWidth + 5; to: 5
                    duration: Math.max(1, texto.implicitWidth - isla.maximo) * 25
                }
            }
        }

        // Una pasada al cambiar de canción; con el ratón encima, sin parar
        Connections {
            target: isla
            function onCancionChanged() {
                if (!titulo.cabe)
                    desplazar.restart();
            }
        }

        MouseArea {
            id: tituloRaton
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                if (containsMouse && !titulo.cabe)
                    desplazar.restart();
                else if (!containsMouse)
                    desplazar.stop();
            }
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (e.button === Qt.RightButton)
                    isla.reproductor.next();
                else if (e.button === Qt.MiddleButton)
                    isla.reproductor.togglePlaying();
                else
                    Paneles.alternar("centro", isla.pantalla, "multimedia");
            }
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
