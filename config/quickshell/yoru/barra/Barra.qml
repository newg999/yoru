// ============================================================================
//  Barra — una por pantalla. La barra en sí es invisible: solo se ven las islas.
//
//  Arriba (lo normal):
//    [escritorios] [título o apps abiertas]    [música] [reloj] [clima]
//        [cpu] [memoria] [temperatura] [portapapeles] [bandeja] [avisos, si los hay] [notificaciones, si hay] [batería] [conexión]
//
//  A la izquierda (Ajustes → Barra y dock), lo mismo en columna:
//    arriba escritorios y ventana · en medio música, reloj y clima ·
//    abajo cpu, memoria, portapapeles, bandeja... hasta la conexión
//
//  El reloj va siempre en el centro exacto; la música y el clima, a sus lados.
//  Si no caben sin chocar con los grupos de los lados (pantallas pequeñas),
//  se esconden en vez de montarse encima.
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
    // Monitor pequeño (portátil) → títulos más cortos; muy estrecho
    // (1366x768 o con escala) → más cortos todavía
    readonly property bool pequena: modelData.width < 1800
    readonly property bool estrecha: modelData.width < 1500

    anchors {
        top: true
        left: true
        right: !barra.vertical
        bottom: barra.vertical
    }
    implicitHeight: Tema.margenBarra + Tema.altoBarra
    implicitWidth: Tema.margenBarra + Tema.anchoBarra
    exclusiveZone: Tema.zonaBarra
    color: "transparent"
    // Con la barra en píldora o minimalista (Ajustes › Barra y dock) se ven
    // paneles/Pildora.qml o barra/BarraMinima.qml
    visible: !Ajustes.centrada
    WlrLayershell.namespace: "yoru-barra"
    WlrLayershell.layer: WlrLayer.Top

    // Escondida: sin zona de clic, para que los clics lleguen al overview
    mask: Niri.overview ? vacia : null
    Region { id: vacia }

    // «No suspender» (Centro de control): swayidle no hace nada mientras
    IdleInhibitor {
        window: barra
        enabled: Despierto.activo
    }

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
        Region { item: grabando; radius: Tema.radio }
        Region { item: bandeja; radius: Tema.radio }
        Region { item: jugando; radius: Tema.radio }
        Region { item: cafe; radius: Tema.radio }
        Region { item: novedades; radius: Tema.radio }
        Region { item: discos; radius: Tema.radio }
        Region { item: portapapeles; radius: Tema.radio }
        Region { item: cpu; radius: Tema.radio }
        Region { item: memoria; radius: Tema.radio }
        Region { item: notificaciones; radius: Tema.radio }
        Region { item: bateria; radius: Tema.radio }
        Region { item: conexion; radius: Tema.radio }
        Region { item: temperatura; radius: Tema.radio }
    }

    // Un grupo de islas: en fila arriba, en columna a la izquierda
    component Grupo: Grid {
        // Lo que ocupan las islas visibles (Grid cuenta también la separación
        // de las ocultas, p. ej. la bandeja vacía, y sobraban 6 px al final)
        readonly property int largo: {
            let fin = 0;
            for (const hijo of children)
                if (hijo.visible)
                    fin = Math.max(fin, barra.vertical ? hijo.y + hijo.height : hijo.x + hijo.width);
            return Math.ceil(fin);
        }
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
        // «pos» movida lo justo para quedar entre «desde» y «hasta» (con separación)
        function enHueco(pos, largo, desde, hasta) {
            return Math.max(desde + sep, Math.min(pos, hasta - largo - sep));
        }

        // ¿Cabe la música entre el grupo de arriba/izquierda y el reloj? ¿Y
        // el clima entre el reloj y el grupo de abajo/derecha?
        readonly property bool cabeMusica: barra.vertical
            ? grupoInicio.y + grupoInicio.largo + sep + musica.largoNatural + sep <= reloj.y
            : grupoInicio.x + grupoInicio.largo + sep + musica.largoNatural + sep <= reloj.x
        readonly property bool cabeClima: barra.vertical
            ? reloj.y + reloj.height + sep + clima.largoNatural + sep <= grupoFin.y
            : reloj.x + reloj.width + sep + clima.largoNatural + sep <= grupoFin.x

        // ---------------------------------------------- Izquierda (o arriba)
        Grupo {
            id: grupoInicio
            x: 0
            y: barra.vertical ? 0 : contenido.centrado(height)

            Escritorios { id: escritorios; salida: barra.modelData.name }
            // La ventana activa o todas las abiertas (Ajustes → Barra y dock)
            Titulo {
                id: titulo
                oculta: !Ajustes.islaTitulo || Ajustes.ventanas !== "activa"
                salida: barra.modelData.name
                maximo: barra.estrecha ? 180 : barra.pequena ? 300 : 420
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
            oculta: !Ajustes.islaMusica || !contenido.cabeMusica
            x: barra.vertical ? 0 : reloj.x - width - contenido.sep
            y: barra.vertical ? reloj.y - height - contenido.sep : contenido.centrado(height)
            pantalla: barra.modelData
            maximo: barra.estrecha ? 90 : barra.pequena ? 140 : 200
        }
        // En el centro exacto, salvo que choque con un grupo de los lados
        // (barra a la izquierda en pantallas bajas): entonces, en el hueco libre
        Reloj {
            id: reloj
            x: barra.vertical ? 0 : contenido.enHueco(Math.round((contenido.width - width) / 2), width,
                                                     grupoInicio.x + grupoInicio.largo, grupoFin.x)
            y: !barra.vertical ? contenido.centrado(height)
                : contenido.enHueco(contenido.centrado(height), height, grupoInicio.y + grupoInicio.largo, grupoFin.y)
            pantalla: barra.modelData
        }
        Clima {
            id: clima
            oculta: !Ajustes.islaClima || !contenido.cabeClima
            x: barra.vertical ? 0 : reloj.x + reloj.width + contenido.sep
            y: barra.vertical ? reloj.y + reloj.height + contenido.sep : contenido.centrado(height)
            pantalla: barra.modelData
        }

        // ------------------------------------------------ Derecha (o abajo)
        Grupo {
            id: grupoFin
            x: barra.vertical ? 0 : Math.round(contenido.width - largo)
            y: barra.vertical ? Math.round(contenido.height - largo) : contenido.centrado(height)

            // El mismo orden que la minimalista: uso, portapapeles, bandeja,
            // avisos (solo cuando pasan), notificaciones (solo si hay sin leer),
            // batería y la conexión, que abre el centro de control. (Apagar:
            // en el centro de control o Mod+Shift+BackSpace)
            Recursos { id: cpu; cual: "cpu"; pantalla: barra.modelData; oculta: !Ajustes.islaRecursos }
            Recursos { id: memoria; cual: "memoria"; pantalla: barra.modelData; oculta: !Ajustes.islaRecursos }
            Recursos { id: temperatura; cual: "temperatura"; pantalla: barra.modelData; oculta: !Ajustes.islaRecursos || Sistema.temperatura <= 0 }
            Campana { id: portapapeles; cual: "portapapeles"; pantalla: barra.modelData }
            Bandeja { id: bandeja; ventana: barra; oculta: !Ajustes.islaBandeja }
            Grabando { id: grabando }
            Jugando { id: jugando }
            Cafe { id: cafe }
            Novedades { id: novedades; pantalla: barra.modelData }
            Usb { id: discos; pantalla: barra.modelData }
            Campana { id: notificaciones; cual: "notificaciones"; pantalla: barra.modelData; oculta: !Notificaciones.hayNuevas && !Notificaciones.noMolestar }
            Bateria { id: bateria; pantalla: barra.modelData }
            Conexion { id: conexion; pantalla: barra.modelData; soloActivo: true }
        }
    }
}
