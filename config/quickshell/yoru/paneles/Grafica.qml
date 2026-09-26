// ============================================================================
//  Grafica — historial en línea (CPU, memoria, red...), de izquierda a derecha
//  valores: una o dos listas de números entre 0 y 1 (la segunda, más tenue)
// ============================================================================
import QtQuick
import qs.comun

Canvas {
    id: grafica

    property var valores: []          // línea principal
    property var valores2: []         // segunda línea (opcional)
    property int puntos: 60           // cuántos valores caben a lo ancho

    onValoresChanged: requestPaint()
    onValores2Changed: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function linea(ctx, lista, trazo, relleno) {
        if (lista.length < 2)
            return;
        const paso = width / (puntos - 1);
        const x0 = width - (lista.length - 1) * paso;
        const y = v => height - 2 - Math.max(0, Math.min(1, v)) * (height - 4);

        ctx.beginPath();
        ctx.moveTo(x0, y(lista[0]));
        for (let i = 1; i < lista.length; i++)
            ctx.lineTo(x0 + i * paso, y(lista[i]));
        ctx.strokeStyle = trazo;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.stroke();

        // Relleno degradado bajo la línea
        ctx.lineTo(width, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        const degradado = ctx.createLinearGradient(0, 0, 0, height);
        degradado.addColorStop(0, relleno);
        degradado.addColorStop(1, "transparent");
        ctx.fillStyle = degradado;
        ctx.fill();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        // Rejilla suave: 25 %, 50 %, 75 %
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06);
        ctx.lineWidth = 1;
        for (const f of [0.25, 0.5, 0.75]) {
            ctx.beginPath();
            ctx.moveTo(0, Math.round(height * f) + 0.5);
            ctx.lineTo(width, Math.round(height * f) + 0.5);
            ctx.stroke();
        }

        linea(ctx, valores2, Qt.rgba(1, 1, 1, 0.45), Qt.rgba(1, 1, 1, 0.08));
        linea(ctx, valores, Tema.blanco, Qt.rgba(1, 1, 1, 0.22));
    }
}
