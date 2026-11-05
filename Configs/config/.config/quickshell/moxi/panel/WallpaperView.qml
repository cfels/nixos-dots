pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import "../components"

Item {
	id: wallpaperView

	required property WallpaperController controller
	required property Theme theme
	property string fontFamily: ""
	property bool expandedGallery: false
	property bool active: controller.expanded
	property bool initialized: false
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
	function updateActive(): void {
		if (!initialized)
			return
		if (wallpaperView.active) {
			if (wallpaperView.expandedGallery && wallpaperView.controller.currentWallpaper)
				wallpaperView.controller.previewWallpaper = wallpaperView.controller.currentWallpaper
			previewFrame.showPreview()
		} else {
			previewFrame.clearTransition()
		}
		wallpaperView.updateWallpaperHover()
	}
	onActiveChanged: Qt.callLater(wallpaperView.updateActive)
	Component.onCompleted: {
		initialized = true
		updateActive()
	}
	Component.onDestruction: initialized = false

	Connections {
		target: wallpaperView.controller
		function onPreviewWallpaperChanged(): void {
			Qt.callLater(previewFrame.showPreview)
		}
		function onWallThumbsChanged(): void {
			Qt.callLater(previewFrame.showPreview)
		}
		function onWallPreviewsChanged(): void {
			Qt.callLater(previewFrame.showPreview)
		}
		function onExpandedChanged(): void {
			Qt.callLater(wallpaperView.updateWallpaperHover)
		}
		function onWallpapersChanged(): void {
			Qt.callLater(wallpaperView.updateWallpaperHover)
		}
	}

	function updateWallpaperHover(): void {
		if (!wallpaperView.active)
			return
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

		property real ghostProgress: 0
		property bool waitingReady: false
		property int generation: 0
		property var snapshot: null

		function clearTransition(): void {
			++generation
			previewCross.stop()
			waitingReady = false
			ghostProgress = 0
			preview.scale = 1
			previewGhost.source = ""
			snapshot = null
		}
		function applyPreview(source, animated, captured): void {
			previewCross.stop()
			if (captured) {
				snapshot = captured
				previewGhost.source = captured.url
				ghostProgress = 1
			}
			waitingReady = ghostProgress > 0
			// Clear the source before changing decoder type. Otherwise a PNG can
			// briefly be opened as a movie when switching to an animated preview.
			preview.source = ""
			preview.animated = animated
			preview.source = source
			if (!source) {
				clearTransition()
			} else if (preview.ready && waitingReady) {
				waitingReady = false
				previewCross.restart()
			}
		}
		function showPreview(): void {
			if (!wallpaperView.active)
				return
			const path = wallpaperView.controller.previewWallpaper
			const file = wallpaperView.controller.wallpaperSource(path)
			const source = file ? "file://" + file : ""
			const animated = wallpaperView.controller.wallpaperSourceAnimated(path)
			if (source === preview.source && animated === preview.animated) {
				++generation
				return
			}
			const serial = ++generation
			if (preview.ready && visible && width > 0 && height > 0 && !Preferences.reducedMotion) {
				// Freeze the decoded outgoing frame; never start a second GIF decoder.
				if (preview.grabToImage(result => {
					if (serial === previewFrame.generation)
						previewFrame.applyPreview(source, animated, result)
				}))
					return
			}
			applyPreview(source, animated, null)
		}
		Component.onCompleted: Qt.callLater(showPreview)

		SquircleImage {
			id: preview
			anchors.fill: parent
			playing: wallpaperView.active
			radius: 30
			power: 4
			// Stable decode sizes keep the cache warm while panel geometry animates.
			sourceWidth: 560
			sourceHeight: 320
			onReadyChanged: {
				if (ready && previewFrame.waitingReady) {
					previewFrame.waitingReady = false
					previewCross.restart()
				}
			}
		}
		Image {
			id: previewGhost
			anchors.fill: parent
			opacity: previewFrame.ghostProgress
			visible: opacity > 0.001
			cache: false
		}

		ParallelAnimation {
			id: previewCross
			onFinished: {
				previewGhost.source = ""
				previewFrame.snapshot = null
			}

			NumberAnimation {
				target: previewFrame
				property: "ghostProgress"
				from: 1
				to: 0
				duration: Preferences.motion(180)
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: preview
				property: "scale"
				from: 1.02
				to: 1
				duration: Preferences.motion(180)
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
		currentIndex: wallpaperView.controller.wallpapers.indexOf(wallpaperView.controller.currentWallpaper)

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
						const path = wallpaperView.controller.wallpaperThumb(modelData) || (wallpaperView.controller.wallpaperIsVideo(modelData) ? "" : modelData)
						return path.length > 0 ? "file://" + path : ""
					}
					radius: 13
					power: 4
					sourceWidth: wallpaperView.expandedGallery ? 256 : 168
					sourceHeight: wallpaperView.expandedGallery ? 144 : 120
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
					strokeWidth: wallpaperView.controller.hoveredWallpaper === modelData || wallpaperView.controller.currentWallpaper === modelData ? 1.4 : 0
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
