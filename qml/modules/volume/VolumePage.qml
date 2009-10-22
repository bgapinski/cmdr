import Qt 4.6
import WesControl 1.0
Item {
    anchors.fill: parent
    anchors.horizontalCenter: parent.horizontalCenter
    Item {
        anchors.fill: parent
        //z: volumeController.connected || true? -1 : 1
        //opacity: volumeController.connected || true? 0 : 1
        z: -1
        opacity: 0
        Rectangle {
            color: "black"
            radius: 20
            opacity: 0.95
            anchors.fill: parent
            anchors.horizontalCenter: parent.horizontalCenter
            MouseRegion {
                anchors.fill: parent
            }
        }
        Text {
            id: unableToConnectText
            text: "Unable to connect to volume controller"
            font.family: "Myriad Pro"
            font.pointSize: 40
            color: "white"
            wrap: true
            width: parent.width-30
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 100
            horizontalAlignment: "AlignHCenter"
        }
        Text {
            text: "Please call #4959 for assistance"
            font.family: "Myriad Pro"
            font.pointSize: 20
            color: "white"
            width: parent.width-30
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: unableToConnectText.bottom
            anchors.topMargin: 50
            horizontalAlignment: "AlignHCenter"
        }
    }

    Image {
        id: backgroundImage
        source: "images/background.png"
        height: 558
        width: 438
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }
    Item {
        id: sliderContainer
        y: 20
        x: 368
        height: 465
        width: 16

        Image {
            property double level
            id: sliderImage
            //y: 433 * (0.975 - volumecontroller.volume)
            y: NumberAnimation {
                duration: 500
                easing: "easeOutBounce"
            }
            level: (100-Math.round(y/(433) * 100 + 2.5))/100
            source: "images/slider.png"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 51.4

        }
        Timer {
            interval: 1000
            onTriggered: if(sliderMouseRegion.state != "dragging")sliderImage.y = 433 * (0.975 - volumecontroller.volume);
        }
        Binding { target: volumecontroller; property: "volume"; value: sliderImage.level }
        MouseRegion {
            id: sliderMouseRegion
            width: 64
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            drag.target: sliderImage
            drag.axis: "YAxis"
            drag.minimumY: -sliderImage.height/2 + 14
            drag.maximumY: parent.height - sliderImage.height/2 - 17
            onPressed: {
                sliderMouseRegion.state = "dragging"
            }
            onReleased: {
                sliderMouseRegion.state = ""
            }
            states: [
                State {
                    name: "dragging"
                }
            ]
        }
    }


    MouseRegion {
        id: muteButtonArea
        y: 500
        width:69
        height: 31
        x: 343
        onClicked: {
            volumecontroller.mute = muteLightRect.state == ""
            //muteLightRect.state = muteLightRect.state == "" ? "muteOnState" : ""
        }
        onPressed: {
            mutePressIndicator.opacity = 0.4
        }
        onReleased: {
            mutePressIndicator.opacity =  0.0
        }
        Rectangle {
            id: mutePressIndicator
            color: "#000000"
            anchors.fill: parent
            opacity: 0.0
        }
        Rectangle {
            id: muteLightRect
            color: "#E82725"
            opacity: 0.0
            opacity: SequentialAnimation {
                id: muteLightAnimation
                running: false
                repeat: true
                NumberAnimation {
                    to: 0.6
                    duration: 600
                }
                PauseAnimation { duration: 1000 }
                NumberAnimation {
                    to: 0.0
                    duration: 600
                }
            }
            height: 8.5
            width: 38
            y: 6
            radius: 3
            anchors.horizontalCenter: parent.horizontalCenter
            state: volumecontroller.mute ? "muteOnState" : ""
            states: [
                State {
                    name: ""
                    PropertyChanges {
                        target: muteLightAnimation
                        running: false
                    }
                    PropertyChanges {
                        target: muteLightRect
                        opacity: 0
                    }
                    PropertyChanges {
                        target: blurredSpeakerImage
                        opacity: 1
                    }
                },
                State {
                    name: "muteOnState"
                    //when: volumecontroller.mute == true
                    PropertyChanges {
                        target: muteLightAnimation
                        running: true
                    }
                    PropertyChanges {
                        target: muteLightRect
                        opacity: 0
                    }
                    PropertyChanges {
                        target: blurredSpeakerImage
                        opacity: 0
                    }
                }
            ]
            //Binding { target: volumecontroller; property: "mute"; value: volumecontroller.state == "muteOnState" }
        }
    }
    Image {
        id: blurredSpeakerImage
        width: 162
        height: 160
        y: 287
        x: 93
        source: "images/blurred_speaker.png"
        opacity: SequentialAnimation {
            running: muteLightRect.state != "muteOnState"
            repeat: true
            NumberAnimation { to: sliderImage.level; duration: 300 }
            NumberAnimation { to: 0; duration: 300 }
            PauseAnimation { duration: 400 }
            NumberAnimation { to: sliderImage.level; duration: 300 }
            NumberAnimation { to: 0; duration: 300 }
            PauseAnimation { duration: 400 }
            NumberAnimation {to: sliderImage.level; duration: 300 }
            PauseAnimation { duration: 100 }
            NumberAnimation {to: 0; duration: 300 }
        }
    }
}
