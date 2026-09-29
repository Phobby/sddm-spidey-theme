import QtQuick
import QtQml

// IDLE durumundaki sağ panel: kullanıcı seçici, oturum seçici, güç butonları.
GlassPanel {
    id: panel

    property real s: 1
    property color accent: "#e8363f"
    property string fontFamily: ""
    property bool showPower: true

    property alias userIndex: users.currentIndex
    readonly property string userName: users.currentItem ? users.currentItem.loginName : ""
    readonly property string userRealName: users.currentItem ? users.currentItem.displayName : ""
    readonly property url userIcon: users.currentItem ? users.currentItem.iconPath : ""
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property string sessionName: {
        var dep = sessionNames.count
        var o = sessionNames.objectAt(sessionIndex)
        return o ? o.name : ""
    }

    signal activated()   // kullanıcıya çift tıklama → zıpla

    radius: 20 * s
    height: col.implicitHeight + 2 * col.anchors.margins

    Instantiator {
        id: sessionNames
        model: sessionModel
        delegate: QtObject { property string name: model.name }
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: 26 * panel.s
        spacing: 18 * panel.s

        Text {
            text: "Kim giriyor?"
            color: panel.accent
            font.family: panel.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 15 * panel.s
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 2.5 * panel.s
        }

        ListView {
            id: users
            width: parent.width
            height: Math.min(count, 4) * 66 * panel.s
            clip: true
            model: userModel
            currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 150
            keyNavigationEnabled: true

            highlight: Rectangle {
                radius: 12 * panel.s
                color: Qt.rgba(1, 1, 1, 0.10)
                border.color: Qt.rgba(1, 1, 1, 0.10)
            }

            delegate: Item {
                id: row
                required property int index
                required property var model
                readonly property string loginName: model.name
                readonly property string displayName: model.realName && model.realName.length ? model.realName : model.name
                readonly property url iconPath: model.icon ? model.icon : ""
                readonly property bool isCurrent: ListView.isCurrentItem

                width: ListView.view.width
                height: 66 * panel.s

                Avatar {
                    id: av
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * panel.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44 * panel.s
                    height: width
                    source: row.iconPath
                    name: row.displayName
                    accent: panel.accent
                    fontFamily: panel.fontFamily
                    selected: row.isCurrent
                }
                Column {
                    anchors.left: av.right
                    anchors.leftMargin: 14 * panel.s
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: row.displayName
                        elide: Text.ElideRight
                        color: "white"
                        opacity: row.isCurrent ? 1 : 0.75
                        font.family: panel.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 21 * panel.s
                    }
                    Text {
                        visible: row.displayName !== row.loginName
                        text: row.loginName
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: panel.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: 14 * panel.s
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: users.currentIndex = row.index
                    onDoubleClicked: { users.currentIndex = row.index; panel.activated() }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }

        Text {
            text: "Oturum"
            color: Qt.rgba(1, 1, 1, 0.55)
            font.family: panel.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 13 * panel.s
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 2 * panel.s
        }

        Item {
            width: parent.width
            height: 36 * panel.s
            IconButton {
                id: prevSession
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 34 * panel.s
                icon: Qt.resolvedUrl("../assets/icons/chevron-left.svg")
                accent: panel.accent
                visible: sessionNames.count > 1
                onClicked: panel.sessionIndex = (panel.sessionIndex - 1 + sessionNames.count) % sessionNames.count
            }
            Text {
                anchors.left: prevSession.right
                anchors.right: nextSession.left
                anchors.margins: 8 * panel.s
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: panel.sessionName
                color: "white"
                font.family: panel.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: 18 * panel.s
            }
            IconButton {
                id: nextSession
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 34 * panel.s
                icon: Qt.resolvedUrl("../assets/icons/chevron-right.svg")
                accent: panel.accent
                visible: sessionNames.count > 1
                onClicked: panel.sessionIndex = (panel.sessionIndex + 1) % sessionNames.count
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: "Devam etmek için ekrana tıkla ya da Enter'a bas"
            color: Qt.rgba(1, 1, 1, 0.55)
            font.family: panel.fontFamily
            font.weight: Font.Medium
            font.pixelSize: 15 * panel.s
        }

        PowerBar {
            visible: panel.showPower
            anchors.horizontalCenter: parent.horizontalCenter
            s: panel.s
            accent: panel.accent
            fontFamily: panel.fontFamily
        }
    }
}
