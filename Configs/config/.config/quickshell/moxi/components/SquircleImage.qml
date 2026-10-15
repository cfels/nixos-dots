import QtQuick
import QtQuick.Effects

Item {
	id: root

	property string source: ""
	property real radius: 16
	property real power: 4
	property real imageScale: 1
	property int sourceWidth: 400
	property int sourceHeight: 400
	property bool animated: false
	property bool playing: true
	property bool ready: root.animated ? animation.status === AnimatedImage.Ready : image.status === Image.Ready

	Image {
		id: image

		visible: false
		anchors.fill: parent
		source: root.animated ? "" : root.source
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		cache: true
		scale: root.imageScale
		sourceSize.width: root.sourceWidth
		sourceSize.height: root.sourceHeight
	}

	AnimatedImage {
		id: animation

		visible: false
		anchors.fill: parent
		source: root.animated ? root.source : ""
		fillMode: Image.PreserveAspectCrop
		playing: root.animated && root.playing
		cache: false
		scale: root.imageScale
		sourceSize.width: root.sourceWidth
		sourceSize.height: root.sourceHeight
	}

	Squircle {
		id: mask

		visible: false
		layer.enabled: true
		anchors.fill: parent
		power: root.power
		radius: root.radius
		fillColor: "white"
	}

	MultiEffect {
		anchors.fill: parent
		source: root.animated ? animation : image
		maskEnabled: true
		maskSource: mask
	}
}
