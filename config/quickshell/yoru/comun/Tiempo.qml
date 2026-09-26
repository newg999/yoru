pragma Singleton

// ============================================================================
//  Tiempo — el clima de donde vives (Open-Meteo: gratis y sin registro)
//
//  El lugar se lee de lugar.json (junto a shell.qml; no se sube al repo):
//      {"nombre": "Madrid", "latitud": 40.4168, "longitud": -3.7038}
//  Si no existe, se adivina por tu IP (ip-api.com).
//  Se actualiza cada 15 minutos.
// ============================================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: tiempo

    property string lugar: ""
    property real latitud: NaN
    property real longitud: NaN

    property bool listo: false
    property int temperatura: 0
    property int sensacion: 0
    property int humedad: 0
    property int viento: 0          // km/h
    property int codigo: 0          // código WMO del estado del cielo
    property bool deDia: true
    property string amanecer: ""    // "07:52"
    property string atardecer: ""
    property var horas: []          // próximas 12 h: [{hora, temp, codigo, dia}]
    property var dias: []           // 7 días: [{fecha, max, min, codigo, lluvia}]

    readonly property string icono: iconoDe(codigo, deDia)
    readonly property string descripcion: descripcionDe(codigo)

    // Códigos WMO → icono (Nerd Font) y texto
    function iconoDe(c, dia) {
        if (c === 0) return dia ? "󰖙" : "󰖔";
        if (c <= 2) return dia ? "󰖕" : "󰼱";
        if (c === 3) return "󰖐";
        if (c <= 48) return "󰖑";
        if (c <= 57) return "󰖗";
        if (c <= 67) return "󰖖";
        if (c <= 77) return "󰖘";
        if (c <= 82) return "󰖖";
        if (c <= 86) return "󰖘";
        return "󰖓";
    }
    function descripcionDe(c) {
        if (c === 0) return "Despejado";
        if (c === 1) return "Casi despejado";
        if (c === 2) return "Parcialmente nublado";
        if (c === 3) return "Nublado";
        if (c <= 48) return "Niebla";
        if (c <= 57) return "Llovizna";
        if (c <= 67) return "Lluvia";
        if (c <= 77) return "Nieve";
        if (c <= 82) return "Chubascos";
        if (c <= 86) return "Chubascos de nieve";
        return "Tormenta";
    }

    // ---------------------------------------------------------------- Lugar
    FileView {
        id: archivoLugar
        path: Quickshell.shellPath("lugar.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const l = JSON.parse(text());
                tiempo.lugar = l.nombre ?? "";
                tiempo.latitud = l.latitud;
                tiempo.longitud = l.longitud;
                tiempo.actualizar();
            } catch (e) {
                console.warn("lugar.json no es válido:", e);
            }
        }
        onLoadFailed: tiempo._porIp()
    }

    function _pedir(url, alLlegar) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    alLlegar(JSON.parse(xhr.responseText));
                } catch (e) {
                    console.warn("Tiempo:", e);
                }
            } else {
                reintentar.start();
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function _porIp() {
        _pedir("http://ip-api.com/json/?fields=city,lat,lon", r => {
            tiempo.lugar = r.city;
            tiempo.latitud = r.lat;
            tiempo.longitud = r.lon;
            tiempo.actualizar();
        });
    }

    // --------------------------------------------------------------- Clima
    function actualizar() {
        if (isNaN(latitud))
            return;
        const url = "https://api.open-meteo.com/v1/forecast"
            + `?latitude=${latitud}&longitude=${longitud}&timezone=auto&forecast_days=7`
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&hourly=temperature_2m,weather_code,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max";
        _pedir(url, r => {
            const a = r.current;
            temperatura = Math.round(a.temperature_2m);
            sensacion = Math.round(a.apparent_temperature);
            humedad = a.relative_humidity_2m;
            viento = Math.round(a.wind_speed_10m);
            codigo = a.weather_code;
            deDia = a.is_day === 1;
            amanecer = r.daily.sunrise[0].slice(11, 16);
            atardecer = r.daily.sunset[0].slice(11, 16);

            // Próximas 12 horas desde la hora actual
            const ahora = a.time.slice(0, 13);
            const desde = Math.max(0, r.hourly.time.findIndex(t => t.slice(0, 13) === ahora));
            const hs = [];
            for (let i = desde; i < Math.min(desde + 12, r.hourly.time.length); i++)
                hs.push({
                    hora: r.hourly.time[i].slice(11, 16),
                    temp: Math.round(r.hourly.temperature_2m[i]),
                    codigo: r.hourly.weather_code[i],
                    dia: r.hourly.is_day[i] === 1
                });
            horas = hs;

            dias = r.daily.time.map((f, i) => ({
                fecha: f,
                max: Math.round(r.daily.temperature_2m_max[i]),
                min: Math.round(r.daily.temperature_2m_min[i]),
                codigo: r.daily.weather_code[i],
                lluvia: r.daily.precipitation_probability_max[i] ?? 0
            }));
            listo = true;
        });
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: tiempo.actualizar()
    }
    // Sin conexión (p. ej. al arrancar antes que el wifi): se prueba en 1 min
    Timer {
        id: reintentar
        interval: 60 * 1000
        onTriggered: isNaN(tiempo.latitud) ? tiempo._porIp() : tiempo.actualizar()
    }
}
