import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

PanelWindow {
	id: popover

	// global-screen rect of the island this panel grows out of
	required property var sourceRect
	property bool isOpen: false
	property real panelWidth: 660
	property real panelHeight: 460
	property real gap: 8
	property color tint: Qt.rgba(0.12, 0.12, 0.15, 0.85)
	property color borderColor: Qt.rgba(1, 1, 1, 0.12)
	property color glowColor: Qt.rgba(1, 1, 1, 0.05)
	property real cornerRadius: 30

	// collapse to exactly the island rect: non-uniform scale, same centre axis
	readonly property real islandX: popover.isOpen || !sourceRect ? 1 : sourceRect.width / popover.panelWidth
	readonly property real islandY: popover.isOpen || !sourceRect ? 1 : sourceRect.height / popover.panelHeight
	property real zoomX: popover.islandX
	property real zoomY: popover.islandY
	property real contentZoom: popover.isOpen ? 1 : 0.98
	property bool closing: false

	// children declared on the panel are mounted inside the card, not the window
	default property alias content: contentLayer.data

	readonly property real panelY: sourceRect ? Math.round(sourceRect.y + sourceRect.height + popover.gap) : 0
	// island centre in card-local coordinates = the zoom vector
	readonly property real originX: popover.panelWidth / 2
	readonly property real originY: sourceRect ? -(popover.gap + sourceRect.height / 2) : 0

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: popover.panelY
	// always mapped like the power/emoji windows: 1px strip while closed
	implicitHeight: popover.isOpen || popover.closing ? popover.panelHeight + 60 : 1
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"
	WlrLayershell.keyboardFocus: popover.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: inputArea }

	// stiffness 380 / mass 0.8 / damping 30 -> ratio 0.86, ~250 ms, light bounce
	Behavior on zoomX {
		SpringAnimation { spring: 380; damping: 30; mass: 0.8; epsilon: 0.1 }
	}

	Behavior on zoomY {
		SpringAnimation { spring: 380; damping: 30; mass: 0.8; epsilon: 0.1 }
	}

	Behavior on contentZoom {
		SpringAnimation { spring: 380; damping: 30; mass: 0.8; epsilon: 0.1 }
	}

	// closing guard: collapse first, drop the surface only once the spring settled
	onIsOpenChanged: {
		if (popover.isOpen) {
			popover.closing = false
			hideTimer.stop()
			return
		}

		popover.closing = true
		hideTimer.restart()
	}

	Timer {
		id: hideTimer

		interval: 340
		onTriggered: popover.closing = false
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		y: 0
		width: popover.panelWidth
		height: popover.panelHeight

		Item {
			id: cardSource

			width: cardHost.width
			height: cardHost.height

			Item {
				id: glass

				x: 0
				y: 0
				width: cardSource.width
				height: cardSource.height
				opacity: popover.isOpen ? 1 : 0
				transform: Scale {
					origin.x: popover.originX
					origin.y: popover.originY
					xScale: popover.zoomX
					yScale: popover.zoomY
				}

				Behavior on opacity {
					NumberAnimation { duration: popover.isOpen ? 120 : 80 }
				}

				Rectangle {
					anchors.fill: parent
					radius: popover.cornerRadius
					color: popover.tint
					border.width: 1
					border.color: popover.borderColor
				}

				Rectangle {
					anchors.fill: parent
					anchors.margins: 1
					radius: popover.cornerRadius - 1
					color: "transparent"
					border.width: 1
					border.color: popover.glowColor
				}
			}

			Item {
				id: contentLayer

				x: 20
				y: 20
				width: cardSource.width - 40
				height: cardSource.height - 40
				opacity: popover.isOpen ? 1 : 0
				enabled: popover.isOpen
				transform: Scale {
					origin.x: cardSource.width / 2
					origin.y: 0
					xScale: popover.contentZoom
					yScale: popover.contentZoom
				}

				Behavior on opacity {
					SequentialAnimation {
						PauseAnimation { duration: popover.isOpen ? 80 : 0 }
						NumberAnimation { duration: popover.isOpen ? 170 : 70 }
					}
				}
			}
		}
	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		y: cardHost.y
		width: popover.isOpen ? cardHost.width : 0
		height: popover.isOpen ? cardHost.height : 0
	}
}
