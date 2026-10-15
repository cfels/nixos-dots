pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

PanelWindow {
	id: island

	required property var barWindow
	property string mode: ""
	readonly property bool expanded: mode !== ""
	readonly property int collapseDuration: 240
	property real expansion: expanded ? 1 : 0
	readonly property real progress: Math.max(0, Math.min(1, expansion))
	property alias launcherHost: launcherPane
	property alias emojiHost: emojiPane
	property alias clipboardHost: clipboardPane
	property alias panelHost: panelPane
	property alias powerHost: powerPane

	property bool armed: false
	property bool geometryEnabled: false
	property bool wasExpanded: false
	property bool captured: false
	property real originWidth: 210
	property real originHeight: 38
	property real originTop: 4
	property color originColor: "transparent"
	property color originBorder: "transparent"
	readonly property real targetWidth: mode === "panel" ? 920 : mode === "power" ? 360 : mode === "emoji" ? 560 : mode === "clipboard" ? 680 : 660
	readonly property real targetHeight: mode === "panel" ? 420 : mode === "power" ? 150 : mode === "emoji" ? 440 : 460

	function captureBar(): void {
		geometryEnabled = false
		armed = false
		originWidth = barWindow.pillWidth
		originHeight = barWindow.pillHeight
		originTop = barWindow.pillTop
		originColor = barWindow.pillColor
		originBorder = barWindow.pillBorderColor
		captured = true
	}

	onModeChanged: {
		if (mode === "") {
			wasExpanded = false
			return
		}
		if (wasExpanded) return
		if (expansion > 0.001) {
			wasExpanded = true
			captured = false
			geometryEnabled = true
			armed = true
			return
		}
		if (!captured) captureBar()
		captured = false
		wasExpanded = true
		Qt.callLater(function() {
			if (island.mode === "") return
			island.geometryEnabled = true
			island.armed = true
		})
	}

	anchors { top: true; left: true; right: true }
	screen: barWindow.screen
	margins.top: barWindow.barTopMargin
	implicitHeight: 650
	visible: expanded || expansion > 0.001
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: expanded && mode !== "panel" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: surface }

	Theme { id: theme }

	Behavior on expansion {
		id: expansionMotion
		NumberAnimation {
			duration: expansionMotion.targetValue === 0 ? island.collapseDuration : 560
			easing.type: Easing.OutCubic
		}
	}

	component Pane: Item {
		id: pane
		property bool active: false
		property real presence: active ? 1 : 0
		opacity: presence
		visible: presence > 0.001
		enabled: active
		clip: true
		transform: Translate { y: (1 - pane.presence) * 8 }
		Behavior on presence {
			NumberAnimation { duration: pane.active ? 240 : 120; easing.type: Easing.OutCubic }
		}
	}

	Rectangle {
		id: surface
		anchors.horizontalCenter: parent.horizontalCenter
		y: island.expanded ? island.originTop : island.barWindow.pillTop
		width: island.expanded ? (island.armed ? island.targetWidth : island.originWidth) : island.barWindow.pillWidth
		height: island.expanded ? (island.armed ? island.targetHeight : island.originHeight) : island.barWindow.pillHeight
		radius: island.expanded && island.armed ? 36 : island.barWindow.pillHeight / 2
		color: island.expanded ? (island.armed ? Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.78) : island.originColor) : island.barWindow.pillColor
		border.color: island.expanded ? (island.armed ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12) : island.originBorder) : island.barWindow.pillBorderColor
		border.width: 1
		clip: true
		opacity: Math.min(1, island.progress * 3)

		Behavior on width {
			id: widthMotion
			enabled: island.geometryEnabled
			NumberAnimation {
				duration: widthMotion.targetValue === island.barWindow.pillWidth ? island.collapseDuration : 560
				easing.type: widthMotion.targetValue === island.barWindow.pillWidth ? Easing.OutCubic : Easing.OutBack
				easing.overshoot: 0.7
			}
		}
		Behavior on height {
			id: heightMotion
			enabled: island.geometryEnabled
			NumberAnimation {
				duration: heightMotion.targetValue === island.barWindow.pillHeight ? island.collapseDuration : 560
				easing.type: heightMotion.targetValue === island.barWindow.pillHeight ? Easing.OutCubic : Easing.OutBack
				easing.overshoot: 0.7
			}
		}
		Behavior on y { enabled: island.geometryEnabled; NumberAnimation { duration: island.expanded ? 460 : island.collapseDuration; easing.type: Easing.OutCubic } }
		Behavior on radius { id: radiusMotion; enabled: island.geometryEnabled; NumberAnimation { duration: radiusMotion.targetValue === 36 ? 480 : island.collapseDuration; easing.type: Easing.OutCubic } }
		Behavior on color { enabled: island.geometryEnabled; ColorAnimation { duration: island.expanded ? 440 : island.collapseDuration } }
		Behavior on border.color { enabled: island.geometryEnabled; ColorAnimation { duration: island.expanded ? 440 : island.collapseDuration } }

		Item {
			id: content
			anchors.fill: parent
			opacity: Math.max(0, (island.progress - 0.2) / 0.8)
			layer.enabled: island.progress > 0.001 && island.progress < 0.999
			layer.effect: MultiEffect {
				blurEnabled: true
				blurMax: 20
				blur: 0.65 * (1 - island.progress)
				autoPaddingEnabled: false
			}
			Pane { id: launcherPane; anchors.horizontalCenter: parent.horizontalCenter; width: 660; height: 460; active: island.mode === "launcher" }
			Pane { id: emojiPane; anchors.horizontalCenter: parent.horizontalCenter; width: 560; height: 440; active: island.mode === "emoji" }
			Pane { id: clipboardPane; anchors.horizontalCenter: parent.horizontalCenter; width: 680; height: 460; active: island.mode === "clipboard" }
			Pane { id: panelPane; anchors.horizontalCenter: parent.horizontalCenter; width: 920; height: 420; active: island.mode === "panel" }
			Pane { id: powerPane; anchors.horizontalCenter: parent.horizontalCenter; width: 360; height: 150; active: island.mode === "power" }
		}
	}
}
