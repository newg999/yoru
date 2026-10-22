// ============================================================================
//  Ajustes — personalizar Yoru sin tocar archivos
//  Es el contenido de la ventana de Ajustes (VentanaAjustes.qml): ella pone
//  la barra lateral con las secciones y aquí se ve la elegida (pestana)
//
//  Secciones: Tema · Fondo · Aspecto · Barra y dock · Pantallas · Sonido ·
//             Ratón · Teclado · Notificaciones · Energía · Fecha y hora ·
//             Apps · Acerca de
//
//    Tema:    paletas de colores (las de «yoru tema»: Yoru, del fondo, Nord...)
//    Fondo:   el fondo actual, elegir otro o pasar al siguiente, y Descubrir
//             fondos nuevos en wallhaven.cc (Descubrir.qml)
//    Barra:   arriba o a la izquierda, qué islas se ven y cuándo sale el dock
//    Aspecto: esquinas, transparencias, letra (tamaño y tipo), desenfoque, animaciones
//             y luz nocturna
//    Pantallas: colocar los monitores arrastrándolos, resolución y escala
//             (PestanaPantallas.qml; se guarda en niri/local.kdl)
//    Sonido:  salida, micrófono y volumen de cada app (PestanaSonido.qml)
//    Ratón:   velocidad, rueda, touchpad y tamaño del cursor
//             (PestanaRaton.qml; en niri/raton.kdl)
//    Teclado: distribuciones, repetición, Bloq Mayús y Bloq Num
//             (PestanaTeclado.qml; también en niri/raton.kdl)
//    Notificaciones: no molestar, duración, posición, sonido y apps
//             silenciadas (PestanaNotificaciones.qml)
//    Apps:    con qué app se abre cada cosa (PestanaApps.qml)
//    Energía: perfil, cuándo bloquear, apagar la pantalla y suspender (PestanaEnergia.qml)
//    Fecha y hora: zona horaria, hora automática y el reloj de la barra (PestanaFecha.qml)
//    Acerca de: el equipo y la versión de Yoru, buscar novedades y actualizar
//             (PestanaAcerca.qml)
//
//  Lo de Barra y Aspecto se guarda en comun/Ajustes.qml; los colores, con
//  «yoru tema» (tema/aplicar.py), que es quien los genera para todo.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.comun

