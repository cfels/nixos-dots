import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components"

PanelWindow {
	id: geom

	Theme {
		id: theme
	}

	signal selected(int x, int y, int width, int height)
	signal cancelled()

	property string freezeSource: ""

	readonly property color accent: theme.accent
	readonly property color shade: theme.background
	readonly property real ropeInset: geomRect.borderWidth * 3.2
	readonly property int screenX: geom.screen ? geom.screen.x : 0
	readonly property int screenY: geom.screen ? geom.screen.y : 0

	function pullPoint(cornerX, cornerY): var {
		var handleX = cornerX < geomRect.width / 2 ? geomRect.anchor1X : geomRect.anchor2X
		var handleY = cornerY < geomRect.height / 2 ? geomRect.anchor1Y : geomRect.anchor2Y

		return { "x": handleX, "y": handleY }
	}


	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	focusable: true
	color: "transparent"

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	Item {
		anchors.fill: parent
		focus: true
		Keys.onEscapePressed: geom.cancelled()
	}

	Image {
		anchors.fill: parent
		source: geom.freezeSource
		fillMode: Image.PreserveAspectCrop
		asynchronous: false
		cache: false
		smooth: true
	}

	Rectangle {
		id: geomRect

		anchors.fill: parent
		color: "transparent"

		property int anchorX: 0
		property int anchorY: 0
		property int anchor1X: width / 2
		property int anchor1Y: height / 2
		property int anchor2X: width / 2
		property int anchor2Y: height / 2
		property int anchorDx: anchor2X - anchor1X
		property int anchorDy: anchor2Y - anchor1Y
		property int borderWidth: 6

		onAnchor1XChanged: canvas.requestPaint()
		onAnchor1YChanged: canvas.requestPaint()
		onAnchor2XChanged: canvas.requestPaint()
		onAnchor2YChanged: canvas.requestPaint()

		Canvas {
			id: canvas

			anchors.fill: parent

			onPaint: {
				var ctx = getContext("2d")
				var handleRadius = 10
				var handles = [
					[geomRect.anchor1X, geomRect.anchor1Y],
					[geomRect.anchor2X, geomRect.anchor1Y],
					[geomRect.anchor1X, geomRect.anchor2Y],
					[geomRect.anchor2X, geomRect.anchor2Y]
				]

				ctx.reset()
				ctx.fillStyle = geom.shade
				ctx.globalAlpha = 0.8
				ctx.fillRect(0, 0, parent.width, parent.height)
				ctx.globalAlpha = 1
				ctx.fillStyle = geom.accent
				ctx.fillRect(
					geomRect.anchor1X - geomRect.borderWidth,
					geomRect.anchor1Y - geomRect.borderWidth,
					geomRect.anchorDx + geomRect.borderWidth * 2,
					geomRect.anchorDy + geomRect.borderWidth * 2
				)

				ctx.clearRect(
					geomRect.anchor1X,
					geomRect.anchor1Y,
					geomRect.anchorDx,
					geomRect.anchorDy
				)

				ctx.strokeStyle = geom.accent
				ctx.lineWidth = geomRect.borderWidth
				ctx.strokeRect(
					geomRect.anchor1X,
					geomRect.anchor1Y,
					geomRect.anchorDx,
					geomRect.anchorDy
				)

				for (var i = 0; i < handles.length; ++i) {
					ctx.beginPath()
					ctx.arc(handles[i][0], handles[i][1], handleRadius, 0, 2 * Math.PI)
					ctx.fillStyle = geom.accent
					ctx.fill()

					ctx.beginPath()
					ctx.arc(handles[i][0], handles[i][1], handleRadius - 3.4, 0, 2 * Math.PI)
					ctx.fillStyle = geom.shade
					ctx.fill()

					ctx.beginPath()
					ctx.arc(handles[i][0], handles[i][1], handleRadius - 6, 0, 2 * Math.PI)
					ctx.fillStyle = geom.accent
					ctx.fill()
				}
			}
		}

		Rope {
			anchors.fill: parent
			color: geom.accent
			anchorX: 0
			anchorY: 0
			pullX: geom.pullPoint(0, 0).x
			pullY: geom.pullPoint(0, 0).y
		}

		Rope {
			anchors.fill: parent
			color: geom.accent
			anchorX: parent.width
			anchorY: 0
			pullX: geom.pullPoint(parent.width, 0).x
			pullY: geom.pullPoint(parent.width, 0).y
		}

		Rope {
			anchors.fill: parent
			color: geom.accent
			anchorX: 0
			anchorY: parent.height
			pullX: geom.pullPoint(0, parent.height).x
			pullY: geom.pullPoint(0, parent.height).y
		}

		Rope {
			anchors.fill: parent
			color: geom.accent
			anchorX: parent.width
			anchorY: parent.height
			pullX: geom.pullPoint(parent.width, parent.height).x
			pullY: geom.pullPoint(parent.width, parent.height).y
		}
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		cursorShape: Qt.CrossCursor

		onPressed: (mouse) => {
			if (mouse.button === Qt.RightButton) {
				geom.cancelled()
				return
			}

			geomRect.anchorX = mouse.x
			geomRect.anchorY = mouse.y

			geomRect.anchor1X = mouse.x
			geomRect.anchor1Y = mouse.y
			geomRect.anchor2X = mouse.x
			geomRect.anchor2Y = mouse.y
		}

		onPositionChanged: (mouse) => {
			geomRect.anchor1X = Math.min(geomRect.anchorX, mouse.x)
			geomRect.anchor1Y = Math.min(geomRect.anchorY, mouse.y)
			geomRect.anchor2X = Math.max(geomRect.anchorX, mouse.x)
			geomRect.anchor2Y = Math.max(geomRect.anchorY, mouse.y)
		}

		onReleased: (mouse) => {
			if (geomRect.anchorDx < 4 || geomRect.anchorDy < 4) {
				geom.cancelled()
				return
			}

			geom.selected(
				geom.screenX + geomRect.anchor1X,
				geom.screenY + geomRect.anchor1Y,
				geomRect.anchorDx,
				geomRect.anchorDy
			)
		}
	}
}
