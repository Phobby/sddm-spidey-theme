import QtQuick

// Yuvarlak ikon butonu (güç butonları, oklar).
Item {
    id: btn
    property url icon
    property string label: ""
    property string tooltip: ""
    property color accent: "#e8363f"
    property string fontFamily: ""
    property real iconScale: 0.46
    signal clicked()

    implicitWidth: 44
    implicitHeight: 44 + (label.length ? labelText.height + 4 : 0)
    activeFocusOnTab: true

    readonly property bool hovered: area.containsMouse
    property bool highlight: false      // vurgu renginde, daha belirgin stil

    // Hover parıltısı
    Rectangle {
        anchors.centerIn: bg
        width: bg.width * 1.24
        height: width
        radius: width / 2
        color: "transparent"
        border.width: bg.width * 0.08
        border.color: Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, 0.35)
        opacity: btn.hovered ? 1 : 0
        scale: bg.scale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: bg
        width: parent.width
        height: width
        radius: width / 2
        scale: area.pressed ? 0.94 : btn.hovered ? 1.1 : 1
        color: btn.highlight
             ? Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, area.pressed ? 0.45 : btn.hovered ? 0.34 : 0.2)
             : area.pressed ? Qt.rgba(1, 1, 1, 0.28)
             : (btn.hovered || btn.activeFocus) ? Qt.rgba(1, 1, 1, 0.18)
             : Qt.rgba(1, 1, 1, 0.06)
        border.color: btn.highlight ? Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, btn.hovered ? 0.95 : 0.6)
                    : (btn.activeFocus || btn.hovered) ? Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, 0.7)
                    : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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

    Rectangle {
        id: tip
        anchors.bottom: bg.top
        anchors.bottomMargin: bg.width * 0.18
        anchors.horizontalCenter: bg.horizontalCenter
        width: tipText.implicitWidth + bg.width * 0.4
        height: tipText.implicitHeight + bg.width * 0.18
        radius: height / 2
        color: Qt.rgba(0.10, 0.10, 0.13, 0.85)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        visible: opacity > 0
        opacity: btn.tooltip.length > 0 && area.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Text {
            id: tipText
            anchors.centerIn: parent
            text: btn.tooltip
            color: "white"
            font.family: btn.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: bg.width * 0.28
        }
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
