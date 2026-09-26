pragma Singleton

// ============================================================================
//  Iconos — icono (de la Nerd Font, en blanco) para cada app, por su app-id
//  Así el título de la barra lleva un icono nítido y a juego con el resto.
//  ¿Una app sale con el icono genérico? Mira su app-id con
//  "niri msg windows" y añade una línea aquí (la primera que coincida gana).
// ============================================================================
import QtQuick
import Quickshell

Singleton {
    readonly property var reglas: [
        [["telegram"], "󰔁"],   // Telegram
        [["discord", "vesktop", "webcord"], "󰙯"],   // Discord
        [["whatsapp", "zapzap"], "󰖣"],   // WhatsApp
        [["spotify"], "󰓇"],   // Spotify
        [["firefox", "librewolf", "zen"], "󰈹"],   // Firefox y derivados
        [["chrome", "chromium"], "󰊯"],   // Chrome / Chromium
        [["brave", "browser", "epiphany", "vivaldi"], "󰖟"],   // otros navegadores
        [["code", "codium", "zed"], "󰨞"],   // editores de código
        [["ghostty", "kitty", "konsole", "alacritty", "foot", "wezterm", "terminal", "ptyxis"], "󰆍"],   // terminales
        [["dolphin", "nautilus", "thunar", "nemo", "files"], "󰉋"],   // archivos
        [["steam", "lutris", "heroic", "bottles"], "󰓓"],   // juegos
        [["okular", "evince", "papers", "pdf"], "󰈦"],   // PDF
        [["writer"], "󰈬"],   // LibreOffice Writer
        [["kcalc", "calculator"], "󰃬"],   // calculadoras
        [["calc"], "󰈛"],   // LibreOffice Calc
        [["impress"], "󰈧"],   // LibreOffice Impress
        [["mpv", "vlc", "celluloid", "dragon", "haruna", "totem", "showtime"], "󰕧"],   // vídeo
        [["elisa", "rhythmbox", "amberol", "music"], "󰝚"],   // música
        [["gwenview", "loupe", "eog", "image"], "󰋩"],   // imágenes
        [["settings", "control-center", "systemsettings"], "󰒓"],   // ajustes
        [["discover", "software", "store"], "󰏗"],   // tiendas de apps
        [["kwrite", "kate", "gedit", "gnome-text-editor", "mousepad"], "󰷈"],   // editores de texto
        [["kmail", "thunderbird", "geary", "evolution", "mail"], "󰇮"],   // correo
    ]
    readonly property string generico: "󰣆"

    // siNo: el icono si ninguna regla coincide (por defecto, el genérico)
    function app(appId, siNo) {
        const id = (appId ?? "").toLowerCase();
        for (const [trozos, icono] of reglas)
            if (trozos.some(t => id.includes(t)))
                return icono;
        return siNo ?? generico;
    }
}
