// ============================================================================
//  Redes wifi: la conectada primero, luego las guardadas y el resto por señal.
//    Clic en una red = conectar (si es nueva y tiene candado, pide la contraseña)
//    En la conectada: 󰖪 desconectar · 󰆴 olvidar
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.comun

Column {
    id: seccion

    property bool activa: false        // la lista está a la vista
    spacing: 4

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var redes: {
        if (!wifi)
            return [];
        // La misma red puede salir varias veces (varios puntos de acceso)
        const vistas = new Map();
        for (const r of wifi.networks.values) {
            if (!r.name)
                continue;
            const previa = vistas.get(r.name);
            if (!previa || r.connected || (!previa.connected && r.signalStrength > previa.signalStrength))
                vistas.set(r.name, r);
        }
        return [...vistas.values()].sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }

    property string pidiendo: ""       // red a la que se está escribiendo la contraseña

    // Buscar redes solo mientras se ve la lista (gasta batería)
    Binding {
        when: seccion.wifi !== null
        target: seccion.wifi
        property: "scannerEnabled"
        value: seccion.activa && Networking.wifiEnabled
    }
    onActivaChanged: if (!activa) pidiendo = ""

    function segura(red) {
        return red.security !== WifiSecurityType.Open && red.security !== WifiSecurityType.Owe;
    }
    function senal(red) {
        return ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(red.signalStrength * 5))];
    }

    Titular {
        width: parent.width
        texto: "Redes wifi"

        BotonIcono {
            icono: "󰑐"
            visible: Networking.wifiEnabled
            onClic: {
                // Apagar y encender el escáner = buscar de nuevo
                seccion.wifi.scannerEnabled = false;
                seccion.wifi.scannerEnabled = true;
            }
        }
        BotonIcono {
            icono: "󰒓"
            onClic: {
                Paneles.cerrar();
                Quickshell.execDetached(["nm-connection-editor"]);
            }
        }
    }

    Texto {
        visible: !Networking.wifiEnabled || seccion.redes.length === 0
        width: parent.width
        height: 44
        horizontalAlignment: Text.AlignHCenter
        font.bold: false
        font.pixelSize: 12
        color: Tema.gris
        text: !Networking.wifiEnabled ? "El wifi está apagado" : "Buscando redes…"
    }

    Lista {
        width: parent.width
        visible: Networking.wifiEnabled
        model: seccion.redes

        delegate: Column {
            id: elemento
            required property var modelData
            readonly property var red: modelData
            readonly property bool escribiendo: seccion.pidiendo === red.name
            width: ListView.view.width
            spacing: 4

            Connections {
                target: elemento.red
                // Contraseña incorrecta o que falta: se pide otra vez
                function onConnectionFailed(motivo) {
                    if (seccion.segura(elemento.red))
                        seccion.pidiendo = elemento.red.name;
                }
            }

            Fila {
                width: parent.width
                icono: seccion.senal(elemento.red)
                titulo: elemento.red.name
                seleccionada: elemento.red.connected
                ocupada: elemento.red.stateChanging
                detalle: elemento.red.connected ? "Conectada"
                    : elemento.red.stateChanging ? "Conectando…"
                    : elemento.red.known ? "Guardada" : ""
                onClic: {
                    const red = elemento.red;
                    if (red.connected)
                        return;
                    if (red.known || !seccion.segura(red))
                        red.connect();
                    else
                        seccion.pidiendo = elemento.escribiendo ? "" : red.name;
                }

                Texto {
                    visible: seccion.segura(elemento.red) && !elemento.red.connected
                    text: "󰌾"
                    font.pixelSize: 13
                    color: Tema.gris
                    height: 30
                    rightPadding: 8
                }
                BotonIcono {
                    visible: elemento.red.connected
                    icono: "󰖪"
                    colorIcono: Tema.oscuro
                    onClic: elemento.red.disconnect()
                }
                BotonIcono {
                    visible: elemento.red.known
                    icono: "󰆴"
                    colorIcono: elemento.red.connected ? Tema.oscuro : Tema.gris
                    onClic: elemento.red.forget()
                }
            }

            // Contraseña
            Rectangle {
                visible: elemento.escribiendo
                width: parent.width
                height: 40
                radius: 10
                color: Tema.caja
                border.width: 1
                border.color: clave.activeFocus ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.1)

                TextInput {
                    id: clave
                    anchors { fill: parent; leftMargin: 14; rightMargin: 44 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: verClave.checked ? TextInput.Normal : TextInput.Password
                    color: Tema.texto
                    selectionColor: Qt.rgba(1, 1, 1, 0.3)
                    font.family: Tema.fuente
                    font.pixelSize: 13
                    clip: true
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: {
                        if (text.length === 0)
                            return;
                        elemento.red.connectWithPsk(text);
                        seccion.pidiendo = "";
                    }
                    Keys.onEscapePressed: seccion.pidiendo = ""

                    Texto {
                        visible: clave.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Contraseña (Enter para conectar)"
                        font.bold: false
                        font.pixelSize: 12
                        color: Tema.gris
                    }
                }

                BotonIcono {
                    id: verClave
                    property bool checked: false
                    anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                    icono: checked ? "󰈈" : "󰈉"
                    onClic: checked = !checked
                }
            }
        }
    }
}
