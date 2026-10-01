// ============================================================================
//  Velocidad — test de velocidad de internet, en mitad de la pantalla
//  Atajo: Mod+Alt+I · también sale en el lanzador («Test de velocidad»)
//
//    Al abrirse empieza solo: latencia, luego bajada y luego subida.
//    Enter (o el botón 󰑓) lo repite · Esc cierra (y para el test)
//
//  Lo que mide de verdad está en scripts/velocidad.py: contra el servidor de
//  Ookla (speedtest.net) más cercano, o contra Cloudflare si Ookla no va.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Panel {
    id: panel
    nombre: "velocidad"
    lado: "medio"
    ancho: 600

    property string fase: ""          // "" · ping · bajada · subida · fin · error
    property real ping: -1            // ms
    property string servidor: ""      // «Digimobil · Santa Cruz de Tenerife»
    property real bajada: 0           // Mbps
    property real subida: 0
    property real progreso: 0         // de la fase en curso, de 0 a 1
    property bool bajadaHecha: false
    property bool subidaHecha: false
    property string error: ""

    readonly property bool midiendo: test.running

    onAbiertoChanged: {
        if (abierto) {
            empezar();
            teclas.forceActiveFocus();
        } else {
            test.running = false;
        }
    }

    function empezar() {
        fase = "ping";
        ping = -1;
        servidor = "";
        bajada = 0;
        subida = 0;
        progreso = 0;
        bajadaHecha = false;
        subidaHecha = false;
        error = "";
        test.running = false;
        Qt.callLater(() => test.running = true);
    }

    Process {
        id: test
        command: ["python3", Quickshell.shellPath("scripts/velocidad.py")]
        stdout: SplitParser {
            onRead: linea => {
                let d;
                try {
                    d = JSON.parse(linea);
                } catch (e) {
                    return;
                }
                panel.fase = d.fase;
                if (d.servidor) panel.servidor = d.servidor;
                if (d.ms !== undefined) panel.ping = d.ms;
                if (d.progreso !== undefined) panel.progreso = d.progreso;
                if (d.fase === "bajada") {
                    panel.bajada = d.mbps;
                    panel.bajadaHecha = !!d.fin;
                } else if (d.fase === "subida") {
                    panel.subida = d.mbps;
                    panel.subidaHecha = !!d.fin;
                } else if (d.fase === "error") {
                    panel.error = d.texto;
                }
            }
        }
        onExited: codigo => {
            if (codigo !== 0 && panel.abierto && panel.fase !== "error" && panel.fase !== "fin") {
                panel.fase = "error";
                panel.error = "El test se ha parado";
            }
        }
    }

    // ------------------------------------------------------------- Dial
    // Arco de 270° con la velocidad; la escala crece sola (100, 250, 500...)
    // para que la aguja no se quede pegada al final ni al principio.
    component Dial: Item {
        id: dial
        property string icono: ""
        property string titulo: ""
        property real valor: 0
        property bool activo: false       // midiendo ahora
        property bool hecho: false        // resultado final

        readonly property var escalas: [10, 25, 50, 100, 250, 500, 1000, 2500, 10000]
        property real maximo: 100
        onValorChanged: {
            const m = escalas.find(e => e >= valor * 1.1) ?? escalas[escalas.length - 1];
            if (m > maximo)
                maximo = m;
        }
        onActivoChanged: if (activo) maximo = 100

        property real mostrado: valor
        Behavior on mostrado { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        property real fraccion: Math.min(1, mostrado / maximo)
        Behavior on maximo { NumberAnimation { duration: Tema.normal } }

        implicitWidth: 250
        implicitHeight: 250

        Canvas {
            id: arco
            anchors.fill: parent
            readonly property real fraccion: dial.fraccion
            readonly property bool encendido: dial.activo || dial.hecho
            onFraccionChanged: requestPaint()
            onEncendidoChanged: requestPaint()
            Connections {
                target: Tema
                function onBlancoChanged() { arco.requestPaint(); }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const c = width / 2;
                const r = c - 12;
                const desde = Math.PI * 0.75;
                const barrido = Math.PI * 1.5;
                ctx.lineCap = "round";
                ctx.lineWidth = 10;

                ctx.beginPath();
                ctx.arc(c, c, r, desde, desde + barrido);
                ctx.strokeStyle = Tema.claro(0.08);
                ctx.stroke();

                if (fraccion > 0.002) {
                    ctx.beginPath();
                    ctx.arc(c, c, r, desde, desde + barrido * fraccion);
                    ctx.strokeStyle = encendido ? Tema.blanco : Tema.claro(0.35);
                    ctx.stroke();
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.icono + "  " + dial.titulo.toUpperCase()
                font.pixelSize: 11
                font.letterSpacing: 1
                color: dial.activo ? Tema.texto : Tema.gris
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.activo || dial.hecho ? (dial.mostrado >= 100 ? Math.round(dial.mostrado) : dial.mostrado.toFixed(1)) : "—"
                font.pixelSize: 44
                color: dial.hecho || dial.activo ? Tema.blanco : Tema.tenue
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Mbps"
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
        }

        // Fin de la escala, abajo a la derecha del arco
        Texto {
            anchors { right: parent.right; rightMargin: 28; bottom: parent.bottom; bottomMargin: 18 }
            text: dial.maximo >= 1000 ? Math.round(dial.maximo / 1000) + "G" : Math.round(dial.maximo)
            font.bold: false
            font.pixelSize: 10
            color: Tema.gris
        }
        Texto {
            anchors { left: parent.left; leftMargin: 32; bottom: parent.bottom; bottomMargin: 18 }
            text: "0"
            font.bold: false
            font.pixelSize: 10
            color: Tema.gris
        }
    }

    // Un dato pequeño bajo los diales: latencia, servidor...
    component Dato: Column {
        property string icono: ""
        property string titulo: ""
        property string valor: ""
        spacing: 2
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.icono + "  " + parent.titulo.toUpperCase()
            font.pixelSize: 10
            font.letterSpacing: 1
            color: Tema.gris
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.valor
            font.pixelSize: 15
        }
    }

    Item {
        id: teclas
        width: parent.width
        implicitHeight: columna.implicitHeight
        focus: true
        Keys.onReturnPressed: panel.empezar()
        Keys.onEnterPressed: panel.empezar()

        Column {
            id: columna
            width: parent.width
            spacing: 12

            Titular {
                width: parent.width
                texto: panel.fase === "ping" ? "Test de velocidad · conectando…"
                    : panel.fase === "bajada" ? "Test de velocidad · midiendo la bajada…"
                    : panel.fase === "subida" ? "Test de velocidad · midiendo la subida…"
                    : panel.fase === "error" ? "Test de velocidad · no se pudo terminar"
                    : "Test de velocidad"

                BotonIcono {
                    icono: "󰑓"
                    girando: panel.midiendo
                    onClic: panel.empezar()
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Dial {
                    icono: "󰇚"
                    titulo: "Bajada"
                    valor: panel.bajada
                    activo: panel.fase === "bajada" && !panel.bajadaHecha
                    hecho: panel.bajadaHecha
                }
                Dial {
                    icono: "󰕒"
                    titulo: "Subida"
                    valor: panel.subida
                    activo: panel.fase === "subida" && !panel.subidaHecha
                    hecho: panel.subidaHecha
                }
            }

            // Avance de la fase en curso
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Tema.caja
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: Tema.claro(0.6)
                    width: parent.width * (panel.fase === "fin" ? 1
                        : panel.fase === "subida" ? 0.5 + panel.progreso / 2
                        : panel.fase === "bajada" ? panel.progreso / 2 : 0)
                    Behavior on width { NumberAnimation { duration: 250 } }
                }
            }

            // Por qué se paró (sin internet, Cloudflare nos frena...)
            Rectangle {
                visible: panel.fase === "error"
                width: parent.width
                height: aviso.implicitHeight + 20
                radius: 10
                color: Tema.conAlfa(Tema.rojo, 0.15)
                border.width: 1
                border.color: Tema.conAlfa(Tema.rojo, 0.4)
                Texto {
                    id: aviso
                    anchors.centerIn: parent
                    width: parent.width - 28
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    text: "󰀦  " + panel.error
                    font.bold: false
                    color: Tema.rojo
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 56
                Dato {
                    icono: "󰓅"
                    titulo: "Latencia"
                    valor: panel.ping >= 0 ? Math.round(panel.ping) + " ms" : "—"
                }
                Dato {
                    icono: "󰒍"
                    titulo: "Servidor"
                    valor: panel.servidor !== "" ? panel.servidor : "—"
                }
            }

            Texto {
                leftPadding: 4
                text: "Enter repite el test  ·  Esc cierra"
                font.bold: false
                font.pixelSize: 11
                color: Tema.gris
            }
        }
    }
}
