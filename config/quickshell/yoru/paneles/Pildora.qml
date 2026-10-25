// ============================================================================
//  Píldora — la barra en una sola píldora arriba en el centro (Ajustes ›
//  Barra y dock › Píldora). Al pulsarla, la propia píldora crece hasta ser
//  el panel y su fila pasa a ser la cabecera:
//
//      cerrada:    ( ━ • •  14:02 )                         sin nada más
//                  ( ━ • • ▌▍▌ Canción ⏯ 14:02  󰓓 󰑋 󰂚 )   con música (clic =
//                                                          Multimedia), bandeja
//                                                          y avisos
//      abierta:    ( ━ • •        14:02        󰃭 󰖐 󰍛 󰏘 󰸉 )   (sin los avisos)
//                  │ página: control · temas · fondos │
//                  ╰──────────────────────────────────╯
//
//    calendario (PaginaCalendario.qml) el mes (su icono, 󰃭)
//    multimedia (PestanaMultimedia.qml) lo que suena, en grande (clic en la
//             canción; sin icono arriba: con música, la canción está a mano)
//    clima    (PestanaClima.qml)  ahora, próximas horas, 7 días y el lugar
//    control  (PaginaControl.qml) wifi, bluetooth, no molestar, modo juego,
//             volumen, accesos rápidos, lo que suena y las notificaciones
//    sistema  (PaginaSistema.qml) cpu, ram, temperatura, clima, memorias USB
//             y actualizaciones
//    temas    (PaginaTemas.qml)   las paletas de «yoru tema»
//    fondos   (PaginaFondos.qml)  los fondos en fila
//
//  Clic en un punto = ese escritorio · en el resto (también la hora) = abrir
//  o cerrar · 󰃭 󰖐 󰍛 󰏘 󰸉 = esa página (otra vez: volver a control) · Esc o
//  clic fuera = cerrar
//  Desde fuera:  qs -c yoru ipc call panel alternar pildora control  (o calendario, multimedia, clima…)
//
//  Cerrada, además, reacciona a lo que pasa («actividades»): crece un
//  momento para enseñarlo y vuelve a su tamaño
//      volumen / brillo / micro   ( 󰕾 ━━━━━━━━━━○────  45% )
//      captura (Imprimir)         la miniatura (clic = verla)
//  Con la píldora no sale el aviso de volumen (Osd.qml): sale aquí. Las
//  notificaciones, no: van sueltas, arriba a la derecha (Avisos.qml).
//  Gestos: rueda = volumen (también sobre la música) · clic central = pausa
//
//  Con la píldora, la barra de islas (barra/Barra.qml) no se ve: lo que
//  mostraba está en las páginas, y sus avisos (grabando, modo juego, no
//  suspender, actualizaciones, USB, notificaciones nuevas, batería) salen en
//  la propia píldora mientras duran.
// ============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.comun
import qs.barra

