import QtQuick 2.1
import QtQuick.Controls 1.0

Item {
    id: root

    readonly property bool playing: userPlay || stagePlay;
    readonly property alias flicking: flickable.flicking
    readonly property alias animating: flickable.animating

    property bool stagePlay: false
    property bool userPlay: false

    Component.onCompleted: {
        myApp.timeline = root
    }

    TimelineCanvas {
        width: parent.width
        height: 20
    }

    FlickableMouseArea {
        id: flickable
        width: parent.width
        height: parent.height
        momentumRestX: playing ? -1 : 0
        onAnimatingChanged: updatePlayAnimation();
        onMomentumXUpdated: myApp.model.setTime(myApp.model.time - (momentumX * 0.1));
        onMomentumYUpdated: if (momentumX === 0) myApp.model.setTime(myApp.model.time - (momentumY * 0.005));

//        onClicked: userPlay = !userPlay;
        onRightClicked: myApp.model.shiftUserInterfaceState();
    }

    onPlayingChanged: updatePlayAnimation();

    function updatePlayAnimation()
    {
        animation.lastTickTime = new Date();
        animation.running = playing && !flickable.animating;
    }

    NumberAnimation {
        id: animation
        target: animation
        property: "tick"
        duration: 1000
        loops: Animation.Infinite
        from: 0
        to: 1

        property real tick: 0
        property var lastTickTime: new Date()

        onTickChanged: {
            var tickTime = (new Date()).getTime();
            var timeIncrement = ((tickTime - lastTickTime) / myApp.model.msPerFrame) * -flickable.momentumX;
            myApp.model.setTime(myApp.model.time + timeIncrement);
            lastTickTime = tickTime;
        }
    }
}

