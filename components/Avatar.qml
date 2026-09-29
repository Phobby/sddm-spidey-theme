import QtQuick
import QtQuick.Effects

// Yuvarlak kullanıcı avatarı; resim okunamazsa baş harf gösterir.
Item {
    id: avatar
    property url source
    property string name: ""
    property color accent: "#e8363f"
    property string fontFamily: ""
    property bool selected: false

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

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: avatar.accent
        opacity: avatar.selected ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
