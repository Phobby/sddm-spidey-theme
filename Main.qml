import QtQuick
import QtQml
import "components"

// Spidey — SDDM (Qt6) theme
// Flow: idle (loop) → jump (once) → phone (intro + loop, password card) → login
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    // ---- theme.conf ---------------------------------------------------------
    function cfg(key, def) {
        var v = config[key]
        return (v === undefined || v === null || String(v) === "") ? def : v
    }
    function cfgBool(key, def) {
        var v = cfg(key, def)
        return v === true || String(v).toLowerCase() === "true"
    }

    // All sizes scale with screen height (1440p reference).
    readonly property real uiScale: Math.max(0.5, Number(cfg("uiScale", 1.0)))
    readonly property real s: height / 1440 * uiScale
    readonly property string fontFamily: cfg("fontFamily", fontLight.name || "sans-serif")
    readonly property color accent: cfg("accentColor", "#b9a6ff")
    readonly property real cardOpacity: Math.max(0, Math.min(1, Number(cfg("cardOpacity", 0.55))))
    readonly property real blurAmount: Math.max(0, Math.min(1, Number(cfg("blurAmount", 0.8))))
    readonly property real cardWidth: Math.max(0.15, Math.min(0.6, Number(cfg("cardWidth", 0.25)))) * width
    readonly property bool panelLeft: String(cfg("panelSide", "right")).toLowerCase() === "left"
    readonly property string clockFormat: cfg("clockFormat", "HH:mm")
    readonly property string dateFormat: cfg("dateFormat", "MMM d")
    readonly property var uiLocale: Qt.locale(cfg("locale", "en_US"))
    // Horizontal center of the panel: the side the character leaves empty
    readonly property real panelCenterX: panelLeft ? width * 0.23 : width * 0.77
    readonly property bool isPrimary: typeof primaryScreen === "undefined" || primaryScreen

    FontLoader { id: fontLight; source: "assets/fonts/Rajdhani-Light.ttf" }
    FontLoader { source: "assets/fonts/Rajdhani-Medium.ttf" }
    FontLoader { source: "assets/fonts/Rajdhani-SemiBold.ttf" }
    FontLoader { source: "assets/fonts/Rajdhani-Bold.ttf" }

    // ---- Clock (updates at the top of each minute) ---------------------------
    property date now: new Date()
    Timer {
        id: minuteTimer
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date()
            interval = 60000 - (root.now.getSeconds() * 1000 + root.now.getMilliseconds()) + 50
            restart()
        }
    }

    // ---- User selection: single source of truth ------------------------------
    Instantiator {
        id: userList
        model: userModel
        delegate: QtObject {
            required property var model
            readonly property string name: model.name
            readonly property string realName: model.realName ? model.realName : ""
            readonly property string displayName: realName.length ? realName : name
            readonly property url icon: model.icon ? model.icon : ""
        }
    }
    readonly property int userCount: userList.count
    property int selectedUserIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    readonly property var selectedUser: {
        var dep = userList.count
        return userList.objectAt(selectedUserIndex)
    }
    readonly property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    function selectUser(step) {
        if (userCount < 1) return
        selectedUserIndex = (selectedUserIndex + step + userCount) % userCount
    }

    // ---- State machine -------------------------------------------------------
    state: "idle"
    states: [
        State { name: "idle" },
        State { name: "jump" },
        State { name: "phone" },
        State { name: "done" }
    ]

    property int topZ: 1
    property Item currentLayer: idleLayer
    readonly property var allLayers: [idleLayer, jumpLayer, phoneLayer, phoneLoopLayer]

    // Bring the layer to the top and fade it in. The ones below get hidden when it's done.
    function crossfadeTo(layer, ms) {
        if (currentLayer === layer && layer.opacity === 1)
            return
        fade.stop()
        topZ += 1
        layer.z = topZ
        layer.opacity = 0
        currentLayer = layer
        fade.target = layer
        fade.duration = ms
        fade.start()
    }
    NumberAnimation {
        id: fade
        property: "opacity"
        to: 1
        easing.type: Easing.InOutQuad
        onFinished: root.afterFade()
    }

    // After a crossfade, hide and pause the layers you can't see; when back in idle,
    // rewind the next clips and park them on their first frame.
    function afterFade() {
        for (var i = 0; i < allLayers.length; i++) {
            var l = allLayers[i]
            if (l === currentLayer)
                continue
            l.opacity = 0
            if (state === "idle")
                l.prepare()
            else
                l.hold()
        }
    }

    function goJump() {
        if (state !== "idle" || !isPrimary)
            return
        if (jumpLayer.failed) {
            goPhoneLoop("")
            return
        }
        state = "jump"
        jumpLayer.start()
        crossfadeTo(jumpLayer, 300)   // hides the jump from a random idle frame
    }

    // jump finished → phone intro clip; the cuts are contiguous, so a short overlap is enough
    function goPhone() {
        if (state !== "jump")
            return
        state = "phone"
        phoneLayer.start()
        crossfadeTo(phoneLayer, 150)
        passwordCard.clear()
        passwordCard.focusField()
    }

    // The intro eases to a stop → switch to the loop that starts on that same frame
    function startPhoneLoop() {
        if (state !== "phone" || currentLayer === phoneLoopLayer)
            return
        phoneLoopLayer.restart()
        crossfadeTo(phoneLoopLayer, 150)
    }

    // Impatient user typed a letter: jump straight to the phone loop
    function goPhoneLoop(firstChar) {
        if (!isPrimary || (state !== "idle" && state !== "jump"))
            return
        state = "phone"
        phoneLoopLayer.restart()
        crossfadeTo(phoneLoopLayer, 300)
        passwordCard.clear()
        passwordCard.focusField()
        if (firstChar)
            passwordCard.insertText(firstChar)
    }

    function goIdle() {
        if (state !== "jump" && state !== "phone")
            return
        state = "idle"
        passwordCard.closePowerMenu()
        passwordCard.busy = false
        passwordCard.clear()
        idleLayer.restart()
        crossfadeTo(idleLayer, 300)
        keyCatcher.forceActiveFocus()
    }

    function login(password) {
        var name = userCount > 0 && selectedUser ? selectedUser.name : passwordCard.typedUsername
        sddm.login(name, password, sessionIndex)
    }

    // ESC: close the power menu first, otherwise go back to IDLE
    function handleEscape() {
        if (passwordCard.powerMenuOpen)
            passwordCard.closePowerMenu()
        else
            goIdle()
    }

    function isTypedChar(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false
        return event.text.length === 1 && event.text.charCodeAt(0) > 32 && event.text.charCodeAt(0) !== 127
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordCard.fail()
        }
        function onLoginSucceeded() {
            root.state = "done"
        }
    }

    // ---- Video layers --------------------------------------------------------
    Item {
        id: videoStack
        anchors.fill: parent

        ClipLayer {
            id: idleLayer
            anchors.fill: parent
            z: 1
            source: root.isPrimary ? Qt.resolvedUrl("assets/idle.mp4") : ""
            poster: Qt.resolvedUrl("assets/idle_first.jpg")
            looping: true
            Component.onCompleted: if (root.isPrimary) start()
        }

        ClipLayer {
            id: jumpLayer
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            source: root.isPrimary ? Qt.resolvedUrl("assets/jump.mp4") : ""
            poster: Qt.resolvedUrl("assets/jump_first.jpg")
            endPoster: Qt.resolvedUrl("assets/jump_last.jpg")
            freezeAtEnd: true
            endLead: 0.15
            Component.onCompleted: if (root.isPrimary) prepare()
            onNearEnd: root.goPhone()
            onFinished: root.goPhone()
        }

        ClipLayer {
            id: phoneLayer
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            source: root.isPrimary ? Qt.resolvedUrl("assets/phone.mp4") : ""
            poster: Qt.resolvedUrl("assets/phone_first.jpg")
            endPoster: Qt.resolvedUrl("assets/phone_loop_first.jpg")
            freezeAtEnd: true
            endLead: 0.15
            Component.onCompleted: if (root.isPrimary) prepare()
            onNearEnd: root.startPhoneLoop()
            onFinished: root.startPhoneLoop()
        }

        ClipLayer {
            id: phoneLoopLayer
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            source: root.isPrimary ? Qt.resolvedUrl("assets/phone_loop.mp4") : ""
            poster: Qt.resolvedUrl("assets/phone_loop_first.jpg")
            looping: true
            Component.onCompleted: if (root.isPrimary) prepare()
        }
    }

    // ---- Interaction ---------------------------------------------------------
    // Click anywhere → jump
    MouseArea {
        anchors.fill: parent
        enabled: root.state === "idle"
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.goJump()
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.handleEscape()
                event.accepted = true
            } else if (root.state === "idle" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                root.goJump()
                event.accepted = true
            } else if (root.state === "idle" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                root.selectUser(event.key === Qt.Key_Up ? -1 : 1)
                event.accepted = true
            } else if (root.isTypedChar(event)) {
                if (root.state === "idle" || root.state === "jump") {
                    root.goPhoneLoop(event.text)
                } else if (root.state === "phone") {
                    // if the field lost focus, don't lose the typed character
                    passwordCard.focusField()
                    passwordCard.insertText(event.text)
                }
                event.accepted = true
            } else if (root.state === "jump" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.goPhoneLoop("")
                event.accepted = true
            }
        }
    }

    // ---- UI -----------------------------------------------------------------
    Item {
        id: ui
        anchors.fill: parent
        visible: root.isPrimary

        // STAGE 1 — glass panel: clock, date, user (doesn't swallow clicks: clicking it also jumps)
        IdlePanel {
            id: idlePanel
            x: root.panelCenterX - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            s: root.s
            fontFamily: root.fontFamily
            accent: root.accent
            now: root.now
            clockFormat: root.clockFormat
            dateFormat: root.dateFormat
            locale: root.uiLocale
            users: userList
            backgroundItem: videoStack
            blurAmount: root.blurAmount
            cardOpacity: root.cardOpacity
            // 3+ users: card width (so the avatar fan fits);
            // 1–2 users: shrink to fit the content
            minWidth: root.userCount >= 3 ? root.cardWidth : 0
            userIndex: root.selectedUserIndex
            onUserPicked: (index) => root.selectedUserIndex = index
            visible: opacity > 0
            opacity: root.state === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }

        // With the power menu open, clicking outside the card closes it (sits below the card)
        MouseArea {
            anchors.fill: parent
            enabled: passwordCard.powerMenuOpen
            visible: enabled
            onClicked: passwordCard.closePowerMenu()
        }

        // STAGE 2 — password card
        PasswordCard {
            id: passwordCard
            width: root.cardWidth
            x: root.panelCenterX - width / 2
            anchors.verticalCenter: parent.verticalCenter
            backgroundItem: videoStack
            s: root.s
            fontFamily: root.fontFamily
            accent: root.accent
            cardOpacity: root.cardOpacity
            blurAmount: root.blurAmount
            now: root.now
            clockFormat: root.clockFormat
            locale: root.uiLocale
            userName: root.selectedUser ? root.selectedUser.name : ""
            canSwitchUser: root.userCount > 1
            askUsername: root.userCount === 0
            visible: opacity > 0
            opacity: root.state === "phone" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            onSubmitted: (password) => root.login(password)
            // Go back to the first screen to pick another user (idle video + panel)
            onAnotherUser: root.goIdle()
            Keys.onEscapePressed: root.handleEscape()
        }

    }

    // ---- Login succeeded → fade to black -------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "black"
        z: 1000
        opacity: root.state === "done" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InQuad } }
        MouseArea { anchors.fill: parent; enabled: parent.visible }
    }
}
