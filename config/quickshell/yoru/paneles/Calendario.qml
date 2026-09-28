// ============================================================================
//  Calendario del mes · 󰅁 󰅂, rueda o ← → = cambiar de mes · clic en el
//  título o Inicio = hoy · 󰃭 abre la app Calendario (eventos)
//  Hoy va en blanco con el número oscuro, como la fila elegida de los menús.
// ============================================================================
import QtQuick
import Quickshell
import qs.comun

Item {
    id: cal

    readonly property var meses: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
        "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var semana: ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]

    SystemClock {
        id: reloj
        precision: SystemClock.Hours
    }
    readonly property date hoy: reloj.date

    // Mes que se ve (se vuelve a hoy cada vez que se abre el panel)
    property int anio: hoy.getFullYear()
    property int mes: hoy.getMonth()
    function volverAHoy() {
        anio = hoy.getFullYear();
        mes = hoy.getMonth();
    }
    function mover(n) {
        const d = new Date(anio, mes + n, 1);
        anio = d.getFullYear();
        mes = d.getMonth();
    }

    // 42 casillas (6 semanas) empezando en lunes
    readonly property var casillas: {
        const primero = new Date(anio, mes, 1);
        const hueco = (primero.getDay() + 6) % 7;
        const lista = [];
        for (let i = 0; i < 42; i++)
            lista.push(new Date(anio, mes, 1 - hueco + i));
        return lista;
    }

    WheelHandler {
        onWheel: e => cal.mover(e.angleDelta.y > 0 ? -1 : 1)
    }

    // Teclado (el panel central le da el foco al abrirse)
    focus: true
    Keys.onLeftPressed: mover(-1)
    Keys.onRightPressed: mover(1)
    Keys.onUpPressed: mover(-12)
    Keys.onDownPressed: mover(12)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            volverAHoy();
            event.accepted = true;
        }
    }

    Column {
        anchors.fill: parent
        spacing: 4

        // Cabecera: 󰅁  septiembre 2026  󰅂
        Item {
            width: parent.width
            height: 32

            BotonIcono {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                icono: "󰅁"
                onClic: cal.mover(-1)
            }
            Texto {
                anchors.centerIn: parent
                text: cal.meses[cal.mes] + " " + cal.anio
                font.pixelSize: 14
                color: tituloRaton.containsMouse ? Tema.blanco : Tema.texto
                MouseArea {
                    id: tituloRaton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cal.volverAHoy()
                }
            }
            BotonIcono {
                id: siguiente
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                icono: "󰅂"
                onClic: cal.mover(1)
            }
            BotonIcono {
                anchors { right: siguiente.left; verticalCenter: parent.verticalCenter }
                icono: "󰃭"
                ayuda: "Abrir Calendario (eventos)"
                colorIcono: Tema.gris
                onClic: {
                    Quickshell.execDetached(["gnome-calendar"]);
                    Paneles.cerrar();
                }
            }
        }

        Grid {
            id: rejilla
            columns: 7
            width: parent.width
            readonly property real celda: width / 7

            Repeater {
                model: cal.semana
                Texto {
                    required property string modelData
                    width: rejilla.celda
                    height: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: 11
                    color: Tema.gris
                }
            }

            Repeater {
                model: cal.casillas
                Item {
                    id: dia
                    required property var modelData
                    readonly property bool esHoy: modelData.toDateString() === cal.hoy.toDateString()
                    readonly property bool deEsteMes: modelData.getMonth() === cal.mes
                    width: rejilla.celda
                    height: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 15
                        color: Tema.blanco
                        visible: dia.esHoy
                    }
                    Texto {
                        anchors.centerIn: parent
                        text: dia.modelData.getDate()
                        font.pixelSize: 12
                        font.bold: dia.esHoy
                        color: dia.esHoy ? Tema.oscuro : dia.deEsteMes ? Tema.texto : Tema.claro(0.25)
                    }
                }
            }
        }
    }
}
