import QtQuick
import QtQuick.Effects

// AŞAMA 1: saat, tarih, seçili kullanıcının avatarı ve adı.
// Blurlu cam arka plan üzerinde; tıklamaları yutmaz, panele tıklamak da zıplatır.
Item {
    id: panel

    property real s: 1
    property string fontFamily: ""
    property color accent: "#b9a6ff"
    property date now: new Date()
    property string clockFormat: "HH:mm"
    property string dateFormat: "MMM d"
    property var locale: Qt.locale("en_US")
    property var users            // Instantiator: objectAt(i).name / realName / icon
    property Item backgroundItem  // cam arka plan için bulanıklaştırılacak video
    property real blurAmount: 0.8
    property real cardOpacity: 0.55
    property real minWidth: 0
    property int userIndex: 0
    readonly property int userCount: users ? users.count : 0

    // Görünen kullanıcı, seçimin gerisinden gelir: önce eski kaybolur, sonra yeni belirir.
    property int shownIndex: 0
    Component.onCompleted: shownIndex = userIndex
    readonly property var shownUser: {
        var dep = userCount
        return users && shownIndex >= 0 ? users.objectAt(shownIndex) : null
    }
    property int _dir: 1
    // Kullanıcı değişim animasyonu yalnızca ana avatar + isme uygulanır
    property real swapOpacity: 1
    property real swapSlide: 0

    signal userPicked(int index)

    // Ana avatarın üzerine gelince diğer kullanıcılar iki yana açılır;
    // grup alanından çıkınca kısa bir gecikmeyle kapanır.
    property bool othersOpen: false
    readonly property bool _wantOpen: userCount > 1 && (mainHover.hovered || (othersOpen && groupHover.hovered))
    on_WantOpenChanged: {
        if (_wantOpen) {
            closeTimer.stop()
            othersOpen = true
        } else {
            closeTimer.restart()
        }
    }
    Timer { id: closeTimer; interval: 300; onTriggered: panel.othersOpen = false }

    readonly property real pad: 44 * s
    implicitWidth: Math.max(minWidth, col.implicitWidth + 2 * pad)
    implicitHeight: col.implicitHeight + 2 * pad

    onUserIndexChanged: {
        if (userIndex === shownIndex || userCount < 1)
            return
        // Wrap durumunda da hareket yönü basılan oka uysun.
        var fwd = (userIndex - shownIndex + userCount) % userCount
        _dir = fwd <= userCount / 2 ? 1 : -1
        swap.restart()
    }

    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: panel; property: "swapOpacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "swapSlide"; to: -panel._dir * 14 * panel.s; duration: 120; easing.type: Easing.OutCubic }
        }
        ScriptAction {
            script: {
                panel.shownIndex = panel.userIndex
                panel.swapSlide = panel._dir * 14 * panel.s
            }
        }
        ParallelAnimation {
            NumberAnimation { target: panel; property: "swapOpacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "swapSlide"; to: 0; duration: 200; easing.type: Easing.OutCubic }
        }
    }

    // Şifre kartıyla aynı blurlu cam arka plan; tıklamaları yutmaz (panele
    // tıklamak da zıplatır).
    GlassPanel {
        id: glass
        anchors.fill: parent
        backgroundItem: panel.backgroundItem
        blurAmount: panel.blurAmount
        blurMax: 48
        radius: 40 * panel.s
        tint: Qt.rgba(0x1a / 255, 0x1a / 255, 0x22 / 255, panel.cardOpacity)
        borderColor: Qt.rgba(1, 1, 1, 0.12)
        shadowSize: 40 * panel.s
        blockInput: false
    }

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 0

        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.now.toLocaleTimeString(panel.locale, panel.clockFormat)
            color: "white"
            font.family: panel.fontFamily
            font.weight: Font.Light
            font.pixelSize: 120 * panel.s
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.now.toLocaleDateString(panel.locale, panel.dateFormat)
            color: "white"
            opacity: 0.7
            font.family: panel.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: clockText.font.pixelSize * 0.25
            font.letterSpacing: 1 * panel.s
        }

        Item { width: 1; height: 44 * panel.s }

        Column {
            id: userCol
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * panel.s

            // Ana avatar + arkasından iki yana açılan diğer kullanıcılar
            Item {
                id: avatarRow
                readonly property real mainSize: 104 * panel.s
                readonly property real otherSize: 64 * panel.s
                readonly property real gap: 18 * panel.s
                readonly property int maxOthers: 6
                readonly property int others: Math.min(Math.max(panel.userCount - 1, 0), maxOthers)
                readonly property int perSide: Math.ceil(others / 2)

                anchors.horizontalCenter: parent.horizontalCenter
                width: mainSize + 2 * perSide * (otherSize + gap)
                height: mainSize

                // Açıkken grubun tamamı hover alanı
                HoverHandler { id: groupHover }

                Repeater {
                    model: panel.userCount

                    Item {
                        id: other
                        required property int index
                        readonly property var user: {
                            var dep = panel.userCount
                            return panel.users ? panel.users.objectAt(index) : null
                        }
                        // Diğerleri arasındaki sıra: 0 sağ, 1 sol, 2 sağ...
                        readonly property int k: index < panel.shownIndex ? index : index - 1
                        readonly property int side: k % 2 === 0 ? 1 : -1
                        readonly property int slot: Math.floor(k / 2)
                        readonly property real openCenter: avatarRow.width / 2 + side * (avatarRow.mainSize / 2 + avatarRow.gap
                                                           + slot * (avatarRow.otherSize + avatarRow.gap) + avatarRow.otherSize / 2)
                        readonly property bool hovered: otherArea.containsMouse

                        visible: index !== panel.shownIndex && k < avatarRow.maxOthers && opacity > 0.01
                        width: avatarRow.otherSize
                        height: width
                        y: (avatarRow.height - height) / 2
                        // Kapalıyken ana avatarın arkasında saklı
                        x: (panel.othersOpen ? openCenter : avatarRow.width / 2) - width / 2
                        z: hovered ? 5 : 1
                        opacity: panel.othersOpen ? (hovered ? 1 : 0.8) : 0
                        scale: !panel.othersOpen ? 0.4 : hovered ? 1.3 : 1
                        Behavior on x { NumberAnimation { duration: 200 + other.slot * 40; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Avatar {
                            anchors.fill: parent
                            source: other.user ? other.user.icon : ""
                            name: other.user ? other.user.displayName : ""
                            accent: panel.accent
                            fontFamily: panel.fontFamily
                            selected: other.hovered
                            ringWidth: 1.5 * panel.s
                        }
                        Text {
                            anchors.top: parent.bottom
                            anchors.topMargin: 8 * panel.s
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: other.user ? other.user.displayName : ""
                            color: "white"
                            opacity: other.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            font.family: panel.fontFamily
                            font.weight: Font.DemiBold
                            font.pixelSize: 13 * panel.s
                        }
                        // Tıklama o kullanıcıyı seçer (zıplamayı başlatmaz)
                        MouseArea {
                            id: otherArea
                            anchors.fill: parent
                            enabled: panel.othersOpen
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.userPicked(other.index)
                        }
                    }
                }

                Avatar {
                    id: avatar
                    z: 10
                    anchors.centerIn: parent
                    width: avatarRow.mainSize
                    height: width
                    source: panel.shownUser ? panel.shownUser.icon : ""
                    name: panel.shownUser ? panel.shownUser.displayName : ""
                    accent: panel.accent
                    fontFamily: panel.fontFamily
                    ringWidth: 1.5 * panel.s
                    opacity: panel.swapOpacity
                    scale: mainHover.hovered && panel.userCount > 1 ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    transform: Translate { y: panel.swapSlide }
                    HoverHandler { id: mainHover }
                }
            }

            Text {
                id: nameText
                anchors.horizontalCenter: parent.horizontalCenter
                text: panel.shownUser ? panel.shownUser.displayName : ""
                color: "white"
                opacity: panel.swapOpacity
                transform: Translate { y: panel.swapSlide }
                font.family: panel.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: 24 * panel.s
            }
            Text {
                id: hint
                anchors.horizontalCenter: parent.horizontalCenter
                visible: panel.userCount > 1
                text: "↑ ↓  switch user"
                color: "white"
                opacity: 0.45
                font.family: panel.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 14 * panel.s
                font.letterSpacing: 1 * panel.s
            }
        }
    }
}
