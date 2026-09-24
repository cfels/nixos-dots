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
	property bool ready: image.status === Image.Ready

	Image {
		id: image

		visible: false
		anchors.fill: parent
		source: root.source
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		cache: true
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
		source: image
		maskEnabled: true
		maskSource: mask
	}
}
