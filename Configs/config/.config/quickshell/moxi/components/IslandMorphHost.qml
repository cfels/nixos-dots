import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Single-window bar + morphing panel. The bar pill and the panel are children of
// the SAME surface, so the panel's collapsed geometry IS the bar's geometry and
// nothing can render behind, clipped, or disjointed from it.
PanelWindow {
	id: host

	property string phase: "collapsed"       // collapsed | morphing | expanded
	property bool open: false
	property string view: ""                 // launcher | clipboard | panel
	property real barHeight: 46
	property real barTop: 6
	property real panelWidth: 920
	property real panelHeight: 420
	property real panelTop: 50
	property color tint: Qt.rgba(0.12, 0.12, 0.15, 0.85)
	property color borderColor: Qt.rgba(1, 1, 1, 0.12)
	property color glowColor: Qt.rgba(1, 1, 1, 0.05)
	property real panelRadius: 30

	// content slots: bar children go in the island, panel children in the card
	default property alias content: panelContent.data
	property alias barContent: islandRow.data
	property alias barItem: islandRow

	// bar geometry, measured from the island itself
	readonly property real islandWidth: islandRow.implicitWidth + 30
	readonly property real islandHeight: 38
	readonly property real islandTop: (host.barHeight - host.islandHeight) / 2

	// absolute bounding box of the bar element in this surface's coordinates.
	// the surface is anchored at (0, barTop) and full width, so this is exactly
	// the bar's screen slot: no centring assumptions, no offset drift.
	readonly property var barRect: ({
		x: islandRow.x,
		y: host.barTop + islandRow.y,
		width: host.islandWidth,
		height: host.islandHeight
	})

	// collapse geometry: 1:1 lock onto the bar rect before animating outward
	readonly property real collapsedLeft: host.barRect.x
	readonly property real collapsedTop: host.barRect.y - host.barTop
	readonly property real collapsedWidth: host.barRect.width
	readonly property real collapsedHeight: host.barRect.height

	signal dismissed()

	function dismiss(): void {
		host.open = false
		host.dismissed()
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: host.barTop
	// surface blooms with the morph so the compositor blurs the real shape
	implicitHeight: host.card.y + host.card.height + 40
	// reserved strip stays bar-sized while the surface is taller
	exclusionMode: ExclusionMode.Normal
	exclusiveZone: host.barTop + host.barHeight + 6
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell"
	WlrLayershell.keyboardFocus: host.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	focus: true
	color: "transparent"
	// input region follows the shape: island when collapsed, card when open
	mask: Region { item: host.open ? card : islandRow }

	// one spring drives position, size and radius together -> the bloom
	Behavior on x {
		SpringAnimation { spring: 340; damping: 27; mass: 0.9; epsilon: 0.1 }
	}

	Behavior on y {
		SpringAnimation { spring: 340; damping: 27; mass: 0.9; epsilon: 0.1 }
	}

	Behavior on width {
		SpringAnimation { spring: 340; damping: 27; mass: 0.9; epsilon: 0.1 }
	}

	Behavior on height {
		SpringAnimation { spring: 340; damping: 27; mass: 0.9; epsilon: 0.1 }
	}

	Behavior on radius {
		SpringAnimation { spring: 340; damping: 27; mass: 0.9; epsilon: 0.1 }
	}

	Item {
		id: card

		x: host.open ? (host.width - host.panelWidth) / 2 : host.collapsedLeft
		y: host.open ? host.panelTop : host.collapsedTop
		width: host.open ? host.panelWidth : host.collapsedWidth
		height: host.open ? host.panelHeight : host.collapsedHeight
		property real radius: host.open ? host.panelRadius : host.collapsedHeight / 2
		opacity: host.open ? 1 : 0

		Behavior on opacity {
			NumberAnimation { duration: host.open ? 140 : 90 }
		}

		Rectangle {
			anchors.fill: parent
			radius: card.radius
			color: host.tint
			border.width: 1
			border.color: host.borderColor
		}

		Rectangle {
			anchors.fill: parent
			anchors.margins: 1
			radius: Math.max(0, card.radius - 1)
			color: "transparent"
			border.width: 1
			border.color: host.glowColor
		}

		Item {
			id: panelContent

			anchors.fill: parent
			anchors.margins: 20
			opacity: host.open ? 1 : 0
			enabled: host.open

			Behavior on opacity {
				SequentialAnimation {
					PauseAnimation { duration: host.open ? 90 : 0 }
					NumberAnimation { duration: host.open ? 170 : 70 }
				}
			}
		}
	}

	// the bar/island itself: always present, interactive while collapsed
	Row {
		id: islandRow

		x: (host.width - host.islandWidth) / 2 + 15
		y: host.islandTop
		height: host.islandHeight
		spacing: 7
	}

	// state machine: collapsed -> morphing -> expanded, and back
	onOpenChanged: {
		host.phase = "morphing"
		phaseTimer.restart()

		if (host.open) host.forceActiveFocus()
	}

	Timer {
		id: phaseTimer

		interval: 360
		onTriggered: host.phase = host.open ? "expanded" : "collapsed"
	}

	// global ESC: collapse first, then hand focus back to the desktop
	Keys.onPressed: (event) => {
		if (event.key === Qt.Key_Escape) {
			host.dismiss()
			event.accepted = true
		}
	}

	Keys.onEscapePressed: host.dismiss()
}
