// ============================================================================
//  Ajustes › Acerca de — el equipo, el sistema y la versión de Yoru
//  Los datos los da scripts/acerca.py. «Buscar novedades» pregunta a GitHub
//  (git fetch) si hay cambios nuevos de Yoru; «Actualizar» abre una terminal
//  con «yoru update» (pide la contraseña: actualiza también el sistema).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.comun

Column {
    id: seccion
    spacing: 8

    property bool activa: false        // a la vista: se lee de nuevo
    onActivaChanged: if (activa) leer(false)

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/yoru/scripts/acerca.py"
    property var datos: null
    property bool buscando: false
    property bool buscado: false       // ya se preguntó a GitHub

    function leer(buscar) {
        if (lector.running)
            return;
        buscando = buscar;
        lector.command = [script, buscar ? "buscar" : "leer"];
        lector.running = true;
    }

    Process {
        id: lector
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    seccion.datos = JSON.parse(text);
                } catch (e) {
                    console.warn("acerca.py:", e);
                }
                if (seccion.buscando)
                    seccion.buscado = true;
                seccion.buscando = false;
            }
        }
    }

    // ------------------------------------------------------ Cabecera
    Rectangle {
        width: parent.width
        height: 120
        radius: Tema.esquina(12)
        color: Tema.caja

        Row {
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            spacing: 22
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: "夜"
                font.pixelSize: 64
                color: Tema.blanco
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Texto {
                    text: "Yoru"
                    font.pixelSize: 24
                    color: Tema.blanco
                }
                Texto {
                    text: seccion.datos ? `${seccion.datos.sistema}  ·  ${seccion.datos.escritorio}` : ""
                    font.pixelSize: 13
                    font.bold: false
                    color: Tema.texto
                }
                Texto {
                    text: seccion.datos?.equipo ?? ""
                    font.pixelSize: 12
                    font.bold: false
                    color: Tema.gris
                }
            }
        }
    }

    // --------------------------------------------------------- El equipo
    Item { width: 1; height: 6 }
    Titular { texto: "Equipo"; width: parent.width }
    Repeater {
        model: {
            const d = seccion.datos;
            if (!d)
                return [];
            return [
                ["󰌢", "Modelo", d.modelo],
                ["󰍛", "Procesador", d.procesador],
                ["󰢮", d.graficas.length > 1 ? "Gráficas" : "Gráfica", d.graficas.join("  ·  ")],
                ["󰘚", "Memoria", `${String(d.memoria).replace(".", ",")} GB`],
                ["󰋊", "Disco", `${d.disco.usado} GB usados de ${d.disco.total} GB`],
                ["󰌽", "Kernel", d.kernel]
            ].filter(f => f[2]);
        }
        Rectangle {
            id: fila
            required property var modelData
            width: seccion.width
            height: 40
            radius: Tema.esquina(10)
            color: "transparent"

            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 12
                Texto {
                    width: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: fila.modelData[0]
                    font.pixelSize: 15
                    color: Tema.gris
                }
                Texto {
                    text: fila.modelData[1]
                    font.pixelSize: 13
                    color: Tema.gris
                }
            }
            Texto {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth, parent.width - 200)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideMiddle
                text: fila.modelData[2]
                font.pixelSize: 13
            }
        }
    }

    // ------------------------------------------------------------- Yoru
    Item { width: 1; height: 6 }
    Titular { texto: "Versión de Yoru"; width: parent.width }
    Rectangle {
        width: parent.width
        height: 64
        radius: Tema.esquina(12)
        color: Tema.caja
        visible: seccion.datos?.yoru != null

        Column {
            anchors { left: parent.left; leftMargin: 16; right: estado.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 4
            Texto {
                width: parent.width
                elide: Text.ElideRight
                text: seccion.datos?.yoru?.mensaje ?? ""
                font.pixelSize: 13
            }
            Texto {
                width: parent.width
                elide: Text.ElideMiddle
                text: {
                    const y = seccion.datos?.yoru;
                    return y ? `${y.commit}  ·  ${y.fecha}  ·  ${y.repo}` + (y.cambiosLocales ? "  ·  con cambios tuyos sin subir" : "") : "";
                }
                font.pixelSize: 11
                font.bold: false
                color: Tema.gris
            }
        }
        Texto {
            id: estado
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            text: {
                const n = seccion.datos?.yoru?.nuevos ?? 0;
                if (seccion.buscando)
                    return "Buscando…";
                if (n > 0)
                    return `󰚰  ${n} ${n === 1 ? "cambio nuevo" : "cambios nuevos"}`;
                return seccion.buscado ? "󰄬  Al día" : "";
            }
            font.pixelSize: 13
            color: (seccion.datos?.yoru?.nuevos ?? 0) > 0 ? Tema.amarillo : Tema.texto
        }
    }

    Opciones {
        width: parent.width
        visible: seccion.datos?.yoru != null
        opciones: [
            {id: "buscar", icono: "󰑓", texto: "Buscar novedades"},
            {id: "actualizar", icono: "󰚰", texto: "Actualizar Yoru y el sistema"},
            {id: "web", icono: "󰊤", texto: "Ver en GitHub"}
        ]
        onElegir: id => {
            if (id === "buscar")
                seccion.leer(true);
            else if (id === "actualizar")
                Niri.lanzar(["kitty", "--hold", "-e", Quickshell.env("HOME") + "/.local/bin/yoru", "update"]);
            else if (seccion.datos.yoru.web)
                Niri.lanzar(["xdg-open", seccion.datos.yoru.web]);
        }
    }
    Texto {
        width: parent.width
        text: "«Actualizar» abre una terminal con «yoru update»: baja lo nuevo de Yoru, actualiza el sistema y las apps, y vuelve a pasar el instalador. Te pedirá la contraseña."
        color: Tema.gris
        font.pixelSize: 11
        font.bold: false
        wrapMode: Text.Wrap
    }
}
