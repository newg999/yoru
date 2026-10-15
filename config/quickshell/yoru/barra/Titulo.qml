// ============================================================================
//  Ventana activa de esta pantalla: icono de la app (en blanco, ver
//  comun/Iconos.qml) y título. Sin ventanas, la isla desaparece.
//  Con la barra a la izquierda, solo el icono (el título, en la ayuda).
// ============================================================================
import QtQuick
import qs.comun

Isla {
    id: isla
    required property string salida
    property int maximo: 420       // píxeles; lo que no quepa se corta con "…"

    readonly property var ventana: Niri.ventanaEn(salida)

    relleno: 12
    espacio: 9

    // Ayuda: el título entero (si se ha cortado) y de qué app es
    ayuda: !ventana ? ""
        : (textoTitulo.truncated || vertical ? Tema.html(ventana.title) + "<br>" : "") + Tema.suave(Tema.html(ventana.app_id))

    Texto {
        visible: isla.ventana !== null
        text: Iconos.app(isla.ventana?.app_id)
        font.pixelSize: Tema.icono
        color: Tema.blanco
        height: Tema.altoBarra
    }

    Texto {
        id: textoTitulo
        text: isla.ventana?.title ?? ""
        visible: text !== "" && !isla.vertical
        font.bold: false
        elide: Text.ElideRight
        width: Math.min(implicitWidth, isla.maximo)
        height: Tema.altoBarra
    }
}
