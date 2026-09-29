import QtQuick

// Uyku / yeniden başlat / kapat.
Row {
    id: bar
    property real s: 1
    property color accent: "#e8363f"
    property string fontFamily: ""
    spacing: 22 * s

    IconButton {
        visible: sddm.canSuspend
        width: 44 * bar.s
        icon: Qt.resolvedUrl("../assets/icons/suspend.svg")
        label: "Uyku"
        accent: bar.accent; fontFamily: bar.fontFamily
        onClicked: sddm.suspend()
    }
    IconButton {
        visible: sddm.canReboot
        width: 44 * bar.s
        icon: Qt.resolvedUrl("../assets/icons/reboot.svg")
        label: "Yeniden başlat"
        accent: bar.accent; fontFamily: bar.fontFamily
        onClicked: sddm.reboot()
    }
    IconButton {
        visible: sddm.canPowerOff
        width: 44 * bar.s
        icon: Qt.resolvedUrl("../assets/icons/power.svg")
        label: "Kapat"
        accent: bar.accent; fontFamily: bar.fontFamily
        onClicked: sddm.powerOff()
    }
}
