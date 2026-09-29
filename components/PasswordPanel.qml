import QtQuick

// PHONE durumundaki şifre kutusu.
Item {
    id: root

    property Item backgroundItem
    property real blurAmount: 0.7
    property real s: 1
    property color accent: "#e8363f"
    property string fontFamily: ""
    property string userName: ""
    property string userRealName: ""
    property url userIcon
    property string sessionName: ""
    property bool busy: false
    property string errorText: ""

    signal submitted(string password)

    implicitHeight: glass.height

    function focusField() { input.forceActiveFocus() }
    function insertText(s) { if (!busy) input.insert(input.cursorPosition, s) }
    function clear() { input.text = ""; errorText = "" }
    function fail(msg) {
        busy = false
        replyTimeout.stop()
        input.text = ""
        errorText = msg
        shake.restart()
        input.forceActiveFocus()
    }
    function _submit() {
        if (busy) return
        busy = true
        errorText = ""
        replyTimeout.restart()
        root.submitted(input.text)
    }
    onBusyChanged: if (!busy) replyTimeout.stop()

    // Daemon yanıt vermezse (ör. --test-mode) kutu kilitli kalmasın.
    Timer {
        id: replyTimeout
        interval: 15000
        onTriggered: root.fail("Giriş yanıtı alınamadı")
    }

    property real shakeOffset: 0
    SequentialAnimation {
        id: shake
        loops: 1
        NumberAnimation { target: root; property: "shakeOffset"; to: -18 * root.s; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 16 * root.s; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -12 * root.s; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 8 * root.s; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -4 * root.s; duration: 55; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }

    GlassPanel {
        id: glass
        x: root.shakeOffset
        width: root.width
        height: col.implicitHeight + 2 * col.anchors.margins
        radius: 20 * root.s
        backgroundItem: root.backgroundItem
        blurAmount: root.blurAmount

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 26 * root.s
            spacing: 18 * root.s

            Row {
                spacing: 14 * root.s
                Avatar {
                    width: 54 * root.s
                    height: width
                    source: root.userIcon
                    name: root.userRealName
                    accent: root.accent
                    fontFamily: root.fontFamily
                    selected: true
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.userRealName
                        color: "white"
                        font.family: root.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 24 * root.s
                    }
                    Text {
                        text: root.sessionName
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: root.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: 14 * root.s
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 10 * root.s

                Rectangle {
                    id: field
                    width: parent.width - loginBtn.width - parent.spacing
                    height: 48 * root.s
                    radius: 10 * root.s
                    color: Qt.rgba(0, 0, 0, 0.30)
                    border.width: input.activeFocus ? 2 : 1
                    border.color: input.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.15)

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 16 * root.s
                        anchors.rightMargin: 16 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        passwordMaskDelay: 0
                        color: "white"
                        selectionColor: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 20 * root.s
                        font.letterSpacing: 2 * root.s
                        enabled: !root.busy
                        clip: true
                        onAccepted: root._submit()
                    }
                    Text {
                        anchors.fill: input
                        verticalAlignment: Text.AlignVCenter
                        visible: input.text.length === 0
                        text: "Şifre"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.family: root.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: 19 * root.s
                    }
                }

                Rectangle {
                    id: loginBtn
                    width: 48 * root.s
                    height: width
                    radius: 10 * root.s
                    color: btnArea.pressed ? Qt.darker(root.accent, 1.3)
                         : btnArea.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent
                    opacity: root.busy ? 0.5 : 1
                    Image {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        source: Qt.resolvedUrl("../assets/icons/arrow-right.svg")
                        sourceSize: Qt.size(width * 2, height * 2)
                    }
                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._submit()
                    }
                }
            }

            Item {
                width: parent.width
                height: 18 * root.s
                Text {
                    anchors.left: parent.left
                    text: root.errorText
                    color: Qt.lighter(root.accent, 1.3)
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 15 * root.s
                }
                Text {
                    anchors.right: parent.right
                    visible: keyboard.capsLock
                    text: "Caps Lock açık"
                    color: "#ffcf5a"
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: 15 * root.s
                }
                Text {
                    anchors.right: parent.right
                    visible: !keyboard.capsLock
                    text: "Esc · geri"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.family: root.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: 14 * root.s
                }
            }
        }
    }
}
