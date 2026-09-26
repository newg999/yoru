// Lista con scroll que crece hasta "maximo" píxeles de alto
import QtQuick

ListView {
    property int maximo: 300

    implicitHeight: Math.min(contentHeight, maximo)
    spacing: 2
    clip: true
    interactive: contentHeight > maximo
    boundsBehavior: Flickable.StopAtBounds
}
