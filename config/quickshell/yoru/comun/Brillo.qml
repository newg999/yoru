pragma Singleton

// ============================================================================
//  Brillo — brillo de las pantallas (portátil con brightnessctl, monitores
//  externos con ddcutil). Lo usa el centro de control y las teclas de brillo.
//
//    Brillo.pantallas       [{id, nombre, valor}]   valor de 0 a 1
//    Brillo.poner(id, v)    cambia una pantalla
//    Brillo.cambiar(0.1)    sube (o baja, con negativo) todas a la vez
//    Brillo.leer()          vuelve a mirar el brillo real (como mucho cada 10 min)
//
//  ddcutil tarda ~1 s por orden: los cambios seguidos (arrastrar la barra,
//  pulsar varias veces la tecla) se juntan y solo se manda el último.
//  Leer también es caro: ddcutil recorre los buses I2C de la gráfica y, con
//  NVIDIA, el ratón va a tirones mientras tanto. Por eso no se relee cada vez
//  que se abre el centro de control, solo si hace rato de la última lectura
//  (el brillo que ponemos nosotros ya lo sabemos).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: brillo

    property var pantallas: []
    property var _pendiente: ({})     // id → % que falta mandar

    property real _leidoEn: Date.now()   // el lector arranca solo al iniciar

    function leer() {
        if (lector.running || Date.now() - _leidoEn < 10 * 60 * 1000)
            return;
        _leidoEn = Date.now();
        lector.running = true;
    }

    function poner(id, valor) {
        const v = Math.max(0.01, Math.min(1, valor));
        pantallas = pantallas.map(p => p.id === id ? Object.assign({}, p, {valor: v}) : p);
        const pend = Object.assign({}, _pendiente);
        pend[id] = Math.round(v * 100);
        _pendiente = pend;
        espera.restart();
    }

    // Con las teclas: también avisa al OSD (Osd.qml)
    signal cambiadoConTecla()
    function cambiar(delta) {
        for (const p of pantallas)
            poner(p.id, Math.round((p.valor + delta) * 20) / 20);
        if (pantallas.length > 0)
            cambiadoConTecla();
    }

    // Manda el siguiente cambio pendiente (uno cada vez)
    function _mandar() {
        const ids = Object.keys(_pendiente);
        if (escritor.running || ids.length === 0)
            return;
        const id = ids[0];
        const pend = Object.assign({}, _pendiente);
        const pct = pend[id];
        delete pend[id];
        _pendiente = pend;
        escritor.command = [Quickshell.shellPath("scripts/brillo.sh"), "poner", id, String(pct)];
        escritor.running = true;
    }

    Timer {
        id: espera
        interval: 150
        onTriggered: brillo._mandar()
    }

    Process {
        id: escritor
        onExited: brillo._mandar()
    }

    Process {
        id: lector
        running: true
        command: [Quickshell.shellPath("scripts/brillo.sh"), "leer"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Mientras hay cambios sin mandar, manda lo que se ve en la barra
                if (Object.keys(brillo._pendiente).length > 0 || escritor.running)
                    return;
                brillo.pantallas = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [id, nombre, pct] = l.split("\t");
                    return {id, nombre, valor: Number(pct) / 100};
                });
            }
        }
    }
}
