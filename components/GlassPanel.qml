import QtQuick
import QtQuick.Effects

// Arkasındaki videoyu bulanıklaştıran yarı saydam cam panel.
Item {
    id: glass

    property Item backgroundItem
    property real blurAmount: 0.7
    property real radius: 18
    property color tint: Qt.rgba(0.06, 0.04, 0.12, 0.38)
    property color borderColor: Qt.rgba(1, 1, 1, 0.14)
    default property alias content: inner.data

    ShaderEffectSource {
        id: snapshot
        anchors.fill: parent
        visible: false
        live: true
        hideSource: false
        sourceItem: glass.backgroundItem
        sourceRect: {
            // x/y/width/height bağımlılıkları: sallanma ve yeniden boyutlanmada güncellensin.
            var dep = glass.x + glass.y + glass.width + glass.height + (glass.parent ? glass.parent.x : 0)
            if (!glass.backgroundItem)
                return Qt.rect(0, 0, 0, 0)
            var p = glass.mapToItem(glass.backgroundItem, 0, 0)
            return Qt.rect(p.x, p.y, glass.width, glass.height)
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: glass.radius
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: snapshot
        autoPaddingEnabled: false
        blurEnabled: glass.blurAmount > 0
        blur: glass.blurAmount
        blurMax: 64
        saturation: 0.15
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: glass.tint
        border.color: glass.borderColor
        border.width: 1
    }

    // Panel içindeki tıklamalar arkadaki "zıpla" alanına geçmesin.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