Item {
    id: panel

    property bool abierto: false      // a la vista (la ventana de Ajustes abierta)
    property var pantalla: null       // donde abrir el selector de fondos
    property string pestana: "tema"   // la sección que se ve (una de Paneles.seccionesAjustes)
    implicitHeight: contenido.height

    readonly property string casa: Quickshell.env("HOME")
    readonly property string yoru: casa + "/.local/bin/yoru"

    property var temas: []            // [{id, nombre, claro, colores}] de «yoru tema --lista»
    property string aplicando: ""     // tema que se está generando
    property string error: ""

    onAbiertoChanged: {
        if (abierto) {
            error = "";
            leerTemas.running = true;
        }
    }

    function ponerTema(id) {
        if (aplicando !== "" || id === Tema.modo)
            return;
        error = "";
        aplicando = id;
        aplicar.command = [yoru, "tema", id];
        aplicar.running = true;
    }

    Process {
        id: leerTemas
        command: [panel.yoru, "tema", "--lista"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    panel.temas = JSON.parse(text);
                } catch (e) {
                    console.warn("yoru tema --lista:", e);
                }
            }
        }
    }

    Process {
        id: aplicar
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            if (codigo !== 0)
                panel.error = errores.text.trim() || "No se pudo poner el tema";
            panel.aplicando = "";
        }
    }

    // Fondo actual (lo escribe niri/scripts/wallpaper.sh)
    property string fondo: ""
    FileView {
        path: panel.casa + "/.cache/wallpaper-actual"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: panel.fondo = text().trim()
    }

    Column {
        id: contenido
        width: parent.width
        spacing: 16

        // ---------------------------------------------------------- Tema
        Column {
            visible: panel.pestana === "tema"
            width: parent.width
            spacing: 10

            Grid {
                id: rejilla
                width: parent.width
                columns: 3
                spacing: 10

                Repeater {
                    model: panel.temas

                    Rectangle {
                        id: tarjeta
                        required property var modelData
                        readonly property bool elegido: Tema.modo === modelData.id
                        readonly property bool ocupado: panel.aplicando === modelData.id
                        readonly property var c: modelData.colores
                        width: (rejilla.width - 2 * rejilla.spacing) / 3
                        height: 72
                        radius: 12
                        color: tarjetaRaton.containsMouse ? Tema.cajaHover : Tema.caja
                        border.width: elegido ? 2 : 1
                        border.color: elegido ? Tema.blanco : Tema.claro(0.10)
                        Behavior on color { ColorAnimation { duration: Tema.rapida } }

                        Column {
                            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            Row {
                                width: parent.width
                                spacing: 6
                                Texto {
                                    text: tarjeta.modelData.nombre
                                    font.pixelSize: 13
                                    width: Math.min(implicitWidth, parent.width - 40)
                                    elide: Text.ElideRight
                                }
                                Texto {
                                    visible: tarjeta.modelData.claro
                                    text: "󰖨"
                                    font.pixelSize: 13
                                    color: Tema.gris
                                }
                            }

                            // Muestra de sus colores (fondo, texto, acento y avisos); los
                            // del fondo de pantalla no se saben hasta generarlos
                            Row {
                                spacing: 6
                                visible: tarjeta.c !== null
                                Repeater {
                                    model: tarjeta.c ? [tarjeta.c.fondo, tarjeta.c.fondo2, tarjeta.c.texto, tarjeta.c.acento, tarjeta.c.rojo, tarjeta.c.amarillo] : []
                                    Rectangle {
                                        required property string modelData
                                        width: 18; height: 18; radius: 9
                                        color: modelData
                                        border.width: 1
                                        border.color: Tema.claro(0.20)
                                    }
                                }
                            }
                            Texto {
                                visible: tarjeta.c === null
                                width: parent.width
                                elide: Text.ElideRight
                                text: "Sacados del fondo de pantalla"
                                font.pixelSize: 11
                                font.bold: false
                                color: Tema.gris
                            }
                        }

                        // Elegido o generándose
                        Texto {
                            anchors { right: parent.right; top: parent.top; margins: 10 }
                            visible: tarjeta.elegido || tarjeta.ocupado
                            text: tarjeta.ocupado ? "󰔟" : "󰄬"
                            font.pixelSize: 14
                            color: Tema.blanco
                            RotationAnimation on rotation {
                                running: tarjeta.ocupado
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        MouseArea {
                            id: tarjetaRaton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.ponerTema(tarjeta.modelData.id)
                        }
                    }
                }
            }

            Texto {
                width: parent.width
                visible: panel.error !== ""
                text: panel.error
                color: Tema.rojo
                font.pixelSize: 12
                font.bold: false
                wrapMode: Text.Wrap
            }
            Texto {
                width: parent.width
                text: "Cambia la barra, los paneles, los bordes de niri y kitty. «Del fondo» se recalcula cada vez que cambias de fondo."
                color: Tema.gris
                font.pixelSize: 11
                font.bold: false
                wrapMode: Text.Wrap
            }
        }

        // --------------------------------------------------------- Fondo
        Column {
            visible: panel.pestana === "fondo"
            width: parent.width
            spacing: 12

            ClippingRectangle {
                width: parent.width
                height: Math.round(width * 9 / 16 * 0.62)
                radius: 12
                color: Tema.caja

                Image {
                    anchors.fill: parent
                    source: panel.fondo !== "" ? "file://" + panel.fondo : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 1200
                }
                Texto {
                    anchors.centerIn: parent
                    visible: panel.fondo === ""
                    text: "Sin fondo elegido"
                    color: Tema.gris
                }
            }

            Texto {
                width: parent.width
                text: panel.fondo.split("/").pop()
                color: Tema.gris
                font.pixelSize: 11
                font.bold: false
                elide: Text.ElideMiddle
            }

            Opciones {
                width: parent.width
                opciones: [
                    {id: "elegir", icono: "󰸉", texto: "Elegir fondo  (Mod+Alt+W)"},
                    {id: "siguiente", icono: "󰒭", texto: "Siguiente"}
                ]
                onElegir: id => {
                    if (id === "elegir")
                        Paneles.alternar("fondos", panel.pantalla, "");
                    else
                        Niri.lanzar([panel.casa + "/.config/niri/scripts/wallpaper.sh", "next"]);
                }
            }

            Interruptor {
                width: parent.width
                titulo: "Colores del fondo"
                detalle: "El tema sigue los colores de cada fondo que pongas"
                activo: Tema.modo === "fondo" || Tema.modo === "fondo-claro"
                onCambiar: v => panel.ponerTema(v ? "fondo" : "blanco")
            }

            Item { width: 1; height: 10 }
            Titular { texto: "Descubrir fondos nuevos"; width: parent.width }
            Descubrir {
                width: parent.width
                activa: panel.abierto && panel.pestana === "fondo"
            }
        }

        // ---------------------------------------------------- Barra y dock
        Column {
            visible: panel.pestana === "barra"
            width: parent.width
            spacing: 8

            Titular { texto: "Posición de la barra"; width: parent.width }
            Opciones {
                width: parent.width
                opciones: [
                    {id: "arriba", icono: "󰁝", texto: "Arriba"},
                    {id: "izquierda", icono: "󰁍", texto: "A la izquierda"}
                ]
                valor: Ajustes.barra
                onElegir: id => Ajustes.barra = id
            }

            Item { width: 1; height: 6 }
            Titular { texto: "Qué se ve en la barra"; width: parent.width }
            Interruptor {
                width: parent.width
                titulo: "Ventanas"
                detalle: Ajustes.ventanas === "abiertas" ? "Un icono por cada app abierta"
                    : Ajustes.vertical ? "La activa: a la izquierda, solo su icono" : "La activa: icono y título"
                activo: Ajustes.islaTitulo
                onCambiar: v => Ajustes.islaTitulo = v
            }
            Opciones {
                width: parent.width
                visible: Ajustes.islaTitulo
                opciones: [
                    {id: "activa", icono: "󰖯", texto: "Ventana activa"},
                    {id: "abiertas", icono: "󰕰", texto: "Apps abiertas"}
                ]
                valor: Ajustes.ventanas
                onElegir: id => Ajustes.ventanas = id
            }
            Interruptor {
                width: parent.width
                titulo: "Música"
                detalle: "Lo que suena y sus botones"
                activo: Ajustes.islaMusica
                onCambiar: v => Ajustes.islaMusica = v
            }
            Interruptor {
                width: parent.width
                titulo: "Clima"
                activo: Ajustes.islaClima
                onCambiar: v => Ajustes.islaClima = v
            }
            Interruptor {
                width: parent.width
                titulo: "CPU, memoria y batería"
                activo: Ajustes.islaRecursos
                onCambiar: v => Ajustes.islaRecursos = v
            }
            Interruptor {
                width: parent.width
                titulo: "Bandeja del sistema"
                detalle: "Apps en segundo plano (Discord, Telegram...)"
                activo: Ajustes.islaBandeja
                onCambiar: v => Ajustes.islaBandeja = v
            }

            Item { width: 1; height: 6 }
            Titular { texto: "Dock"; width: parent.width }
            Opciones {
                width: parent.width
                opciones: [
                    {id: "overview", icono: "󰕰", texto: "Con el overview"},
                    {id: "siempre", icono: "󰍹", texto: "Siempre"},
                    {id: "nunca", icono: "󰜺", texto: "Nunca"}
                ]
                valor: Ajustes.dock
                onElegir: id => Ajustes.dock = id
            }
        }

        // ------------------------------------------------------- Aspecto
        Column {
            visible: panel.pestana === "aspecto"
            width: parent.width
            spacing: 4

            component Regulador: Item {
                id: regulador
                property string titulo: ""
                property real valor: 0          // 0-1 en la barra
                property string mostrado: ""
                signal movido(real nuevo)
                width: parent.width
                height: 40
                Texto {
                    id: etiqueta
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 200
                    text: regulador.titulo
                    font.pixelSize: 13
                }
                Deslizador {
                    anchors {
                        left: etiqueta.right; leftMargin: 8
                        right: cifra.left; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    valor: regulador.valor
                    onMovido: nuevo => regulador.movido(nuevo)
                }
                Texto {
                    id: cifra
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 50
                    horizontalAlignment: Text.AlignRight
                    text: regulador.mostrado
                    font.pixelSize: 12
                    color: Tema.gris
                }
            }

            // Esquinas: 0-20 px
            Regulador {
                titulo: "Esquinas de la barra"
                valor: Ajustes.radio / 20
                mostrado: Ajustes.radio + " px"
                onMovido: nuevo => Ajustes.radio = Math.round(nuevo * 20)
            }
            // Las de niri: 0 (en ángulo recto) a 24 px
            Regulador {
                titulo: "Esquinas de las ventanas"
                valor: Ajustes.radioVentanas / 24
                mostrado: Ajustes.radioVentanas + " px"
                onMovido: nuevo => Ajustes.radioVentanas = Math.round(nuevo * 24)
            }
            // Transparencias: de 0 (invisible) a 1 (sólido)
            Regulador {
                titulo: "Opacidad de las islas"
                valor: Ajustes.opacidadIslas
                mostrado: Math.round(Ajustes.opacidadIslas * 100) + "%"
                onMovido: nuevo => Ajustes.opacidadIslas = Math.round(nuevo * 20) / 20
            }
            // Los paneles, de 40 a 100 %: menos no se lee
            Regulador {
                titulo: "Opacidad de los paneles"
                valor: (Ajustes.opacidadPaneles - 0.4) / 0.6
                mostrado: Math.round(Ajustes.opacidadPaneles * 100) + "%"
                onMovido: nuevo => Ajustes.opacidadPaneles = Math.round((0.4 + nuevo * 0.6) * 20) / 20
            }
            // Letra de la barra: 11-16 px
            Regulador {
                titulo: "Letra de la barra"
                valor: (Ajustes.letra - 11) / 5
                mostrado: Ajustes.letra + " px"
                onMovido: nuevo => Ajustes.letra = 11 + Math.round(nuevo * 5)
            }
            // Tipo de letra: cada botón sale escrito en la suya. Solo las
            // que estén instaladas (en otro equipo puede faltar alguna)
            Item {
                width: parent.width
                height: 40
                Texto {
                    id: etiquetaLetra
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 200
                    text: "Tipo de letra"
                    font.pixelSize: 13
                }
                Opciones {
                    anchors {
                        left: etiquetaLetra.right; leftMargin: 8
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    opciones: [
                        {id: "JetBrainsMono Nerd Font", texto: "JetBrains"},
                        {id: "Adwaita Sans", texto: "Adwaita"},
                        {id: "Noto Sans", texto: "Noto"},
                        {id: "Cantarell", texto: "Cantarell"},
                        {id: "Montserrat", texto: "Montserrat"}
                    ].filter(f => Qt.fontFamilies().includes(f.id)).map(f => Object.assign(f, {fuente: f.id}))
                    valor: Ajustes.fuente
                    onElegir: id => Ajustes.fuente = id
                }
            }

            Interruptor {
                width: parent.width
                titulo: "Desenfoque"
                detalle: "El fondo se ve borroso detrás de las islas de la barra"
                activo: Ajustes.desenfoque
                onCambiar: v => Ajustes.desenfoque = v
            }
            Interruptor {
                width: parent.width
                titulo: "Bordes"
                detalle: "Línea alrededor de las islas de la barra, los paneles y el dock"
                activo: Ajustes.bordes
                onCambiar: v => Ajustes.bordes = v
            }
            Interruptor {
                width: parent.width
                titulo: "Animaciones"
                detalle: "Paneles, islas y botones se mueven con suavidad"
                activo: Ajustes.animaciones
                onCambiar: v => Ajustes.animaciones = v
            }

            // Luz nocturna (comun/LuzNocturna.qml, con wlsunset)
            Item {
                width: parent.width
                height: 40
                Texto {
                    id: etiquetaLuz
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 200
                    text: "Luz nocturna"
                    font.pixelSize: 13
                }
                Opciones {
                    anchors {
                        left: etiquetaLuz.right; leftMargin: 8
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    opciones: [
                        {id: "apagada", icono: "󰖨", texto: "Apagada"},
                        {id: "auto", icono: "󰖚", texto: "Al anochecer"},
                        {id: "siempre", icono: "󰖔", texto: "Siempre"}
                    ]
                    valor: Ajustes.luzNocturna
                    onElegir: id => Ajustes.luzNocturna = id
                }
            }
            // Calidez: de 5500 K (poco) a 2500 K (muy anaranjada)
            Regulador {
                visible: Ajustes.luzNocturna !== "apagada"
                titulo: "Calidez"
                valor: (5500 - Ajustes.calidez) / 3000
                mostrado: Ajustes.calidez + " K"
                onMovido: nuevo => Ajustes.calidez = 5500 - Math.round(nuevo * 30) * 100
            }
            Texto {
                visible: !LuzNocturna.instalada && Ajustes.luzNocturna !== "apagada"
                width: parent.width
                leftPadding: 12
                text: "Falta wlsunset: instálalo con «sudo dnf install wlsunset»"
                font.pixelSize: 11
                font.bold: false
                color: Tema.amarillo
            }

            Item { width: 1; height: 6 }
            Opciones {
                width: parent.width
                opciones: [{id: "restablecer", icono: "󰑓", texto: "Restablecer el aspecto"}]
                onElegir: Ajustes.restablecerAspecto()
            }
        }

        // ----------------------------------------------------- Pantallas
        PestanaPantallas {
            visible: panel.pestana === "pantallas"
            activa: panel.abierto && visible
            width: parent.width
        }

        // -------------------------------------------------------- Sonido
        PestanaSonido {
            visible: panel.pestana === "sonido"
            activa: panel.abierto && visible
            width: parent.width
        }

        // --------------------------------------------------------- Ratón
        PestanaRaton {
            visible: panel.pestana === "raton"
            activa: panel.abierto && visible
            width: parent.width
        }

        // ------------------------------------------------------- Teclado
        PestanaTeclado {
            visible: panel.pestana === "teclado"
            activa: panel.abierto && visible
            width: parent.width
        }

        // ---------------------------------------------- Apps predeterminadas
        PestanaApps {
            visible: panel.pestana === "apps"
            activa: panel.abierto && visible
            width: parent.width
        }

        // ------------------------------------------------ Notificaciones
        PestanaNotificaciones {
            visible: panel.pestana === "notificaciones"
            width: parent.width
        }

        // ------------------------------------------------------- Energía
        PestanaEnergia {
            visible: panel.pestana === "energia"
            width: parent.width
        }

        // -------------------------------------------------- Fecha y hora
        PestanaFecha {
            visible: panel.pestana === "fecha"
            activa: panel.abierto && visible
            width: parent.width
        }

        // ------------------------------------------------------ Acerca de
        PestanaAcerca {
            visible: panel.pestana === "acerca"
            activa: panel.abierto && visible
            width: parent.width
        }
    }
}
