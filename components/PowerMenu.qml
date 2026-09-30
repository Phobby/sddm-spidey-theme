import QtQuick

// Round power button; on click, Shut down / Restart / Sleep slide out
// from behind it one after another, moving to the left.
Item {
    id: menu

    property real s: 1
    property color accent: "#b9a6ff"
    property string fontFamily: ""
    property bool open: false

    function close() { open = false }

    readonly property real btnSize: 46 * s
    readonly property real gap: 12 * s

    // If SDDM reports no power actions at all (e.g. --test-mode, no daemon)
    // show them all; otherwise hide the unsupported ones.
    readonly property bool _anyKnown: sddm.canPowerOff || sddm.canReboot || sddm.canSuspend
    readonly property var _items: {
        var list = []
        if (!_anyKnown || sddm.canPowerOff)
            list.push({ icon: "power.svg", tip: "Shut down", action: "powerOff" })
        if (!_anyKnown || sddm.canReboot)
            list.push({ icon: "reboot.svg", tip: "Restart", action: "reboot" })
        if (!_anyKnown || sddm.canSuspend)
            list.push({ icon: "suspend.svg", tip: "Sleep", action: "suspend" })
        return list
    }

    function _run(action) {
        if (action === "powerOff") sddm.powerOff()
        else if (action === "reboot") sddm.reboot()
        else if (action === "suspend") { close(); sddm.suspend() }
    }

    width: btnSize + _items.length * (btnSize + gap)
    height: btnSize

    Repeater {
        model: menu._items

        IconButton {
            required property var modelData
            required property int index
            readonly property real openX: menu.width - menu.btnSize - (index + 1) * (menu.btnSize + menu.gap)
            readonly property real closedX: menu.width - menu.btnSize

            width: menu.btnSize
            // Hidden behind the power button when closed; slides left when opened.
            x: menu.open ? openX : closedX
            opacity: menu.open ? 1 : 0
            scale: menu.open ? 1 : 0.6
            visible: opacity > 0
            enabled: menu.open
            // Farther buttons arrive a bit later → staggered opening
            Behavior on x { NumberAnimation { duration: 180 + index * 50; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 160 + index * 50; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180 + index * 50; easing.type: Easing.OutCubic } }

            icon: Qt.resolvedUrl("../assets/icons/" + modelData.icon)
            tooltip: modelData.tip
            accent: menu.accent
            fontFamily: menu.fontFamily
            onClicked: menu._run(modelData.action)
        }
    }

    IconButton {
        id: powerBtn
        x: menu.width - menu.btnSize
        z: 1
        width: menu.btnSize
        icon: menu.open ? Qt.resolvedUrl("../assets/icons/close.svg") : Qt.resolvedUrl("../assets/icons/power.svg")
        accent: menu.accent
        fontFamily: menu.fontFamily
        tooltip: menu.open ? "" : "Power"
        highlight: true
        rotation: menu.open ? 90 : 0
        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        onClicked: menu.open = !menu.open
    }
}
