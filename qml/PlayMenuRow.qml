import QtQuick 2.0

Row {
    id: root

    x: parent.width - width
    width: parent.width
    height: parent.height

    layoutDirection: Qt.RightToLeft
    opacity: myApp.model.fullScreenMode ? 0 : 1
    visible: opacity > 0 && y !== 50
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    state: menuIndex === menuRows.indexOf(root) ? "in" : "out"

    states: [
        State {
            name: "in"
            PropertyChanges { target: root; y: 0 }
        },
        State {
            name: "out"
            PropertyChanges { target: root; y: 50 }

        }
    ]

    transitions: [
        Transition {
            from: "in"
            animations: NumberAnimation { target: root; property: "y"; from: -50; to: 0; duration: 200; easing.type: Easing.OutCubic }
        },
        Transition {
            from: "out"
            animations: NumberAnimation { target: root; property: "y"; from: 0; to: 50; duration: 200; easing.type: Easing.OutCubic }
        }
    ]

}