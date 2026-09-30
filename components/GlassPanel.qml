import QtQuick
import QtQuick.Effects

// Arkasındaki videoyu bulanıklaştıran yarı saydam cam panel.
Item {
    id: glass

    property Item backgroundItem
    property real blurAmount: 0.8
    property int blurMax: 48
    property real radius: 18
    property color tint: Qt.rgba(0.10, 0.10, 0.13, 0.55)
    property color borderColor: Qt.rgba(1, 1, 1, 0.12)
    property real borderWidth: 1
    property bool shadowEnabled: true
    property real shadowSize: 32
    property color shadowColor: Qt.rgba(0, 0, 0, 0.45)
    default property alias content: inner.data

    property bool blockInput: true   // false: tıklamalar arkadaki alana geçer
    signal backgroundClicked()

    RectangularShadow {
        anchors.fill: parent
        visible: glass.shadowEnabled
        radius: glass.radius
        blur: glass.shadowSize
        spread: 0
        offset.y: glass.shadowSize * 0.25
        color: glass.shadowColor
    }

    ShaderEffectSource {
        id: snapshot
        anchors.fill: parent
        visible: false
        live: true
        hideSource: false
        sourceItem: glass.backgroundItem
        sourceRect: {
            // x/y/width/height bağımlılıkları: sallanma ve yeniden boyutlanmada güncellensin.
            var dep = glass.x + glass.y + glass.width + glass.height + (glass.parent ? glass.parent.x + glass.parent.y : 0)
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
        blurMax: glass.blurMax
        saturation: 0.1
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
        border.width: glass.borderWidth
    }

    // Panel içindeki tıklamalar arkadaki alana geçmesin.
    MouseArea {
        anchors.fill: parent
        enabled: glass.blockInput
        acceptedButtons: Qt.AllButtons
        onClicked: glass.backgroundClicked()
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
