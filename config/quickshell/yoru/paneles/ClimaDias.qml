// ============================================================================
//  Clima por días (Resumen) · 󰅁 󰅂 o la rueda = otro día de los 7
//  Hoy enseña lo de ahora; los demás días, la máxima y la mínima.
//  Clic en el lugar = pestaña Clima (para cambiarlo, ver los 7 días...)
// ============================================================================
import QtQuick
import qs.comun

Item {
    id: clima

    property int dia: 0
    function volverAHoy() { dia = 0; }
    function mover(n) { dia = Math.max(0, Math.min(Tiempo.dias.length - 1, dia + n)); }

    readonly property bool hoy: dia === 0
    readonly property var datos: Tiempo.dias[dia] ?? {}
    readonly property var diasSemana: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property string nombre: dia === 0 ? "hoy" : dia === 1 ? "mañana"
        : datos.fecha ? diasSemana[new Date(datos.fecha + "T12:00").getDay()] : ""

    WheelHandler {
        onWheel: e => clima.mover(e.angleDelta.y > 0 ? -1 : 1)
    }

    Texto {
        visible: !Tiempo.listo
        anchors.centerIn: parent
        text: "Cargando el tiempo…"
        font.bold: false
        color: Tema.gris
    }

    // Cabecera: 󰅁  MIÉRCOLES  󰅂
    Item {
        id: cabecera
        visible: Tiempo.listo
        width: parent.width
        height: 32

        BotonIcono {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            icono: "󰅁"
            colorIcono: clima.dia > 0 ? Tema.texto : Tema.tenue
            onClic: clima.mover(-1)
        }
        Texto {
            anchors.centerIn: parent
            text: clima.nombre.toUpperCase()
            font.pixelSize: 13
            font.letterSpacing: 1.5
            color: Tema.texto
        }
        BotonIcono {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            icono: "󰅂"
            colorIcono: clima.dia < Tiempo.dias.length - 1 ? Tema.texto : Tema.tenue
            onClic: clima.mover(1)
        }
    }

    // Icono · temperatura, lugar y cielo
    Item {
        visible: Tiempo.listo
        anchors { top: cabecera.bottom; topMargin: 18; left: parent.left; right: parent.right }
        height: 130

        Texto {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: clima.hoy ? Tiempo.icono : Tiempo.iconoDe(clima.datos.codigo ?? 0, true)
            font.pixelSize: 58
            color: Tema.blanco
        }
        Column {
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            Texto {
                anchors.right: parent.right
                text: (clima.hoy ? Tiempo.temperatura : clima.datos.max) + "°C"
                font.pixelSize: 54
                color: Tema.blanco
            }
            Texto {
                anchors.right: parent.right
                text: clima.hoy ? Tiempo.descripcion
                    : Tiempo.descripcionDe(clima.datos.codigo ?? 0) + " · mín " + clima.datos.min + "°"
                font.bold: false
                font.pixelSize: 12
                color: Tema.gris
            }
            Item { width: 1; height: 4 }
            Texto {
                anchors.right: parent.right
                text: "󰍎 " + (Tiempo.lugar || "Elegir lugar")
                font.pixelSize: 13
                color: lugarRaton.containsMouse ? Tema.blanco : Tema.texto
                MouseArea {
                    id: lugarRaton
                    anchors { fill: parent; margins: -4 }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Paneles.seccion = "clima"
                }
            }
        }
    }

    // Viento, humedad, lluvia y sensación
    Grid {
        id: detalles
        visible: Tiempo.listo
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        columns: 2
        spacing: 8
        Repeater {
            model: [
                {icono: "󰖝", valor: (clima.hoy ? Tiempo.viento : clima.datos.viento) + " km/h", texto: "viento"},
                {icono: "󰖎", valor: (clima.hoy ? Tiempo.humedad : clima.datos.humedad) + "%", texto: "humedad"},
                {icono: "󰖌", valor: (clima.datos.lluvia ?? 0) + "%", texto: "lluvia"},
                {icono: "󰔏", valor: (clima.hoy ? Tiempo.sensacion : clima.datos.sensacion) + "°", texto: "sensación"}
            ]
            Tarjeta {
                id: detalle
                required property var modelData
                width: (detalles.width - detalles.spacing) / 2
                height: 52
                Row {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 12
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: detalle.modelData.icono
                        font.pixelSize: 18
                        color: Tema.texto
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Texto {
                            text: detalle.modelData.valor
                            font.pixelSize: 13
                            color: Tema.blanco
                        }
                        Texto {
                            text: detalle.modelData.texto
                            font.bold: false
                            font.pixelSize: 11
                            color: Tema.gris
                        }
                    }
                }
            }
        }
    }
}
