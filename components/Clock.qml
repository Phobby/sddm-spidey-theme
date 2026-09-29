import QtQuick

Column {
    id: clock
    property real s: 1
    property string fontFamily: ""
    property string timeFormat: "HH:mm"
    property string dateFormat: "d MMMM dddd"
    property var locale: Qt.locale()
    property date now: new Date()
    spacing: 0

    Timer {
        interval: 1000
        running: clock.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.now = new Date()
    }

    Text {
        text: clock.now.toLocaleTimeString(clock.locale, clock.timeFormat)
        color: "white"
        font.family: clock.fontFamily
        font.weight: Font.Bold
        font.pixelSize: 44 * clock.s
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.35)
    }
    Text {
        text: clock.now.toLocaleDateString(clock.locale, clock.dateFormat)
        color: Qt.rgba(1, 1, 1, 0.8)
        font.family: clock.fontFamily
        font.weight: Font.DemiBold
        font.pixelSize: 17 * clock.s
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.5 * clock.s
    }
}
