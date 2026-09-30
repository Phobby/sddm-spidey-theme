import QtQuick
import QtQuick.Effects

// Round user avatar; falls back to the initial if the image can't be read.
Item {
    id: avatar
    property url source
    property string name: ""
    property color accent: "#e8363f"
    property string fontFamily: ""
    property bool selected: false
    property color ringColor: Qt.rgba(1, 1, 1, 0.55)
    property real ringWidth: 1.5

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.darker(avatar.accent, 1.6)
        visible: img.status !== Image.Ready
        Text {
            anchors.centerIn: parent
            text: avatar.name.length ? avatar.name.charAt(0).toUpperCase() : "?"
            color: "white"
            font.family: avatar.fontFamily
            font.weight: Font.Bold
            font.pixelSize: parent.height * 0.48
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: avatar.source
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    Item {
        id: circle
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: img.status === Image.Ready
        maskEnabled: true
        maskSource: circle
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    // Thin light ring (accent color when selected)
    Rectangle {
        anchors.fill: parent
        anchors.margins: -avatar.ringWidth
        radius: width / 2
        color: "transparent"
        border.width: avatar.ringWidth
        border.color: avatar.selected ? avatar.accent : avatar.ringColor
        Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }
}
