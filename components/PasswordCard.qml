import QtQuick
import QtQuick.Effects

// STAGE 2: blurred glass card — user/time row, pill password field,
// ANOTHER USER / UNLOCK buttons.
Item {
    id: root

    property Item backgroundItem
    property real s: 1
    property string fontFamily: ""
    property color accent: "#b9a6ff"
    property real cardOpacity: 0.55
    property real blurAmount: 0.8
    property date now: new Date()
    property string clockFormat: "HH:mm"
    property var locale: Qt.locale("en_US")
    property string userName: ""
    property bool canSwitchUser: false
    property bool busy: false

    signal submitted(string password)
    signal anotherUser()

    readonly property bool powerMenuOpen: powerMenu.open
    function closePowerMenu() { powerMenu.close() }

    implicitHeight: card.height

    readonly property color errorColor: "#ff5a6a"
    property bool errorFlash: false

    function focusField() { input.forceActiveFocus() }
    function clear() { input.text = "" }
    function insertText(t) { if (!busy) input.insert(input.cursorPosition, t) }
    function fail() {
        busy = false
        replyTimeout.stop()
        input.text = ""
        errorFlash = true
        errorTimer.restart()
        shake.restart()
        input.forceActiveFocus()
    }
    function _submit() {
        if (busy) return
        busy = true
        replyTimeout.restart()
        root.submitted(input.text)
    }
    onBusyChanged: if (!busy) replyTimeout.stop()

    Timer { id: errorTimer; interval: 900; onTriggered: root.errorFlash = false }
    // If the daemon never answers (e.g. --test-mode), don't leave the card locked.
    Timer { id: replyTimeout; interval: 15000; onTriggered: root.fail() }

    property real shakeOffset: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeOffset"; to: -18 * root.s; duration: 45; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "shakeOffset"; to: 16 * root.s; duration: 70; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "shakeOffset"; to: -12 * root.s; duration: 65; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "shakeOffset"; to: 8 * root.s; duration: 60; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "shakeOffset"; to: -4 * root.s; duration: 55; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 50; easing.type: Easing.OutCubic }
    }

    GlassPanel {
        id: card
        x: root.shakeOffset
        width: root.width
        height: col.implicitHeight + 2 * col.anchors.margins
        radius: height * 0.12
        backgroundItem: root.backgroundItem
        blurAmount: root.blurAmount
        blurMax: 48
        tint: Qt.rgba(0x1a / 255, 0x1a / 255, 0x22 / 255, root.cardOpacity)
        borderColor: Qt.rgba(1, 1, 1, 0.12)
        shadowSize: 40 * root.s
        onBackgroundClicked: powerMenu.close()

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 30 * root.s
            spacing: 22 * root.s

            // a) lock · USERNAME · time
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * root.s
                opacity: 0.6
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s
                    height: width
                    source: Qt.resolvedUrl("../assets/icons/lock.svg")
                    sourceSize: Qt.size(width * 2, height * 2)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.userName.toUpperCase()
                    color: "white"
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 13 * root.s
                    font.letterSpacing: 3 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    color: "white"
                    font.family: root.fontFamily
                    font.pixelSize: 13 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.now.toLocaleTimeString(root.locale, root.clockFormat)
                    color: "white"
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: 13 * root.s
                    font.letterSpacing: 1 * root.s
                }
            }

            // b) pill-shaped password field
            Item {
                id: field
                width: parent.width
                height: 56 * root.s
                readonly property bool focused: input.activeFocus

                // Focus glow
                RectangularShadow {
                    anchors.fill: parent
                    radius: height / 2
                    blur: 18 * root.s
                    spread: 0
                    color: root.errorFlash ? root.errorColor : root.accent
                    opacity: root.errorFlash ? 0.55 : field.focused ? 0.45 : 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(0, 0, 0, 0.22)
                    border.width: (field.focused ? 2 : 1.5) * root.s
                    border.color: root.errorFlash ? root.errorColor
                                : field.focused ? Qt.lighter(root.accent, 1.15)
                                : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5)
                    Behavior on border.color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 28 * root.s
                    anchors.rightMargin: 28 * root.s
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    color: "white"
                    selectionColor: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: 24 * root.s
                    font.letterSpacing: 6 * root.s
                    enabled: !root.busy
                    clip: true
                    onAccepted: root._submit()
                }
                Text {
                    anchors.centerIn: parent
                    visible: input.text.length === 0
                    text: "PASSWORD"
                    color: "white"
                    opacity: 0.35
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: 14 * root.s
                    font.letterSpacing: 4 * root.s
                }
            }

            // c) ANOTHER USER | UNLOCK →
            Row {
                id: buttons
                width: parent.width
                spacing: 12 * root.s

                Rectangle {
                    id: anotherBtn
                    visible: root.canSwitchUser
                    width: (parent.width - parent.spacing) * 0.42
                    height: 48 * root.s
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, anotherArea.pressed ? 0.20 : anotherArea.containsMouse ? 0.14 : 0.06)
                    border.color: anotherArea.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.7) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    scale: anotherArea.pressed ? 0.97 : anotherArea.containsMouse ? 1.03 : 1
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: "ANOTHER USER"
                        color: "white"
                        opacity: anotherArea.containsMouse ? 1 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        font.family: root.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 12 * root.s
                        font.letterSpacing: 2 * root.s
                    }
                    MouseArea {
                        id: anotherArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.anotherUser()
                    }
                }

                Rectangle {
                    id: unlockBtn
                    width: anotherBtn.visible ? parent.width - anotherBtn.width - parent.spacing : parent.width
                    height: 48 * root.s
                    radius: height / 2
                    color: Qt.darker(root.accent, unlockArea.pressed ? 1.9 : unlockArea.containsMouse ? 1.35 : 1.6)
                    opacity: root.busy ? 0.55 : 1
                    scale: unlockArea.pressed ? 0.97 : unlockArea.containsMouse ? 1.03 : 1
                    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // Hover glow
                    RectangularShadow {
                        anchors.fill: parent
                        z: -1
                        radius: parent.radius
                        blur: 20 * root.s
                        spread: 0
                        color: root.accent
                        opacity: unlockArea.containsMouse ? 0.45 : 0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 10 * root.s
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "UNLOCK"
                            color: "white"
                            font.family: root.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 13 * root.s
                            font.letterSpacing: 3 * root.s
                        }
                        Image {
                            id: arrow
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18 * root.s
                            height: width
                            source: Qt.resolvedUrl("../assets/icons/arrow-right.svg")
                            sourceSize: Qt.size(width * 2, height * 2)
                            transform: Translate {
                                x: unlockArea.containsMouse ? 5 * root.s : 0
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    MouseArea {
                        id: unlockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._submit()
                    }
                }
            }

            // d) bottom row: divider + hint + power menu (inside the card)
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }
            Item {
                width: parent.width
                height: powerMenu.height

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ESC · BACK"
                    color: "white"
                    opacity: powerMenu.open ? 0 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: 12 * root.s
                    font.letterSpacing: 2 * root.s
                }
                PowerMenu {
                    id: powerMenu
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    accent: root.accent
                    fontFamily: root.fontFamily
                }
            }
        }
    }
}
