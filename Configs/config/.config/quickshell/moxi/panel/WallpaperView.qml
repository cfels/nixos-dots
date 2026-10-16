import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../components"

Item {
	id: wallpaperView

	required property WallpaperController controller
	required property Theme theme
	property string fontFamily: ""
	readonly property bool hovered: gridHover.hovered

	function updateWallpaperHover(pos): void {
		if (!wallpaperView.controller.expanded || wallpaperView.controller.wallpapers.length === 0)
			return
		var cw = grid.cellWidth
		var ch = grid.cellHeight

		if (cw <= 0 || ch <= 0)
			return
		var columns = Math.max(1, Math.floor(grid.width / cw))
		var col = Math.floor((grid.contentX + pos.x) / cw)
		var row = Math.floor((grid.contentY + pos.y) / ch)
		var index = row * columns + col

		if (col < 0 || col >= columns || index < 0 || index >= wallpaperView.controller.wallpapers.length) {
			wallpaperView.controller.hoveredWallpaper = ""
			return
		}

		var path = wallpaperView.controller.wallpapers[index]

		if (wallpaperView.controller.hoveredWallpaper === path)
			return
		wallpaperView.controller.hoveredWallpaper = path
		wallpaperView.controller.previewWallpaper = path
	}

	Text {
		id: wallTitle

		color: wallpaperView.theme.foreground
		font.family: wallpaperView.fontFamily
		font.pixelSize: 14
		font.weight: Font.DemiBold
		text: "Wallpaper"
	}

	Rectangle {
		id: previewFrame

		anchors.top: wallTitle.bottom
		anchors.topMargin: 10
		anchors.left: parent.left
		anchors.right: parent.right
		height: 140
		color: "transparent"
		clip: true

		property string shownSource: ""
		property bool shownAnimated: false
		property string previousSource: ""
		property bool previousAnimated: false
		property real ghostProgress: 0
		property bool waitingReady: false

		function cross(): void {
			const nextSource = preview.source
			const nextAnimated = preview.animated

			if (nextSource === previewFrame.shownSource && nextAnimated === previewFrame.shownAnimated)
				return
			if (previewFrame.shownAnimated) {
				previewFrame.previousSource = previewFrame.shownSource
				previewFrame.previousAnimated = true
			} else {
				previewFrame.previousAnimated = false
				previewFrame.previousSource = previewFrame.shownSource
			}

			previewFrame.shownSource = nextSource
			previewFrame.shownAnimated = nextAnimated

			previewCross.stop()

			if (nextSource.length === 0) {
				previewFrame.waitingReady = false
				previewFrame.ghostProgress = 0
				return
			}

			previewFrame.ghostProgress = 1

			if (preview.ready) {
				previewFrame.waitingReady = false
				previewCross.restart()
			} else {
				previewFrame.waitingReady = true
			}
		}

		SquircleImage {
			id: preview

			anchors.fill: parent
			source: wallpaperView.controller.wallpaperSource(wallpaperView.controller.previewWallpaper).length > 0 ? "file://" + wallpaperView.controller.wallpaperSource(wallpaperView.controller.previewWallpaper) : ""
			animated: wallpaperView.controller.wallpaperSourceAnimated(wallpaperView.controller.previewWallpaper)
			playing: wallpaperView.controller.expanded
			radius: 30
			power: 4
			sourceWidth: 560
			sourceHeight: 320

			onSourceChanged: previewFrame.cross()
			onReadyChanged: {
				if (ready && previewFrame.waitingReady) {
					previewFrame.waitingReady = false
					previewCross.restart()
				}
			}
			Component.onCompleted: {
				previewFrame.shownSource = preview.source
				previewFrame.shownAnimated = preview.animated
			}
		}

		SquircleImage {
			id: previewGhost

			anchors.fill: parent
			source: previewFrame.previousSource
			animated: previewFrame.previousAnimated
			radius: 30
			power: 4
			sourceWidth: 560
			sourceHeight: 320
			opacity: previewFrame.ghostProgress
			visible: previewFrame.ghostProgress > 0.001
			playing: visible && wallpaperView.controller.expanded
			layer.enabled: visible
			layer.effect: MultiEffect {
				blurEnabled: true
				blur: (1 - previewFrame.ghostProgress) * 0.85
				blurMax: 24
			}
		}

		ParallelAnimation {
			id: previewCross

			NumberAnimation {
				target: previewFrame
				property: "ghostProgress"
				from: 1
				to: 0
				duration: 430
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: preview
				property: "scale"
				from: 1.02
				to: 1
				duration: 430
				easing.type: Easing.OutCubic
			}
		}
	}

	GridView {
		id: grid

		anchors.top: previewFrame.bottom
		anchors.topMargin: 12
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: hint.top
		anchors.bottomMargin: 8
		clip: true
		cellWidth: Math.max(1, Math.floor(width / 2))
		cellHeight: Math.max(1, Math.floor(height / 2))
		boundsBehavior: Flickable.StopAtBounds
		flickDeceleration: 1400
		maximumFlickVelocity: 2600
		model: wallpaperView.controller.wallpapers

		HoverHandler {
			id: gridHover

			onPointChanged: wallpaperView.updateWallpaperHover(gridHover.point.position)
			onHoveredChanged: if (!hovered)
				wallpaperView.controller.hoveredWallpaper = ""
		}

		function glideBy(delta): void {
			var maximum = Math.max(0, contentHeight - height)
			var base = gridScrollAnimation.running ? gridScrollAnimation.to : contentY

			gridScrollAnimation.to = Math.max(0, Math.min(maximum, base + delta))
			gridScrollAnimation.restart()
		}

		NumberAnimation {
			id: gridScrollAnimation

			target: grid
			property: "contentY"
			duration: 300
			easing.type: Easing.OutCubic
		}

		WheelHandler {
			onWheel: wheel => {
				var step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * 2 : wheel.angleDelta.y / 120 * grid.cellHeight

				if (step === 0)
					return
				grid.glideBy(-step)
				wheel.accepted = true
			}
		}

		delegate: Item {
			required property var modelData

			width: grid.cellWidth
			height: grid.cellHeight
			z: wallpaperView.controller.hoveredWallpaper === modelData ? 2 : 1

			Rectangle {
				id: thumb

				anchors.centerIn: parent
				width: parent.width - 12
				height: parent.height - 12
				radius: 14
				color: "transparent"
				scale: wallpaperView.controller.hoveredWallpaper === modelData ? 1.06 : 1

				Behavior on scale {
					NumberAnimation {
						duration: 340
						easing.type: Easing.OutBack
						easing.overshoot: 1.4
					}
				}

				SquircleImage {
					anchors.fill: parent
					source: "file://" + (wallpaperView.controller.wallpaperIsVideo(modelData) ? wallpaperView.controller.wallpaperThumb(modelData) : modelData)
					radius: 13
					power: 4
					sourceWidth: 168
					sourceHeight: 120
				}

				Rectangle {
					anchors.right: parent.right
					anchors.top: parent.top
					anchors.margins: 5
					width: wallpaperView.controller.wallpaperIsVideo(modelData) ? 15 : 22
					height: 15
					radius: 7.5
					color: Qt.rgba(0, 0, 0, 0.55)
					visible: wallpaperView.controller.wallpaperIsVideo(modelData) || wallpaperView.controller.wallpaperIsAnimated(modelData)

					Shape {
						anchors.centerIn: parent
						anchors.verticalCenterOffset: -0.5
						anchors.horizontalCenterOffset: 0.6
						width: 7
						height: 8
						visible: wallpaperView.controller.wallpaperIsVideo(modelData)
						preferredRendererType: Shape.CurveRenderer

						ShapePath {
							strokeColor: "transparent"
							fillColor: "white"
							startX: 0
							startY: 6.6
							PathLine {
								x: 0
								y: 1.4
							}
							PathQuad {
								controlX: 0
								controlY: 0
								x: 1.22
								y: 0.69
							}
							PathLine {
								x: 5.78
								y: 3.31
							}
							PathQuad {
								controlX: 7
								controlY: 4
								x: 5.78
								y: 4.69
							}
							PathLine {
								x: 1.22
								y: 7.31
							}
							PathQuad {
								controlX: 0
								controlY: 8
								x: 0
								y: 6.6
							}
						}
					}

					Text {
						anchors.centerIn: parent
						visible: !wallpaperView.controller.wallpaperIsVideo(modelData)
						color: "white"
						font.family: wallpaperView.fontFamily
						font.pixelSize: 8
						font.weight: Font.Bold
						text: "GIF"
					}
				}

				Squircle {
					anchors.fill: parent
					power: 4
					radius: 14
					fillColor: "transparent"
					strokeColor: wallpaperView.theme.accent
					strokeWidth: wallpaperView.controller.hoveredWallpaper === modelData || wallpaperView.controller.previewWallpaper === modelData ? 1.4 : 0
				}

				TapHandler {
					onTapped: {
						wallpaperView.controller.previewWallpaper = modelData
						wallpaperView.controller.setWallpaper(modelData)
					}
				}

				WheelHandler {
					onWheel: wheel => wheel.accepted = false
				}
			}
		}
	}

	Text {
		id: hint

		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		visible: !wallpaperView.controller.wallpaperTool
		color: theme.danger
		font.family: wallpaperView.fontFamily
		font.pixelSize: 11
		text: "install awww to set wallpapers"
	}
}
