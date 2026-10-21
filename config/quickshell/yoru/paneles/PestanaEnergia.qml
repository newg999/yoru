// ============================================================================
//  Ajustes › Energía — cuándo se bloquea, se apaga la pantalla y se suspende
//  Los tiempos se guardan en comun/Ajustes.qml y los aplica
//  niri/scripts/inactividad.sh (swayidle), que se relanza al cambiarlos.
//  También el perfil de energía, el mismo que en el centro de control.
// ============================================================================
import QtQuick
import qs.comun

Column {
    id: seccion
    spacing: 8

    // Botones de minutos: [5, 10...] y «Nunca» (0)
    function minutos(lista) {
        return lista.map(m => ({id: String(m), texto: m === 0 ? "Nunca" : m >= 60 ? (m / 60) + " h" : m + " min"}));
    }

    Titular { texto: "Perfil de energía"; width: parent.width }
    SelectorEnergia { width: parent.width }
    Interruptor {
        width: parent.width
        titulo: "No suspender"
        detalle: "Ni bloquear ni apagar la pantalla hasta que lo quites (como en el centro de control)"
        activo: Despierto.activo
        onCambiar: v => Despierto.activo = v
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Bloquear la pantalla"; width: parent.width }
    Opciones {
        width: parent.width
        opciones: seccion.minutos([2, 5, 10, 15, 30, 0])
        valor: String(Ajustes.bloquearMin)
        onElegir: id => Ajustes.ponerEnergia("bloquearMin", Number(id))
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Apagar la pantalla"; width: parent.width }
    Opciones {
        width: parent.width
        opciones: seccion.minutos([5, 10, 15, 30, 60, 0])
        valor: String(Ajustes.pantallaMin)
        onElegir: id => Ajustes.ponerEnergia("pantallaMin", Number(id))
    }

    Item { width: 1; height: 6 }
    Titular { texto: "Suspender"; width: parent.width }
    Opciones {
        width: parent.width
        opciones: seccion.minutos([15, 30, 60, 120, 0])
        valor: String(Ajustes.suspenderMin)
        onElegir: id => Ajustes.ponerEnergia("suspenderMin", Number(id))
    }
    Interruptor {
        width: parent.width
        visible: Ajustes.suspenderMin > 0
        titulo: "También enchufado"
        detalle: Ajustes.suspenderEnchufado ? "Suspende siempre, con batería o enchufado"
            : "Solo con batería: enchufado (o en un PC de sobremesa) no se suspende"
        activo: Ajustes.suspenderEnchufado
        onCambiar: v => Ajustes.ponerEnergia("suspenderEnchufado", v)
    }

    Item { width: 1; height: 4 }
    Texto {
        width: parent.width
        text: "Los tiempos cuentan desde la última vez que tocas el teclado o el ratón. Antes de suspender siempre se bloquea, y un vídeo a pantalla completa (o «No suspender») lo detiene todo."
        color: Tema.gris
        font.pixelSize: 11
        font.bold: false
        wrapMode: Text.Wrap
    }
}
