// ============================================================================
//  Ajustes › Escritorio: los widgets sobre el fondo (barra/Escritorio.qml,
//  los datos en comun/Widgets.qml)
//
//    Widgets            un interruptor para cada uno
//    Colocarlos         modo edición (arrastrar, rueda = tamaño) · restablecer
//    Aspecto            tamaño de todos, el fondo de las tarjetas, la hora
// ============================================================================
import QtQuick
import qs.comun

Column {
    id: seccion
    spacing: 8

    Titular { texto: "Colocarlos"; width: parent.width }
    Fila {
        width: parent.width
        icono: "󰏫"
        titulo: "Colocar con el ratón"
        detalle: "Arrastra cada widget a su sitio y usa la rueda para su tamaño. También con clic derecho sobre un widget"
        onClic: {
            Paneles.ajustesAbiertos = false;
            Widgets.editando = true;
        }
    }
    Fila {
        width: parent.width
        icono: "󰑓"
        titulo: "Volver a la columna de la derecha"
        detalle: "Todos a su sitio de siempre y a su tamaño normal"
        onClic: Widgets.restablecer()
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Widgets"; width: parent.width }
    Repeater {
        model: Widgets.catalogo
        Interruptor {
            required property var modelData
            width: seccion.width
            titulo: modelData.icono + "  " + modelData.nombre
            detalle: modelData.detalle
            activo: Widgets.activo(modelData.id)
            onCambiar: v => Widgets.alternar(modelData.id, v)
        }
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Tamaño"; width: parent.width }
    Opciones {
        width: parent.width
        opciones: [
            {id: "0.8", icono: "󰘕", texto: "Pequeño"},
            {id: "1", icono: "󰘖", texto: "Normal"},
            {id: "1.25", icono: "󰊓", texto: "Grande"},
            {id: "1.5", icono: "󰊓", texto: "Muy grande"}
        ]
        valor: String(Widgets.escala)
        onElegir: id => Widgets.ponerEscala(Number(id))
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Fondo de las tarjetas"; width: parent.width }
    Opciones {
        width: parent.width
        opciones: [
            {id: "0.35", icono: "󰂵", texto: "Transparente"},
            {id: "0.6", icono: "󰂷", texto: "Medio"},
            {id: "0.8", icono: "󰝤", texto: "Normal"},
            {id: "0.95", icono: "󰝤", texto: "Opaco"}
        ]
        valor: String(Widgets.opacidad)
        onElegir: id => Widgets.ponerOpacidad(Number(id))
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Hora"; width: parent.width }
    Interruptor {
        width: parent.width
        titulo: "Con segundos"
        activo: Widgets.segundos
        onCambiar: v => Widgets.ponerSegundos(v)
    }
    Interruptor {
        width: parent.width
        titulo: "Con la fecha"
        detalle: "«viernes, 6 de noviembre» bajo la hora"
        activo: Widgets.fecha
        onCambiar: v => Widgets.ponerFecha(v)
    }
}
