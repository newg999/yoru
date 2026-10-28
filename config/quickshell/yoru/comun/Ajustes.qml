pragma Singleton

// ============================================================================
//  Ajustes — lo que se cambia desde la app de Ajustes (Mod+Alt+T)
//  Se guardan en ~/.local/state/yoru/ajustes.json: fuera del repo, como los
//  favoritos del dock. Si lo editas a mano, se aplica al guardar.
//  Lo que falte en el archivo se queda con el valor de aquí.
//  Los colores no van aquí: son cosa de «yoru tema» (ver comun/Tema.qml).
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ajustes

    // ------------------------------------------------------- Barra y dock
    property alias barra: datos.barra                 // "arriba" · "izquierda" (islas) · "minimalista" · "dock"
    property alias dock: datos.dock                   // "overview" · "siempre" · "nunca"
    property alias islaTitulo: datos.islaTitulo
    property alias ventanas: datos.ventanas           // "activa" (icono y título) · "abiertas" (todas)
    property alias islaMusica: datos.islaMusica
    property alias islaClima: datos.islaClima
    property alias islaRecursos: datos.islaRecursos
    property alias islaBandeja: datos.islaBandeja

    // ------------------------------------------------------------ Aspecto
    property alias radio: datos.radio                 // esquinas de islas y paneles (px)
    property alias radioVentanas: datos.radioVentanas // esquinas de las ventanas (px, ver abajo)
    property alias ventanasAPares: datos.ventanasAPares // dos ventanas que llenan la pantalla: al agrandar una, la otra se encoge (Niri.qml)
    property alias opacidadIslas: datos.opacidadIslas
    property alias opacidadPaneles: datos.opacidadPaneles
    property alias letra: datos.letra                 // texto de la barra (px)
    property alias fuente: datos.fuente               // tipo de letra de todo Yoru
    property alias luzNocturna: datos.luzNocturna     // "apagada" · "auto" · "siempre"
    property alias calidez: datos.calidez             // K de la luz nocturna
    property alias desenfoque: datos.desenfoque       // fondo borroso tras las islas
    property alias bordes: datos.bordes               // línea alrededor de islas y paneles
    property alias animaciones: datos.animaciones

    // ------------------------------------------------- Energía (0 = nunca)
    property alias bloquearMin: datos.bloquearMin       // bloquear la pantalla
    property alias pantallaMin: datos.pantallaMin       // apagar la pantalla
    property alias suspenderMin: datos.suspenderMin
    property alias suspenderEnchufado: datos.suspenderEnchufado  // si no, solo con batería

    // ------------------------------------------------------ Fecha y hora
    property alias reloj24: datos.reloj24               // 14:30 · 2:30 p. m.
    property alias relojSegundos: datos.relojSegundos   // segundos en el reloj de la barra

    // ----------------------------------------------------- Notificaciones
    property alias avisosSegundos: datos.avisosSegundos // lo que dura un aviso en pantalla
    property alias avisosLado: datos.avisosLado         // "derecha" · "centro"
    property alias avisosSonido: datos.avisosSonido     // un «tin» al llegar
    property alias appsAvisos: datos.appsAvisos         // las apps que han avisado alguna vez
    property alias silenciadas: datos.silenciadas       // esas, sin aviso ni sonido (sí en el panel)

    // ------------------------------------------- Grabar la pantalla (Mod+Alt+R)
    property alias grabarSonido: datos.grabarSonido     // lo que suena
    property alias grabarMicro: datos.grabarMicro       // el micrófono (en vez de lo que suena)

    readonly property bool vertical: barra === "izquierda"
    // Islas arriba: en píldoras con fichas dentro y widgets en el escritorio
    // (barra/BarraIslas.qml y barra/Escritorio.qml)
    readonly property bool pildoras: barra === "arriba"
    // La barra de píldoras: las islas arriba, o la minimalista (la misma,
    // sobre una franja entera de lado a lado)
    readonly property bool conPildoras: pildoras || barra === "minimalista"
    readonly property bool minimalista: barra === "minimalista"
    // Todo recto: con la minimalista
    readonly property bool recto: minimalista
    // Estilo dock: el dock de config/quickshell/yoru-dock (un port de LeyzS
    // QsDock), que la barra arranca aparte (shell.qml)
    readonly property bool estiloDock: barra === "dock"
    // Minimalista y dock: sin islas
    readonly property bool centrada: minimalista || estiloDock

    // Su lado y si se esconde los guarda el propio dock; aquí se leen y se
    // cambian (Ajustes › Barra y dock)
    readonly property string carpetaDock: Quickshell.env("HOME") + "/.local/share/quickshell"
    property string dockLado: "izquierda"     // dock-yon: «dikey» (izquierda) o «yatay» (abajo)
    property bool dockEsconder: true          // dock-mod: «gizli» (se esconde) o «sabit»
    FileView {
        path: ajustes.carpetaDock + "/dock-yon"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: ajustes.dockLado = text().trim() === "yatay" ? "abajo" : "izquierda"
    }
    FileView {
        id: archivoModoDock
        path: ajustes.carpetaDock + "/dock-mod"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: ajustes.dockEsconder = text().trim() !== "sabit"
    }
    // Cambiar de lado: el dock lo hace con su animación (la «serpiente»)
    function ponerDockLado(lado) {
        if (lado !== dockLado)
            Quickshell.execDetached(["qs", "-c", "yoru-dock", "ipc", "call", "dock", "yon"]);
    }
    function ponerDockEsconder(si) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\n" "$2" > "$1/dock-mod"',
            "sh", carpetaDock, si ? "gizli" : "sabit"]);
    }

    // Vuelve a dejar el aspecto (no la barra ni el dock) como al principio
    function restablecerAspecto() {
        datos.radio = 10;
        datos.radioVentanas = 10;
        datos.opacidadIslas = 0.45;
        datos.opacidadPaneles = 0.90;
        datos.letra = 13;
        datos.fuente = "JetBrainsMono Nerd Font";
        datos.desenfoque = true;
        datos.bordes = true;
        datos.animaciones = true;
    }

    // Cambia un tiempo de Energía y, un momento después (ya guardado en el
    // archivo), vuelve a lanzar swayidle con los tiempos nuevos
    function ponerEnergia(clave, valor) {
        datos[clave] = valor;
        relanzarInactividad.restart();
    }
    Timer {
        id: relanzarInactividad
        interval: 600
        onTriggered: Quickshell.execDetached(["niri", "msg", "action", "spawn-sh", "--",
            "~/.config/niri/scripts/inactividad.sh"])
    }

    // ------------------------------- Esquinas y huecos de las ventanas
    // Los dibuja niri: se le escribe este archivo, que config/niri/config.kdl
    // incluye después de rules.kdl (gana lo último). Con la barra
    // minimalista, sin huecos entre ventanas ni con los bordes y sin
    // esquinas redondas (no se pueden cambiar: todo recto, como ella)
    readonly property string niriVentanas: `// Generado por la barra (Ajustes → Aspecto y Barra). No lo edites: se sobrescribe.
window-rule {
    geometry-corner-radius ${datos.barra === "minimalista" ? 0 : datos.radioVentanas}
    clip-to-geometry true
}
` + (datos.barra === "minimalista" ? `layout {
    gaps 0
}
` : "")
    FileView {
        id: archivoVentanas
        path: Quickshell.env("HOME") + "/.local/state/yoru/niri-ventanas.kdl"
        printErrors: false
        onLoaded: ajustes.escribirVentanas()
        onLoadFailed: ajustes.escribirVentanas()
    }
    property bool _ventanasLeido: false   // hasta leerlo no se sabe si cambia
    // Al arrancar solo se escribe si cambia; al mover el regulador, siempre
    // (text() puede devolver aún el contenido anterior)
    function escribirVentanas(siempre) {
        _ventanasLeido = true;
        if (!siempre && archivoVentanas.text() === niriVentanas)
            return;
        archivoVentanas.setText(niriVentanas);
        // niri no vigila el archivo si no existía al cargar su config
        recargarNiri.restart();
    }
    // Un momento después: al avisar del cambio, niriVentanas aún no está al día
    onRadioVentanasChanged: if (_ventanasLeido) Qt.callLater(escribirVentanas, true)
    onBarraChanged: if (_ventanasLeido) Qt.callLater(escribirVentanas, true)
    Timer {
        id: recargarNiri
        interval: 150
        onTriggered: Quickshell.execDetached(["niri", "msg", "action", "load-config-file"])
    }

    // Ya se ha leído ajustes.json: hasta entonces, todo vale lo de serie (la
    // barra «arriba»...). Lo que actúa fuera (arrancar el dock) espera a esto
    property bool leido: false
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/yoru/ajustes.json"
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: ajustes.leido = true
        // Cualquier cambio desde el panel se guarda al momento
        onAdapterUpdated: writeAdapter()
        // Primera vez: se crea con los valores de aquí
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            ajustes.leido = true;
        }

        JsonAdapter {
            id: datos
            property string barra: "arriba"
            property string dock: "overview"
            property bool islaTitulo: true
            property string ventanas: "activa"
            property bool islaMusica: true
            property bool islaClima: true
            property bool islaRecursos: true
            property bool islaBandeja: true

            property int radio: 10
            property int radioVentanas: 10
            property bool ventanasAPares: true
            property real opacidadIslas: 0.45
            property real opacidadPaneles: 0.90
            property int letra: 13
            property string fuente: "JetBrainsMono Nerd Font"
            property string luzNocturna: "apagada"
            property int calidez: 4000
            property bool desenfoque: true
            property bool bordes: true
            property bool animaciones: true

            property int bloquearMin: 5
            property int pantallaMin: 10
            property int suspenderMin: 15
            property bool suspenderEnchufado: false
            property bool reloj24: true
            property bool relojSegundos: false

            property int avisosSegundos: 5
            property string avisosLado: "derecha"
            property bool avisosSonido: false
            property var appsAvisos: []
            property var silenciadas: []

            property bool grabarSonido: true
            property bool grabarMicro: false
        }
    }
}
