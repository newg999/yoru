// ============================================================================
//  Pestaña Ratón de Ajustes — ratón, touchpad y cursor
//
//    Ratón:    velocidad, rueda, aceleración, scroll natural y zurdo
//    Touchpad: velocidad, tocar = clic, scroll natural, apagarlo al escribir
//              o con un ratón conectado (solo si el equipo tiene touchpad)
//    Cursor:   tamaño y esconderlo al escribir
//
//  Se guarda en niri/local.kdl con scripts/raton.py (un momento después de
//  dejar de tocar, para no recargar niri a cada paso del deslizador).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Item {
    id: pestana

    property bool activa: false
    property var datos: null          // {raton, touchpad, cursor, hayTouchpad}
    property string error: ""

    implicitHeight: columnas.height + 12 + pie.height
    onActivaChanged: if (activa) lector.running = true

    // Cambia un ajuste y guarda al rato
    function poner(seccion, clave, valor) {
        const d = JSON.parse(JSON.stringify(datos));
        d[seccion][clave] = valor;
        datos = d;
        espera.restart();
    }

    Timer {
        id: espera
        interval: 400
        onTriggered: {
            pestana.error = "";
            escritor.command = [Quickshell.shellPath("scripts/raton.py"), "guardar", JSON.stringify(pestana.datos)];
            escritor.running = true;
        }
    }

    Process {
        id: lector
        command: [Quickshell.shellPath("scripts/raton.py"), "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pestana.datos = JSON.parse(text);
                } catch (e) {
                    pestana.error = "No se pudieron leer los ajustes del ratón";
                }
            }
        }
    }

    Process {
        id: escritor
        stderr: StdioCollector { id: errores }
        onExited: codigo => {
            if (codigo !== 0)
                pestana.error = errores.text.trim() || "No se pudo guardar";
        }
    }

    Process {
        id: restablecedor
        command: [Quickshell.shellPath("scripts/raton.py"), "restablecer"]
        onExited: lector.running = true
    }

    // Fila con un deslizador (como las de Aspecto)
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
            width: 96
            text: regulador.titulo
            font.pixelSize: 13
        }
        Deslizador {
            anchors {
                left: etiqueta.right; leftMargin: 8
                right: cifra.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            valor: regulador.valor
            onMovido: nuevo => regulador.movido(nuevo)
        }
        Texto {
            id: cifra
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: 40
            horizontalAlignment: Text.AlignRight
            text: regulador.mostrado
            font.pixelSize: 12
            color: Tema.gris
        }
    }

    function decimal(v, signo) {
        const t = (Math.round(v * 10) / 10).toFixed(1).replace(".", ",");
        return signo && v > 0 ? "+" + t : t;
    }

    Row {
        id: columnas
        visible: pestana.datos !== null
        width: parent.width
        spacing: 16
        readonly property real mitad: (width - spacing) / 2

        // ------------------------------------------- Ratón y cursor
        Column {
            width: columnas.mitad
            spacing: 2

            Titular { texto: "Ratón"; width: parent.width }
            // Velocidad: -1 a 1, de 0,1 en 0,1
            Regulador {
                titulo: "Velocidad"
                valor: pestana.datos ? (pestana.datos.raton.velocidad + 1) / 2 : 0
                mostrado: pestana.datos ? pestana.decimal(pestana.datos.raton.velocidad, true) : ""
                onMovido: nuevo => pestana.poner("raton", "velocidad", Math.round((nuevo * 2 - 1) * 10) / 10)
            }
            // Rueda: de 0,2 a 3 veces lo normal
            Regulador {
                titulo: "Rueda"
                valor: pestana.datos ? (pestana.datos.raton.rueda - 0.2) / 2.8 : 0
                mostrado: pestana.datos ? pestana.decimal(pestana.datos.raton.rueda, false) + "×" : ""
                onMovido: nuevo => pestana.poner("raton", "rueda", Math.round((0.2 + nuevo * 2.8) * 10) / 10)
            }
            Item { width: 1; height: 4 }
            Opciones {
                width: parent.width
                opciones: [
                    {id: "adaptive", icono: "󰓅", texto: "Aceleración"},
                    {id: "flat", icono: "󰕭", texto: "Sin aceleración"}
                ]
                valor: pestana.datos?.raton.perfil ?? ""
                onElegir: id => pestana.poner("raton", "perfil", id)
            }
            Item { width: 1; height: 4 }
            Interruptor {
                width: parent.width
                titulo: "Desplazamiento natural"
                detalle: "La rueda mueve la página como en el móvil"
                activo: pestana.datos?.raton.natural ?? false
                onCambiar: v => pestana.poner("raton", "natural", v)
            }
            Interruptor {
                width: parent.width
                titulo: "Para zurdos"
                detalle: "Cambia el botón izquierdo por el derecho"
                activo: pestana.datos?.raton.zurdo ?? false
                onCambiar: v => pestana.poner("raton", "zurdo", v)
            }

            Item { width: 1; height: 6 }
            Titular { texto: "Cursor"; width: parent.width }
            Opciones {
                width: parent.width
                opciones: [24, 32, 40, 48].map(t => ({id: String(t), texto: t === 24 ? "Normal" : t + " px"}))
                valor: pestana.datos ? String(pestana.datos.cursor.tamano) : ""
                onElegir: id => pestana.poner("cursor", "tamano", Number(id))
            }
            Item { width: 1; height: 4 }
            Interruptor {
                width: parent.width
                titulo: "Esconderlo al escribir"
                detalle: "Vuelve en cuanto mueves el ratón"
                activo: pestana.datos?.cursor.esconder ?? false
                onCambiar: v => pestana.poner("cursor", "esconder", v)
            }
        }

        // ---------------------------------------------------- Touchpad
        Column {
            width: columnas.mitad
            spacing: 2
            visible: pestana.datos?.hayTouchpad ?? false

            Titular { texto: "Touchpad"; width: parent.width }
            Regulador {
                titulo: "Velocidad"
                valor: pestana.datos ? (pestana.datos.touchpad.velocidad + 1) / 2 : 0
                mostrado: pestana.datos ? pestana.decimal(pestana.datos.touchpad.velocidad, true) : ""
                onMovido: nuevo => pestana.poner("touchpad", "velocidad", Math.round((nuevo * 2 - 1) * 10) / 10)
            }
            Regulador {
                titulo: "Desplazar"
                valor: pestana.datos ? (pestana.datos.touchpad.rueda - 0.2) / 2.8 : 0
                mostrado: pestana.datos ? pestana.decimal(pestana.datos.touchpad.rueda, false) + "×" : ""
                onMovido: nuevo => pestana.poner("touchpad", "rueda", Math.round((0.2 + nuevo * 2.8) * 10) / 10)
            }
            Item { width: 1; height: 4 }
            Interruptor {
                width: parent.width
                titulo: "Tocar para hacer clic"
                detalle: "Sin tener que hundir el touchpad"
                activo: pestana.datos?.touchpad.tocar ?? false
                onCambiar: v => pestana.poner("touchpad", "tocar", v)
            }
            Interruptor {
                width: parent.width
                titulo: "Desplazamiento natural"
                detalle: "Con dos dedos, como en el móvil"
                activo: pestana.datos?.touchpad.natural ?? false
                onCambiar: v => pestana.poner("touchpad", "natural", v)
            }
            Interruptor {
                width: parent.width
                titulo: "Ignorarlo mientras escribes"
                detalle: "Para no mover el cursor con la palma"
                activo: pestana.datos?.touchpad.escribiendo ?? false
                onCambiar: v => pestana.poner("touchpad", "escribiendo", v)
            }
            Interruptor {
                width: parent.width
                titulo: "Apagarlo con un ratón"
                detalle: "Con un ratón conectado no responde"
                activo: pestana.datos?.touchpad.conRaton ?? false
                onCambiar: v => pestana.poner("touchpad", "conRaton", v)
            }
        }
    }

    Column {
        id: pie
        anchors.top: columnas.bottom
        anchors.topMargin: 12
        width: parent.width
        spacing: 8

        Texto {
            width: parent.width
            visible: pestana.error !== ""
            text: pestana.error
            color: Tema.rojo
            font.pixelSize: 12
            font.bold: false
            wrapMode: Text.Wrap
        }
        Opciones {
            width: parent.width
            opciones: [{id: "restablecer", icono: "󰑓", texto: "Restablecer el ratón"}]
            onElegir: restablecedor.running = true
        }
        Texto {
            width: parent.width
            text: "Se aplica al momento. El tamaño del cursor, en las apps ya abiertas, al volver a abrirlas."
            color: Tema.gris
            font.pixelSize: 11
            font.bold: false
            wrapMode: Text.Wrap
        }
    }
}
