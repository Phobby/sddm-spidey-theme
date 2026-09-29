import QtQuick

// Yuvarlak ikon butonu (güç butonları, oklar).
Item {
    id: btn
    property url icon
    property string label: ""
    property color accent: "#e8363f"
    property string fontFamily: ""
    property real iconScale: 0.46
    signal clicked()

    implicitWidth: 44
    implicitHeight: 44 + (label.length ? labelText.height + 4 : 0)
    activeFocusOnTab: true

    Rectangle {
        id: bg
        width: parent.width
        height: width
        radius: width / 2
        color: area.pressed ? Qt.rgba(1, 1, 1, 0.28)
             : (area.containsMouse || btn.activeFocus) ? Qt.rgba(1, 1, 1, 0.16)
             : Qt.rgba(1, 1, 1, 0.06)
        border.color: btn.activeFocus ? btn.accent : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Image {
            anchors.centerIn: parent
            width: parent.width * btn.iconScale
            height: width
            source: btn.icon
            sourceSize: Qt.size(width * 2, height * 2)
        }
    }

    Text {
        id: labelText
        visible: btn.label.length > 0
        anchors.top: bg.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: bg.horizontalCenter
        text: btn.label
        color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.95 : 0.6)
        font.family: btn.fontFamily
        font.pixelSize: bg.width * 0.3
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: area
        anchors.fill: bg
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
    Keys.onReturnPressed: btn.clicked()
    Keys.onEnterPressed: btn.clicked()
    Keys.onSpacePressed: btn.clicked()
}
