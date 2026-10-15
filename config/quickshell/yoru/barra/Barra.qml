// ============================================================================
//  Barra — una por pantalla. La barra en sí es invisible: solo se ven las islas.
//
//  Arriba (lo normal):
//    [escritorios] [título o apps abiertas]    [música] [reloj] [clima]    [bandeja] [recursos] [conexión] [campana]
//
//  A la izquierda (Ajustes → Barra y dock), lo mismo en columna:
//    arriba escritorios y ventana · en medio música, reloj y clima ·
//    abajo bandeja, recursos, conexión y campana
//
//  El reloj va siempre en el centro exacto; la música y el clima, a sus lados.
//  Con el overview abierto (Mod+Tab) la barra se aparta y desaparece, como en DMS.
//  Detrás de cada isla, el fondo se ve desenfocado (como en los paneles).
//  Qué islas se ven, el desenfoque y la posición se eligen en Ajustes.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.comun

PanelWindow {
    id: barra
    required property ShellScreen modelData
    screen: modelData

    readonly property bool vertical: Ajustes.vertical
    // Monitor pequeño (portátil) → títulos más cortos
    readonly property bool pequena: modelData.width < 1800

    anchors {
        top: true
        left: true
        right: !barra.vertical
        bottom: barra.vertical
    }
    implicitHeight: Tema.margenBarra + Tema.altoBarra
    implicitWidth: Tema.margenBarra + Tema.anchoBarra
    exclusiveZone: Tema.margenBarra + Tema.grosor
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    // Escondida: sin zona de clic, para que los clics lleguen al overview
    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    // Desenfoque detrás de cada isla (la barra en sí es transparente: si se
    // desenfocara entera, se vería una franja borrosa de lado a lado).
    // Fuera durante el overview, que es cuando la barra se esconde.
    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : islas
    Region {
        id: islas
        Region { item: escritorios; radius: Tema.radio }
        Region { item: titulo; radius: Tema.radio }
        Region { item: ventanas; radius: Tema.radio }
        Region { item: musica; radius: Tema.radio }
        Region { item: reloj; radius: Tema.radio }
        Region { item: clima; radius: Tema.radio }
        Region { item: bandeja; radius: Tema.radio }
        Region { item: recursos; radius: Tema.radio }
        Region { item: conexion; radius: Tema.radio }
        Region { item: campana; radius: Tema.radio }
    }

    // Un grupo de islas: en fila arriba, en columna a la izquierda
    component Grupo: Grid {
        // Solo cambian las columnas: una (en columna) o de sobra (en fila).
        // Cambiar filas y columnas a la vez pasa un momento por 1×1 y Qt avisa
        columns: barra.vertical ? 1 : 99
        spacing: Tema.separacion
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }

    // ------------------------------------------------- Tapa (a la izquierda)
    // niri deja asomar la columna de la izquierda por la zona que reserva la
    // barra (no por la separación de 12 px, que se deja ver). Se tapa con el propio fondo de pantalla, recortado en
    // su sitio (swaybg -m fill = PreserveAspectCrop centrado): parece que ahí
    // no hay nada. Arriba no hace falta: encima no hay ventanas.
    property string fondo: ""
    FileView {
        path: Quickshell.env("HOME") + "/.cache/wallpaper-actual"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: barra.fondo = text().trim()
    }

    Item {
        anchors.fill: parent
        visible: barra.vertical
        clip: true
        opacity: Niri.overview ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }

        // Sin fondo (o mientras carga), el color de fondo del tema
        Rectangle {
            anchors.fill: parent
            color: Tema.oscuro
        }
        Image {
            width: barra.modelData.width
            height: barra.modelData.height
            source: barra.fondo !== "" && barra.vertical ? "file://" + barra.fondo : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width, height)
            asynchronous: true
        }

        // La sombra de las ventanas de niri llega hasta aquí: en el borde
        // oscurece el fondo un 41 % (medido). Se sigue en la tapa, cada vez
        // más suave hacia la izquierda, para que no se vea un corte. A lo alto
        // también cambia (medido): arriba empieza floja, porque niri la baja
        // 6 px (offset y=6), y abajo se apaga antes del borde.
        // Sin ventanas en el escritorio, niri no dibuja sombra: aquí tampoco.
        Canvas {
            id: sombra
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 30
            visible: barra.vertical && Niri.ventanaEn(barra.modelData.name) !== null
            onHeightChanged: requestPaint()

            // [y, intensidad de 0 a 1] arriba y [distancia al borde de abajo, intensidad]
            readonly property var arriba: [[0, 0.17], [6, 0.29], [12, 0.44], [18, 0.6], [24, 0.76], [30, 0.85], [36, 0.93], [45, 0.98], [54, 1]]
            readonly property var abajo: [[0, 0.45], [6, 0.5], [12, 0.59], [18, 0.73], [24, 0.88], [33, 1]]

            function interpolar(puntos, d) {
                for (let i = 1; i < puntos.length; i++) {
                    const [d0, v0] = puntos[i - 1], [d1, v1] = puntos[i];
                    if (d <= d1)
                        return v0 + (v1 - v0) * (d - d0) / (d1 - d0);
                }
                return 1;
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                // Una franja de 2 px cada vez con su intensidad (en medio, toda igual)
                for (let y = 0; y < height; y += 2) {
                    const f = Math.min(interpolar(arriba, y), interpolar(abajo, height - y - 2));
                    const g = ctx.createLinearGradient(0, 0, width, 0);
                    g.addColorStop(0.0, "rgba(0,0,0,0)");
                    g.addColorStop(0.5, `rgba(0,0,0,${0.12 * f})`);
                    g.addColorStop(0.8, `rgba(0,0,0,${0.28 * f})`);
                    g.addColorStop(1.0, `rgba(0,0,0,${0.41 * f})`);
                    ctx.fillStyle = g;
                    ctx.fillRect(0, y, width, 2);
                }
            }
        }
    }

    Item {
        id: contenido
        opacity: Niri.overview ? 0 : 1
        // Con el overview se aparta hacia su borde (arriba o a la izquierda)
        transform: Translate {
            x: Niri.overview && barra.vertical ? -(Tema.anchoBarra + Tema.margenBarra) : 0
            y: Niri.overview && !barra.vertical ? -(Tema.altoBarra + Tema.margenBarra) : 0
            Behavior on x { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tema.normal } }

        anchors {
            fill: parent
            topMargin: barra.vertical ? Tema.margenLados : Tema.margenBarra
            leftMargin: barra.vertical ? Tema.margenBarra : Tema.margenLados
            rightMargin: barra.vertical ? 0 : Tema.margenLados
            bottomMargin: barra.vertical ? Tema.margenLados : 0
        }

        // Colocadas con x/y y no con anclajes: quitar un anclaje al cambiar
        // de posición (anchors.x: undefined) no siempre lo suelta y las islas
        // acababan con alto negativo o encima de otras.
        readonly property int sep: Tema.separacion
        function centrado(alto) { return Math.round((height - alto) / 2); }

        // ---------------------------------------------- Izquierda (o arriba)
        Grupo {
            x: 0
            y: barra.vertical ? 0 : contenido.centrado(height)

            Escritorios { id: escritorios; salida: barra.modelData.name }
            // La ventana activa o todas las abiertas (Ajustes → Barra y dock)
            Titulo {
                id: titulo
                oculta: !Ajustes.islaTitulo || Ajustes.ventanas !== "activa"
                salida: barra.modelData.name
                maximo: barra.pequena ? 300 : 420
            }
            Ventanas {
                id: ventanas
                oculta: !Ajustes.islaTitulo || Ajustes.ventanas !== "abiertas"
                salida: barra.modelData.name
            }
        }

        // ------------------------------------------------------------- Centro
        // El reloj en el centro exacto; la música antes y el clima después
        Musica {
            id: musica
            oculta: !Ajustes.islaMusica
            x: barra.vertical ? 0 : reloj.x - width - contenido.sep
            y: barra.vertical ? reloj.y - height - contenido.sep : contenido.centrado(height)
            pantalla: barra.modelData
            maximo: barra.pequena ? 140 : 200
        }
        Reloj {
            id: reloj
            x: barra.vertical ? 0 : Math.round((contenido.width - width) / 2)
            y: contenido.centrado(height)
            pantalla: barra.modelData
        }
        Clima {
            id: clima
            oculta: !Ajustes.islaClima
            x: barra.vertical ? 0 : reloj.x + reloj.width + contenido.sep
            y: barra.vertical ? reloj.y + reloj.height + contenido.sep : contenido.centrado(height)
            pantalla: barra.modelData
        }

        // ------------------------------------------------ Derecha (o abajo)
        Grupo {
            x: barra.vertical ? 0 : contenido.width - width
            y: barra.vertical ? contenido.height - height : contenido.centrado(height)

            Bandeja { id: bandeja; ventana: barra; oculta: !Ajustes.islaBandeja }
            Recursos { id: recursos; pantalla: barra.modelData; oculta: !Ajustes.islaRecursos }
            Conexion { id: conexion; pantalla: barra.modelData }
            Campana { id: campana; pantalla: barra.modelData }
        }
    }
}
