// ============================================================================
//  Discos — las memorias USB y discos externos conectados
//    Clic en uno = abrirlo en Archivos (si no estaba montado, se monta)
//    󰇪 = expulsarlo: desmonta y lo apaga, y ya se puede quitar
//  Los datos y las órdenes van por comun/Discos.qml (scripts/discos.py)
// ============================================================================
import QtQuick
import qs.comun

Panel {
    id: panel
    nombre: "discos"
    lado: "derecha"
    ancho: 380

    onAbiertoChanged: if (abierto) Discos.leer()
    // Al expulsar el último ya no queda nada que enseñar
    Connections {
        target: Discos
        function onListaChanged() {
            if (panel.abierto && Discos.lista.length === 0 && Discos.error === "")
                Paneles.cerrar();
        }
    }

    Column {
        width: parent.width
        spacing: 4

        Titular { texto: "Memorias y discos"; width: parent.width }

        Repeater {
            model: Discos.lista

            Fila {
                id: fila
                required property var modelData
                width: parent.width
                icono: "󰕓"
                titulo: modelData.nombre
                formato: Text.PlainText
                ocupada: Discos.ocupado === modelData.disco
                detalle: modelData.tamano + "  ·  " + (Discos.ocupado === modelData.disco ? "Un momento…"
                    : modelData.montaje !== "" ? modelData.modelo : "Sin montar")
                onClic: Discos.abrir(modelData)

                BotonIcono {
                    icono: "󰇪"
                    onClic: Discos.expulsar(fila.modelData)
                }
            }
        }

        Texto {
            visible: Discos.error !== ""
            width: parent.width
            leftPadding: 4
            text: Discos.error
            color: Tema.rojo
            font.pixelSize: 11
            font.bold: false
            wrapMode: Text.Wrap
        }
        Texto {
            width: parent.width
            leftPadding: 4
            topPadding: 4
            text: "Expúlsala antes de quitarla: así no se pierde lo que se estaba copiando."
            color: Tema.gris
            font.pixelSize: 11
            font.bold: false
            wrapMode: Text.Wrap
        }
    }
}
