import QtQuick 2.1
import QtQuick.Controls 1.0
import QtQuick.Layouts 1.0
import QtQuick.Window 2.0

ApplicationWindow {
    id: myApp
    visible: true
    visibility: touchUI ? Window.FullScreen : Window.Windowed
    width: 1500
    height: 600

    Component.onCompleted: width += 1

    property bool touchUI: Qt.platform.os === "ios"

    property alias stage: stage
    property alias menuController: menuController
    property alias timelineFlickable: timelineFlickable
    property alias searchView: searchView

    property Flickable spriteTreeFlickable
    property FlickableMouseArea msPerFrameFlickable

    property Style style: Style {}
    property Model model: Model {}

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                searchView.visible = false;
                return;
            }

            if (!(event.modifiers & Qt.ControlModifier))
                return;

            if (event.key === Qt.Key_P) {
                timelineFlickable.userPlay = !timelineFlickable.userPlay;
            } else if (event.key === Qt.Key_M) {
               menuToggleButton.clicked(1)
            } else if (event.key === Qt.Key_R) {
                menu.interactionPlayButton.checked = !menu.interactionPlayButton.checked;
            } else if (event.key === Qt.Key_S) {
                searchView.visible = true
            } else if (event.key === Qt.Key_Left) {
                model.setTime(0);
            } else if (event.key === Qt.Key_Up) {
                model.setTime(Math.max(0, model.time - 50));
            } else if (event.key === Qt.Key_Down) {
                model.setTime(model.time + 50);
            }
        }

        Stage {
            id: stage
            anchors.fill: parent
            flickable: (menuToggleButton.pressed || flickable.touchCount > 1) ? null : flickable
        }

        TimelineCanvas {
            id: timeline
            anchors.left: parent.left
            anchors.right: actionLabel.left
            anchors.rightMargin: 4
            height: 15
            opacity: timelineFlickable.userPlay ? 0 : 1
            visible: opacity !== 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Text {
            id: actionLabel
            color: "gray"
            width: 50
            font.family: "Arial"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignRight
            opacity: timeline.opacity
            text: !myApp.model.hasSelection || !stage.flickable ? "Flick"
                  : myApp.model.recordsPositionX || myApp.model.recordsPositionY ? "Move"
                  : myApp.model.recordsRotation ? "Rotate"
                  : myApp.model.recordsScale ? "Scale"
                  : "Unknown"

            anchors.right: recordingIndicator.left
            anchors.rightMargin: 4
        }

        Rectangle {
            id: recordingIndicator
            height: timeline.height - (y * 2)
            width: height
            radius: height
            color: !model.hasSelection || !stage.flickable ? "lightgray" : stage.timelinePlay ? "red" : model.hasSelection ? "orange" : "lightgray"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 2
            opacity: timeline.opacity

            SequentialAnimation {
                running: model.hasSelection && stage.flickable && stage.timelinePlay
                onRunningChanged: if (!running) recordingIndicator.opacity = Qt.binding(function() { return timeline.opacity })
                loops: Animation.Infinite
                PauseAnimation { duration: 1000 }
                PropertyAnimation {
                    target: recordingIndicator
                    property: "opacity"
                    duration: 200
                    easing.type: Easing.OutQuad
                    to: 0.0
                }
                PauseAnimation { duration: 1000 }
                PropertyAnimation {
                    target: recordingIndicator
                    property: "opacity"
                    duration: 200
                    easing.type: Easing.InQuad
                    to: 1
                }
            }

        }

        TimelineFlickable {
            id: timelineFlickable
            anchors.fill: parent
            flickable: (model.hasSelection && !menuToggleButton.pressed && flickable.touchCount < 2) ? null : flickable
        }

        FlickableMouseArea {
            id: flickable
            anchors.fill: parent
            momentumRestX: timelineFlickable.playing ? -1 : 0
        }

        MenuController {
            id: menuController
            x: menuToggleButton.width
            width: parent.width - x
            height: 70
            clip: true
            anchors.bottom: parent.bottom
            opacity: 0
            visible: opacity !== 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        MultiTouchButton {
            id: menuToggleButton
            width: 70
            height: menuController.height
            anchors.bottom: parent.bottom
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(0, 0, 1, 0.5)
                radius: 4
            }

            onClicked: {
                opacity = 0
                menuController.toggle()
            }
        }

        SearchView {
            id: searchView
            anchors.fill: parent
            visible: false
        }

    }

    Component {
        id: stageSpriteComponent
        StageSprite {
            id: stageSprite
            model: myApp.model
            property alias image: image;
            width: image.width
            height: image.height
            Image {
                id: image
                onStatusChanged: {
                    if (status === Image.Ready) {
                        anchorX = width / 2;
                        anchorY = height / 2;
                        for (var j = 0; j < keyframes.length; ++j) {
                            var keyframe = keyframes[j];
                            keyframe.anchorX = anchorX;
                            keyframe.anchorY = anchorY;
                        }
                    }
                }
            }
        }
    }

    property int nextSpriteNr: 0

    function addImage(url)
    {
        var sprite = stageSpriteComponent.createObject(stage.sprites, {"objectName":"sprite " + nextSpriteNr++, "image.source":url});
        model.addSprite(sprite);
    }
}
