import QtQuick
import "components"

// Spidey — SDDM (Qt6) teması
// Akış: idle (döngü) → jump (bir kez) → phone (son karede donar + şifre) → giriş
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

    readonly property real s: height / 1080
    readonly property string fontFamily: cfg("font", fontMedium.name || "sans-serif")
    readonly property color accent: cfg("accentColor", "#e8363f")
    readonly property real panelWidth: Number(cfg("panelWidth", 400)) * s
    readonly property bool panelLeft: String(cfg("panelSide", "right")).toLowerCase() === "left"
    readonly property real blurAmount: Math.max(0, Math.min(1, Number(cfg("blur", 0.7))))
    readonly property string powerPos: String(cfg("powerButtons", "panel")).toLowerCase()
    readonly property bool showClock: cfgBool("showClock", true)
    readonly property real margin: 72 * s
    readonly property bool isPrimary: typeof primaryScreen === "undefined" || primaryScreen

    FontLoader { id: fontMedium; source: "assets/fonts/Rajdhani-Medium.ttf" }
    FontLoader { source: "assets/fonts/Rajdhani-SemiBold.ttf" }
    FontLoader { source: "assets/fonts/Rajdhani-Bold.ttf" }

    // ---- Durum makinesi -----------------------------------------------------
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

    // Katmanı en üste al ve opacity ile aç. Alttakiler geçiş bitince gizlenir.
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

    // Geçiş bitince görünmeyen katmanları gizle ve durdur; idle'a dönüldüyse
    // sonraki klipleri başa sarıp ilk karelerinde hazır beklet.
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
        crossfadeTo(jumpLayer, 300)   // idle'ın rastgele karesinden geçişi gizler
    }

    // jump bitti → telefonu çıkarma (giriş) klibi; ardışık kesitler, kısa overlap
    function goPhone() {
        if (state !== "jump")
            return
        state = "phone"
        phoneLayer.start()
        crossfadeTo(phoneLayer, 150)
        passwordPanel.clear()
        passwordPanel.focusField()
    }

    // Giriş klibi yavaşlayarak durur → aynı kareden başlayan döngüye geç
    function startPhoneLoop() {
        if (state !== "phone" || currentLayer === phoneLoopLayer)
            return
        phoneLoopLayer.restart()
        crossfadeTo(phoneLoopLayer, 150)
    }

    // Beklemek istemeyen kullanıcı harfe bastı: doğrudan telefona bakma anına
    function goPhoneLoop(firstChar) {
        if (!isPrimary || (state !== "idle" && state !== "jump"))
            return
        state = "phone"
        phoneLoopLayer.restart()
        crossfadeTo(phoneLoopLayer, 300)
        passwordPanel.clear()
        passwordPanel.focusField()
        if (firstChar)
            passwordPanel.insertText(firstChar)
    }

    function goIdle() {
        if (state !== "jump" && state !== "phone")
            return
        state = "idle"
        passwordPanel.busy = false
        passwordPanel.clear()
        idleLayer.restart()
        crossfadeTo(idleLayer, 300)
        keyCatcher.forceActiveFocus()
    }

    function login(password) {
        sddm.login(userPanel.userName, password, userPanel.sessionIndex)
    }

    function isTypedChar(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false
        return event.text.length === 1 && event.text.charCodeAt(0) > 32 && event.text.charCodeAt(0) !== 127
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordPanel.fail("Yanlış şifre")
        }
        function onLoginSucceeded() {
            root.state = "done"
        }
    }

    // ---- Video katmanları ---------------------------------------------------
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

    // ---- Etkileşim ----------------------------------------------------------
    // Panel dışına tıklama → zıpla
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
                root.goIdle()
                event.accepted = true
            } else if (root.state === "idle" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                root.goJump()
                event.accepted = true
            } else if (root.state === "idle" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                var n = userPanel.userIndex + (event.key === Qt.Key_Up ? -1 : 1)
                var count = userModel.count !== undefined ? userModel.count : userModel.rowCount()
                if (n >= 0 && n < count)
                    userPanel.userIndex = n
                event.accepted = true
            } else if (root.isTypedChar(event)) {
                if (root.state === "idle" || root.state === "jump") {
                    root.goPhoneLoop(event.text)
                } else if (root.state === "phone") {
                    // fokus alandan kaçtıysa yazılan harf kaybolmasın
                    passwordPanel.focusField()
                    passwordPanel.insertText(event.text)
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

        Clock {
            id: clock
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 48 * root.s
            anchors.topMargin: 40 * root.s
            s: root.s
            fontFamily: root.fontFamily
            timeFormat: root.cfg("clockFormat", "HH:mm")
            dateFormat: root.cfg("dateFormat", "d MMMM dddd")
            locale: Qt.locale(root.cfg("locale", ""))
            visible: root.showClock && opacity > 0
            opacity: root.state === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        UserPanel {
            id: userPanel
            width: root.panelWidth
            anchors.verticalCenter: parent.verticalCenter
            x: root.panelLeft ? root.margin : parent.width - width - root.margin
            s: root.s
            accent: root.accent
            fontFamily: root.fontFamily
            backgroundItem: videoStack
            blurAmount: root.blurAmount
            showPower: root.powerPos === "panel"
            visible: opacity > 0
            opacity: root.state === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onActivated: root.goJump()
        }

        PowerBar {
            id: floatingPower
            visible: opacity > 0 && root.powerPos !== "panel" && root.powerPos !== "hidden"
            opacity: root.state === "idle" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            s: root.s
            accent: root.accent
            fontFamily: root.fontFamily
            x: root.powerPos === "bottom-left" ? 48 * root.s : parent.width - width - 48 * root.s
            y: root.powerPos === "top-right" ? 40 * root.s : parent.height - height - 40 * root.s
        }

        PasswordPanel {
            id: passwordPanel
            width: root.panelWidth
            anchors.verticalCenter: parent.verticalCenter
            x: root.panelLeft ? root.margin : parent.width - width - root.margin
            s: root.s
            accent: root.accent
            fontFamily: root.fontFamily
            backgroundItem: videoStack
            blurAmount: root.blurAmount
            userName: userPanel.userName
            userRealName: userPanel.userRealName
            userIcon: userPanel.userIcon
            sessionName: userPanel.sessionName
            visible: opacity > 0
            opacity: root.state === "phone" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutQuad } }
            onSubmitted: (password) => root.login(password)

            Keys.onEscapePressed: root.goIdle()
        }
    }

    // ---- Giriş başarılı → siyaha kararma ------------------------------------
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