PanelWindow {
    id: ventana

    required property ShellScreen modelData
    screen: modelData

    readonly property bool abierta: Paneles.abierto === "pildora" && Paneles.pantalla === modelData
    readonly property string pagina: paginas.pagina
    function ir(p) { paginas.ir(p); }
    function subirVolumen(d) {
        const a = salida?.audio;
        if (!a)
            return;
        a.muted = false;
        a.volume = Math.max(0, Math.min(1, a.volume + d));
    }

    // 0 = píldora · 1 = panel. Mientras se cierra, la ventana sigue a
    // pantalla completa (para que la animación quepa)
    property real progreso: abierta ? 1 : 0
    Behavior on progreso {
        NumberAnimation { duration: Ajustes.animaciones ? 420 : 0; easing.type: Easing.OutExpo }
    }
    readonly property bool desplegada: abierta || progreso > 0
    // El contenido entra en la segunda mitad (si no, se ve aplastado)
    readonly property real dentro: Math.max(0, progreso * 2 - 1)

    visible: Ajustes.pildora
    anchors { top: true; left: true; right: true }
    implicitHeight: desplegada ? modelData.height : Tema.margenBarra + Math.max(Tema.altoBarra, Math.ceil(caja.height)) + 2
    exclusiveZone: Tema.zonaBarra
    color: "transparent"
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: abierta ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Cerrada, solo la píldora coge clics (el resto de la franja, a las
    // ventanas); con el overview, nada
    mask: Niri.overview ? vacia : desplegada ? null : soloPildora
    Region { id: vacia }
    Region { id: soloPildora; item: caja }

    BackgroundEffect.blurRegion: Niri.overview || !Ajustes.desenfoque ? null : desenfoque
    Region { id: desenfoque; item: caja; radius: caja.radius }

    // «No suspender» (lo hace la barra de islas, que aquí no se ve)
    IdleInhibitor {
        window: ventana
        enabled: Despierto.activo
    }

    // Clic fuera = cerrar
    MouseArea {
        anchors.fill: parent
        enabled: ventana.abierta
        onClicked: Paneles.cerrar()
    }

    // ================================================== Actividades
    // Solo en la pantalla con el foco, cerrada y sin el overview
    readonly property bool enfocada: (Niri.escritorios.find(e => e.is_focused)?.output ?? modelData.name) === modelData.name
    readonly property bool puedeVivir: Ajustes.pildora && enfocada && !abierta && !Niri.overview

    // Las notificaciones no salen aquí, sino sueltas arriba a la derecha
    // (Avisos.qml). La que manda niri al hacer una captura («Screenshot
    // captured», en inglés y sin abrirse), ni eso: en su lugar, la
    // actividad «captura»
    function esCapturaNiri(e) {
        return e?.n && Notificaciones.app(e.n) === "niri" && /screenshot/i.test(e.n.summary ?? "");
    }
    Connections {
        target: Notificaciones
        enabled: Ajustes.pildora
        function onEmergentesChanged() {
            for (const e of Notificaciones.emergentes.filter(ventana.esCapturaNiri))
                Notificaciones.ocultar(e);
        }
    }
    // "volumen" · "brillo" · "micro" · "captura" (la canción nueva no: con
    // música solo se ven las ondas, y la canción con el ratón encima)
    property string actividad: ""
    readonly property string viva: puedeVivir ? ventana.actividad : ""
    // Lo último que se vio: mientras se encoge, se sigue dibujando eso
    property string ultima: ""
    onVivaChanged: if (viva !== "") ultima = viva
    property real vivo: viva !== "" ? 1 : 0
    Behavior on vivo {
        NumberAnimation {
            duration: Ajustes.animaciones ? (ventana.viva !== "" ? 480 : 360) : 0
            easing.type: Easing.OutExpo
        }
    }

    function avisar(que, ms) {
        if (!listo || !puedeVivir)
            return;
        ventana.actividad = que;
        finActividad.interval = ms;
        finActividad.restart();
    }
    Timer {
        id: finActividad
        // Con el ratón encima no se va
        onTriggered: caja.encima ? restart() : ventana.actividad = ""
    }
    // Al abrir el panel, fuera
    onAbiertaChanged: if (abierta) ventana.actividad = ""

    // Al arrancar, Pipewire y el reproductor «cambian» todo de golpe: no cuenta
    property bool listo: false
    Timer {
        interval: 2500
        running: true
        onTriggered: ventana.listo = true
    }

    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [ventana.salida, ventana.entrada] }
    Connections {
        target: ventana.salida?.audio ?? null
        function onVolumeChanged() { ventana.avisar("volumen", 1500); }
        function onMutedChanged() { ventana.avisar("volumen", 1500); }
    }
    Connections {
        target: ventana.entrada?.audio ?? null
        function onVolumeChanged() { ventana.avisar("micro", 1500); }
        function onMutedChanged() { ventana.avisar("micro", 1500); }
    }
    Connections {
        target: Brillo
        function onCambiadoConTecla() { ventana.avisar("brillo", 1500); }
    }
    // Captura (Imprimir): niri avisa con la ruta
    property string captura: ""
    Connections {
        target: Niri
        function onCaptura(ruta) {
            if (ruta === "")
                return;
            ventana.captura = ruta;
            ventana.avisar("captura", 5000);
        }
    }

    SystemClock {
        id: reloj
        precision: Ajustes.relojSegundos ? SystemClock.Seconds : SystemClock.Minutes
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Paneles.cerrar()

        Rectangle {
            id: caja

            // Medidas: cerrada, cada cosa a continuación de la anterior
            // (sin huecos); abierta, escritorios a la izquierda, hora en el
            // centro y páginas y avisos a la derecha. Al abrirse, cada cosa
            // se desliza de un sitio al otro (x = mezcla de los dos)
            // Con el ratón encima (cerrada y sin actividad) se ensancha un poco
            property real crece: encima && !ventana.abierta && ventana.vivo === 0 ? 8 : 0
            Behavior on crece { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
            readonly property real margen: 14 + crece
            readonly property int hueco: 12
            // La música se va 1,5 s después de cerrar el reproductor (al
            // cambiar de canción a veces desaparece un momento y daba
            // saltos), y mientras se va guarda el último título
            // También en pausa (para poder seguir con ⏯); se va al cerrar el reproductor
            readonly property bool suena: Reproductor.actual !== null
            property bool conMusica: suena
            property string tituloMusica: ""
            onSuenaChanged: {
                if (suena) {
                    quitarMusica.stop();
                    conMusica = true;
                } else {
                    quitarMusica.restart();
                }
            }
            Timer {
                id: quitarMusica
                interval: 1500
                onTriggered: caja.conMusica = false
            }
            Binding {
                target: caja
                property: "tituloMusica"
                value: Reproductor.titulo(Reproductor.actual) || Reproductor.nombre(Reproductor.actual)
                when: caja.suena
                restoreMode: Binding.RestoreNone
            }
            // Lo que ocupan la música y los avisos (con su hueco), suave al
            // aparecer o irse
            property real anchoMusica: conMusica ? musicaFila.implicitWidth + hueco : 0
            Behavior on anchoMusica { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
            property real anchoAvisos: avisos.implicitWidth > 0 ? avisos.implicitWidth + hueco : 0
            Behavior on anchoAvisos { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }

            readonly property real xMusica: margen + puntos.width + hueco
            readonly property real xReloj: xMusica + anchoMusica
            readonly property real anchoCerradaSuave: xReloj + reloj_.implicitWidth + anchoAvisos + margen
            // Multimedia y Clima, más anchas (son las pestañas del panel
            // central, hechas para más sitio); al cambiar de página, suave
            property real anchoAbierta: paginas.anchoPedido
            Behavior on anchoAbierta {
                enabled: ventana.abierta
                NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic }
            }
            readonly property real altoAbierta: Tema.altoBarra + 8 + paginas.height + 14
            function mezcla(cerrada, abierta) { return Math.round(cerrada + (abierta - cerrada) * ventana.progreso); }

            // Con una actividad, cerrada mide lo que pida esa actividad
            readonly property var medidaViva: ({
                volumen: [340, Tema.altoBarra], brillo: [340, Tema.altoBarra], micro: [340, Tema.altoBarra],
                captura: [380, 86]
            })[ventana.ultima] ?? [anchoCerradaSuave, Tema.altoBarra]
            readonly property real anchoCerrada: anchoCerradaSuave + (medidaViva[0] - anchoCerradaSuave) * ventana.vivo
            readonly property real altoCerrada: Tema.altoBarra + (medidaViva[1] - Tema.altoBarra) * ventana.vivo
            readonly property real radioCerrada: Tema.altoBarra / 2 + (Math.min(medidaViva[1] / 2, 26) - Tema.altoBarra / 2) * ventana.vivo
            readonly property bool encima: cajaEncima.hovered

            HoverHandler { id: cajaEncima }

            width: mezcla(anchoCerrada, anchoAbierta)
            height: Math.round(altoCerrada + (altoAbierta - altoCerrada) * ventana.progreso)
            x: Math.round((ventana.width - width) / 2)
            // Recta (Ajustes › Barra y dock): pegada al borde de arriba, como
            // una pestaña, y sin esquinas redondas, como la minimalista
            y: Ajustes.recto ? 0 : Tema.margenBarra
            radius: Ajustes.recto ? 0 : radioCerrada + (Tema.radioPanel - radioCerrada) * ventana.progreso

            // La «isla negra»: negro puro, sin borde (como la Dynamic Island);
            // el color solo sale del acento y de las carátulas
            // (como ChillPill: gris casi negro, no negro puro)
            color: cabeceraRaton.containsMouse && !ventana.abierta && ventana.vivo === 0 ? "#181818" : "#111111"
            Behavior on color { ColorAnimation { duration: Tema.rapida } }
            border.width: 0
            clip: true

            // Con el overview se va hacia arriba, como la barra
            opacity: Niri.overview ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
            transform: Translate {
                y: Niri.overview ? -(Tema.altoBarra + Tema.margenBarra) : 0
                Behavior on y { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
            }

            // Los clics dentro no cierran
            MouseArea {
                anchors.fill: parent
            }

            // ------------------------------------------------------ Cabecera
            Item {
                id: cabecera
                width: parent.width
                height: Tema.altoBarra
                opacity: Math.max(0, 1 - ventana.vivo * 2)
                visible: opacity > 0

                // Clic en la cabecera = abrir o cerrar · clic central = pausa
                // · rueda = volumen
                MouseArea {
                    id: cabeceraRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: e => {
                        if (e.button === Qt.MiddleButton)
                            Reproductor.actual?.togglePlaying();
                        else
                            ventana.abierta ? Paneles.cerrar() : Paneles.alternar("pildora", ventana.modelData, "control");
                    }
                    onWheel: e => ventana.subirVolumen(e.angleDelta.y > 0 ? 0.05 : -0.05)
                }

                // Escritorios: el activo, alargado
                Row {
                    id: puntos
                    x: caja.margen
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Repeater {
                        model: Niri.escritoriosDe(ventana.modelData.name)
                        Rectangle {
                            id: punto
                            required property var modelData
                            readonly property bool activo: modelData.is_active
                            width: activo ? 20 : 8
                            height: 8
                            radius: 4
                            color: modelData.is_urgent ? Tema.rojo
                                : activo || puntoRaton.containsMouse ? Tema.blanco
                                : modelData.active_window_id !== null ? Tema.claro(0.5) : Tema.claro(0.25)
                            Behavior on width { NumberAnimation { duration: Tema.normal; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            MouseArea {
                                id: puntoRaton
                                anchors { fill: parent; margins: -4 }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Niri.irA(punto.modelData)
                                onWheel: e => Niri.accion(e.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
                            }
                        }
                    }
                }

                // Lo que suena, en medio: unas ondas (cava) y la canción.
                // Clic = Multimedia · clic central = pausa. Abierta no hace
                // falta (está en la página control)
                Item {
                    id: musica
                    x: caja.xMusica
                    width: Math.max(0, caja.anchoMusica - caja.hueco)
                    height: parent.height
                    clip: true
                    visible: width > 0 && ventana.progreso < 1
                    opacity: 1 - ventana.progreso * 2

                    // Unas ondas que bailan con el sonido y el nombre entero de
                    // la canción (sin disco, y sin abrirse al pasar el ratón)
                    Row {
                        id: musicaFila
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            // En pausa, quietas y apagadas
                            opacity: Reproductor.actual?.isPlaying ? 1 : 0.4
                            Behavior on opacity { NumberAnimation { duration: Tema.normal } }
                            Repeater {
                                model: 5
                                Rectangle {
                                    required property int index
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 4 + 12 * (Reproductor.actual?.isPlaying ? (Cava.niveles[index] ?? 0) : 0)
                                    radius: 1.5
                                    color: Tema.blanco
                                    Behavior on height { NumberAnimation { duration: 80 } }
                                }
                            }
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            // Entero; solo los nombres larguísimos se cortan
                            width: Math.min(implicitWidth, 520)
                            elide: Text.ElideRight
                            text: caja.tituloMusica
                            color: musicaRaton.containsMouse ? Tema.blanco : Tema.texto
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                        }
                    }
                    MouseArea {
                        id: musicaRaton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: e => e.button === Qt.MiddleButton ? Reproductor.actual?.togglePlaying() : ventana.ir("multimedia")
                        // Rueda: el volumen, como en el resto de la píldora
                        onWheel: e => ventana.subirVolumen(e.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }

                Texto {
                    id: reloj_
                    x: caja.mezcla(caja.xReloj, (caja.anchoAbierta - implicitWidth) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(reloj.date, (Ajustes.reloj24 ? "HH:mm" : "h:mm AP") + (Ajustes.relojSegundos ? ":ss" : ""))
                    color: Tema.blanco
                    // Clic en la hora: como el resto de la cabecera, abre o
                    // cierra (el calendario es su icono, 󰃭, a la derecha)
                    MouseArea {
                        anchors { fill: parent; margins: -6 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ventana.abierta ? Paneles.cerrar()
                            : Paneles.alternar("pildora", ventana.modelData, "control")
                    }
                }

                // A la derecha: avisos y, al abrirse, las páginas
                // Avisos, solo cuando pasan: las islas de la barra, sin
                // su fondo (clic = su panel)
                Row {
                    id: avisos
                    // Cerrada, tras la hora. Al abrirse se desvanecen y dejan
                    // sitio a las páginas (lo que avisan está dentro:
                    // notificaciones en control, actualizaciones en sistema)
                    x: caja.xReloj + reloj_.implicitWidth + caja.hueco
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Math.max(0, 1 - ventana.progreso * 2)
                    visible: opacity > 0
                    spacing: 0
                    // Las apps de la bandeja (Steam, Discord...): clic = su
                    // app · clic derecho = su menú
                    Bandeja { ventana: ventana; color: "transparent"; border.width: 0 }
                    Grabando { color: "transparent"; border.width: 0 }
                    Jugando { color: "transparent"; border.width: 0 }
                    Cafe { color: "transparent"; border.width: 0 }
                    Novedades { pantalla: ventana.modelData; color: "transparent"; border.width: 0 }
                    Usb { pantalla: ventana.modelData; color: "transparent"; border.width: 0 }
                    // Solo si hay notificaciones sin leer (al abrir el panel se va) o con
                // «No molestar» puesto (la campana tachada, para no olvidarlo)
                    Campana {
                        cual: "notificaciones"
                        pantalla: ventana.modelData
                        oculta: !Notificaciones.hayNuevas && !Notificaciones.noMolestar
                        color: "transparent"
                        border.width: 0
                    }
                    Bateria { pantalla: ventana.modelData; color: "transparent"; border.width: 0 }
                }

                // Páginas: crecen al abrirse
                Row {
                    id: iconos
                    x: caja.anchoAbierta - caja.margen - width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: ventana.progreso > 0
                    opacity: ventana.dentro
                    Repeater {
                        model: [
                            {id: "calendario", icono: "󰃭"},
                            {id: "clima", icono: "󰖐"},
                            {id: "sistema", icono: "󰍛"},
                            {id: "temas", icono: "󰏘"},
                            {id: "fondos", icono: "󰸉"}
                        ]
                        Rectangle {
                            id: icono
                            required property var modelData
                            readonly property bool elegida: ventana.pagina === modelData.id
                            width: 26; height: 22; radius: Tema.esquina(11)
                            color: elegida ? Tema.blanco : iconoRaton.containsMouse ? Tema.cajaHover : "transparent"
                            Behavior on color { ColorAnimation { duration: Tema.rapida } }
                            Texto {
                                anchors.centerIn: parent
                                text: icono.modelData.icono
                                font.pixelSize: 13
                                color: icono.elegida ? Tema.oscuro : Tema.texto
                            }
                            MouseArea {
                                id: iconoRaton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ventana.ir(icono.modelData.id)
                            }
                        }
                    }
                }

            }

            // --------------------------------------------------- Actividades
            Item {
                id: capaViva
                anchors.fill: parent
                opacity: Math.max(0, ventana.vivo * 2 - 1) * (1 - ventana.progreso)
                visible: opacity > 0

                // Volumen, micro o brillo: icono, barra y %
                Item {
                    visible: ["volumen", "micro", "brillo"].includes(ventana.ultima)
                    anchors.fill: parent
                    readonly property var nodo: ventana.ultima === "micro" ? ventana.entrada : ventana.salida
                    readonly property bool mudo: ventana.ultima !== "brillo" && (nodo?.audio?.muted ?? true)
                    readonly property real valor: ventana.ultima === "brillo" ? (Brillo.pantallas[0]?.valor ?? 0) : (nodo?.audio?.volume ?? 0)
                    Texto {
                        id: nivelIcono
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 22
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 16
                        color: parent.mudo ? Tema.tenue : Tema.blanco
                        text: ventana.ultima === "brillo" ? (parent.valor < 0.35 ? "󰃞" : parent.valor < 0.7 ? "󰃟" : "󰃠")
                            : ventana.ultima === "micro" ? (parent.mudo ? "󰍭" : "󰍬")
                            : parent.mudo ? "󰖁" : parent.valor < 0.34 ? "󰕿" : parent.valor < 0.67 ? "󰖀" : "󰕾"
                    }
                    Rectangle {
                        id: nivelCarril
                        anchors {
                            left: nivelIcono.right; leftMargin: 12
                            right: nivelTexto.left; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        height: 6
                        radius: 3
                        color: Tema.claro(0.18)
                        Rectangle {
                            width: Math.max(parent.height, Math.min(1, parent.parent.valor) * parent.width)
                            height: parent.height
                            radius: parent.radius
                            color: parent.parent.mudo ? Tema.tenue : Tema.blanco
                            Behavior on width { NumberAnimation { duration: Tema.rapida; easing.type: Easing.OutCubic } }
                        }
                    }
                    Texto {
                        id: nivelTexto
                        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 40
                        horizontalAlignment: Text.AlignRight
                        text: parent.mudo ? "mudo" : Math.round(parent.valor * 100) + "%"
                        color: parent.mudo ? Tema.tenue : Tema.texto
                    }
                    // Rueda: sigue subiendo o bajando
                    MouseArea {
                        anchors.fill: parent
                        onWheel: e => ventana.ultima !== "brillo" && ventana.subirVolumen(e.angleDelta.y > 0 ? 0.05 : -0.05)
                    }
                }

                // Captura: la miniatura (clic = verla)
                Item {
                    visible: ventana.ultima === "captura"
                    anchors.fill: parent
                    Item {
                        id: mini
                        anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
                        width: 114; height: 64
                        Image {
                            id: miniImagen
                            anchors.fill: parent
                            visible: false
                            source: ventana.captura ? "file://" + ventana.captura : ""
                            sourceSize: Qt.size(228, 128)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        Rectangle { id: miniMascara; anchors.fill: parent; radius: Tema.esquina(14); visible: false; layer.enabled: true }
                        MultiEffect {
                            anchors.fill: parent
                            source: miniImagen
                            maskEnabled: true
                            maskSource: miniMascara
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }
                    Column {
                        anchors { left: mini.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Texto { text: "󰄀  Captura guardada"; color: Tema.blanco }
                        Texto {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: "Clic para verla"
                            font.bold: false
                            font.pixelSize: Tema.letra - 1
                            color: Tema.gris
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yoru", "abrir", ventana.captura]);
                            ventana.actividad = "";
                        }
                    }
                }
            }

            // ------------------------------------------------------- Páginas
            Paginas {
                id: paginas
                x: 14
                y: Tema.altoBarra + 8
                width: caja.anchoAbierta - 28
                pantalla: ventana.modelData
                abierta: ventana.abierta
                visible: ventana.progreso > 0
                opacity: ventana.dentro
            }
        }
    }
}
