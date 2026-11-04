pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Shapes
import "../components"

Item {
	id: wallpaperView

	required property WallpaperController controller
	required property Theme theme
	property string fontFamily: ""
	property bool expandedGallery: false
	property bool active: controller.expanded
	property int columns: 2
	property real previewHeight: 140
	readonly property bool hovered: gridHover.hovered
	// Scene coordinates stay stable while the grid scrolls under the pointer.
	readonly property point pointerScenePosition: gridHover.point.scenePosition
	readonly property int tileInset: expandedGallery ? 12 : 6
	implicitHeight: expandedGallery ? grid.y + grid.height + 8 + (hint.visible ? hint.implicitHeight : 0) : 0

	TransformWatcher {
		a: wallpaperView.expandedGallery && wallpaperView.Window.window ? wallpaperView.Window.window.contentItem : null
		b: wallpaperView.expandedGallery ? grid : null
		onTransformChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
	}

	onPointerScenePositionChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
	onActiveChanged: Qt.callLater(wallpaperView.updateWallpaperHover)

	Connections {
		target: wallpaperView.controller
		function onExpandedChanged(): void {
			Qt.callLater(wallpaperView.updateWallpaperHover)
		}
		function onWallpapersChanged(): void {
			Qt.callLater(wallpaperView.updateWallpaperHover)
		}
	}

	function updateWallpaperHover(): void {
		let path = ""
		if (wallpaperView.active && gridHover.hovered) {
			const pos = grid.mapFromItem(null, wallpaperView.pointerScenePosition.x, wallpaperView.pointerScenePosition.y)
			const index = grid.indexAt(grid.contentX + pos.x, grid.contentY + pos.y)
			const tile = grid.itemAtIndex(index)
			if (index >= 0 && index < wallpaperView.controller.wallpapers.length && tile && pos.x >= 0 && pos.y >= 0 && pos.x < grid.width && pos.y < grid.height) {
				const local = tile.mapFromItem(grid, pos.x, pos.y)
				const inset = wallpaperView.tileInset
				if (local.x >= inset && local.y >= inset && local.x < tile.width - inset && local.y < tile.height - inset)
					path = wallpaperView.controller.wallpapers[index]
			}
		}
		wallpaperView.controller.hoveredWallpaper = path
		if (path.length > 0)
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
		height: wallpaperView.previewHeight
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
			playing: wallpaperView.active
			radius: 30
			power: 4
			sourceWidth: wallpaperView.expandedGallery ? Math.ceil(previewFrame.width) : 560
			sourceHeight: wallpaperView.expandedGallery ? Math.ceil(previewFrame.height) : 320

			onSourceChanged: Qt.callLater(previewFrame.cross)
			onAnimatedChanged: Qt.callLater(previewFrame.cross)
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
			sourceWidth: wallpaperView.expandedGallery ? Math.ceil(previewFrame.width) : 560
			sourceHeight: wallpaperView.expandedGallery ? Math.ceil(previewFrame.height) : 320
			opacity: previewFrame.ghostProgress
			visible: previewFrame.ghostProgress > 0.001
			playing: visible && wallpaperView.active
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
				duration: 180
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: preview
				property: "scale"
				from: 1.02
				to: 1
				duration: 180
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
		height: wallpaperView.expandedGallery ? Math.ceil(count / wallpaperView.columns) * cellHeight : Math.max(0, hint.y - 8 - y)
		clip: !wallpaperView.expandedGallery
		interactive: !wallpaperView.expandedGallery
		cellWidth: Math.max(1, Math.floor(width / wallpaperView.columns))
		cellHeight: wallpaperView.expandedGallery ? Math.max(1, Math.round((cellWidth - wallpaperView.tileInset * 2) * 9 / 16) + wallpaperView.tileInset * 2) : Math.max(1, Math.floor(height / 2))
		boundsBehavior: Flickable.StopAtBounds
		flickDeceleration: 1400
		maximumFlickVelocity: 2600
		model: wallpaperView.controller.wallpapers

		HoverHandler {
			id: gridHover
			parent: grid
			onHoveredChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
		}

		onContentXChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
		onContentYChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
		onWidthChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
		onHeightChanged: Qt.callLater(wallpaperView.updateWallpaperHover)
		onCountChanged: Qt.callLater(wallpaperView.updateWallpaperHover)

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
			enabled: !wallpaperView.expandedGallery
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
				width: parent.width - wallpaperView.tileInset * 2
				height: parent.height - wallpaperView.tileInset * 2
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
					source: {
						const path = wallpaperView.controller.wallpaperIsVideo(modelData) ? wallpaperView.controller.wallpaperThumb(modelData) : modelData
						return path.length > 0 ? "file://" + path : ""
					}
					radius: 13
					power: 4
					sourceWidth: wallpaperView.expandedGallery ? Math.ceil(thumb.width) : 168
					sourceHeight: wallpaperView.expandedGallery ? Math.ceil(thumb.height) : 120
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
					enabled: !wallpaperView.expandedGallery
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
		text: "install Quickshell to set wallpapers"
	}
}
