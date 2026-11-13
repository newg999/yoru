pragma Singleton

// ============================================================================
//  Widgets — los del escritorio (barra/Escritorio.qml): cuáles salen, dónde,
//  de qué tamaño y su aspecto. También los iconos de archivos y accesos
//  directos (barra/IconosEscritorio.qml): si salen, su tamaño y su sitio. Se cambian en Ajustes › Escritorio o sobre el
//  propio escritorio en modo edición (clic derecho en un widget):
//    arrastrar = moverlo · rueda = su tamaño · × = quitarlo
//
//  Se guarda en ~/.local/state/yoru/widgets.json. Las posiciones van en
//  fracciones de la pantalla (0-1, la esquina de arriba a la izquierda del
//  widget): así valen en cualquier resolución. Sin posición guardada, el
//  widget va en la columna de la derecha (como al principio).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: widgets

    // Todos los que hay, en el orden de la columna de la derecha
    readonly property var catalogo: [
        {id: "hora", nombre: "Hora", icono: "󰥔", detalle: "La hora en grande (y la fecha, si quieres)"},
        {id: "agujas", nombre: "Reloj de agujas", icono: "󰅐", detalle: "Un reloj analógico"},
        {id: "disco", nombre: "Disco", icono: "󰋊", detalle: "Lo ocupado del disco del sistema", par: true},
        {id: "temp", nombre: "Temperatura", icono: "󰔏", detalle: "La de la CPU", par: true},
        {id: "ram", nombre: "Memoria", icono: "󰍛", detalle: "La RAM en uso", par: true},
        {id: "cpu", nombre: "CPU", icono: "󰘚", detalle: "El uso del procesador", par: true},
        {id: "bateria", nombre: "Batería", icono: "󰁹", detalle: "La carga (en portátiles)", par: true},
        {id: "red", nombre: "Red", icono: "󰖩", detalle: "La conexión y lo que baja y sube", par: true},
        {id: "tiempo", nombre: "El tiempo", icono: "󰖐", detalle: "Temperatura, cielo y los próximos días"},
        {id: "calendario", nombre: "Calendario", icono: "󰃭", detalle: "El mes, con hoy marcado"},
        {id: "musica", nombre: "Música", icono: "󰝚", detalle: "Lo que suena, con sus botones (solo con algo sonando)"}
    ].filter(w => w.id !== "bateria" || (UPower.displayDevice?.isLaptopBattery ?? false))

    function info(id) {
        return catalogo.find(w => w.id === id) ?? null;
    }

    // Modo edición (no se guarda): los widgets se mueven y cambian de tamaño
    // (qs -c yoru ipc call widgets editar)
    property bool editando: false
    IpcHandler {
        target: "widgets"
        function editar(): void { widgets.editando = !widgets.editando; }
    }

    // ------------------------------------------------------------ Datos
    readonly property var activos: datos.activos
    readonly property real escala: datos.escala
    readonly property real opacidad: datos.opacidad
    readonly property bool segundos: datos.segundos
    readonly property bool fecha: datos.fecha
    // Iconos del escritorio (barra/IconosEscritorio.qml): lo de ~/Escritorio
    readonly property bool iconos: datos.iconos
    readonly property real tamIconos: datos.tamIconos
    readonly property var sitiosIconos: datos.sitiosIconos

    function activo(id) {
        return datos.activos.includes(id);
    }
    function alternar(id, si) {
        const a = datos.activos.filter(x => x !== id);
        if (si ?? !activo(id))
            a.push(id);
        // En el orden del catálogo (el de la columna)
        datos.activos = catalogo.map(w => w.id).filter(x => a.includes(x));
    }
    function sitio(id) {
        return datos.sitios[id] ?? null;
    }
    function mover(id, x, y) {
        const s = Object.assign({}, datos.sitios);
        s[id] = {x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y))};
        datos.sitios = s;
    }
    function tam(id) {
        return datos.tamanos[id] ?? 1;
    }
    function redimensionar(id, t) {
        const s = Object.assign({}, datos.tamanos);
        s[id] = Math.round(Math.max(0.6, Math.min(2.2, t)) * 100) / 100;
        datos.tamanos = s;
    }
    function ponerEscala(v) { datos.escala = Math.round(Math.max(0.6, Math.min(2, v)) * 100) / 100; }
    function ponerOpacidad(v) { datos.opacidad = Math.round(Math.max(0, Math.min(1, v)) * 100) / 100; }
    function ponerSegundos(v) { datos.segundos = v; }
    function ponerFecha(v) { datos.fecha = v; }
    function ponerIconos(v) { datos.iconos = v; }
    function ponerTamIconos(v) { datos.tamIconos = Math.round(Math.max(0.7, Math.min(1.6, v)) * 100) / 100; }
    // nombre del archivo → [columna, fila]
    function colocarIconos(sitios) { datos.sitiosIconos = sitios; }
    function ordenarIconos() { datos.sitiosIconos = {}; }

    // Todo a su sitio de la columna y a su tamaño
    function restablecer() {
        datos.sitios = {};
        datos.tamanos = {};
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/yoru/widgets.json"
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: datos
            // Los de siempre: la hora, las cuatro tarjetas y la música
            property var activos: ["hora", "disco", "temp", "ram", "cpu", "musica"]
            property var sitios: ({})       // id → {x, y} (0-1)
            property var tamanos: ({})      // id → 0.6-2.2
            property real escala: 1         // todos a la vez
            property real opacidad: 0.8     // el fondo de las tarjetas
            property bool segundos: true    // en la hora
            property bool fecha: false      // bajo la hora
            property bool iconos: true      // archivos y accesos directos
            property real tamIconos: 1
            property var sitiosIconos: ({}) // nombre → [columna, fila]
        }
    }
}
