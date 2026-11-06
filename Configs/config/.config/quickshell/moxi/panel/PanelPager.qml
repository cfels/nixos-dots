pragma ComponentBehavior: Bound
import QtQuick
import "../components"

Item {
	id: pager
	property alias desktopHost: desktop
	readonly property var settingsItem: settings.item
	property Component settingsComponent
	property bool panelExpanded: false
	property bool settingsOpen: false
	property real outgoingWidth: 0
	property real outgoingHeight: 0
	onWidthChanged: if (settingsOpen) outgoingWidth = width
	onHeightChanged: if (settingsOpen) outgoingHeight = height
	readonly property int direction: settingsOpen ? -1 : 1
	property string requestedPage: ""
	property real dragDistance: 0
	property bool dragCanceled: false
	property real wheelDistance: 0
	property bool wheelConsumed: false
	property real reveal: 0
	readonly property bool transitioning: panelSpring.running
	readonly property real blend: Math.max(0, Math.min(1, reveal))
	readonly property bool desktopActive: panelExpanded && (!settingsOpen || transitioning || swipe.active)
	readonly property real dragOffset: swipe.active && !settingsOpen ? Math.max(-140, Math.min(140, dragDistance)) : 0
	clip: true

	function showSettings(page): void {
		requestedPage = page || "appearance"
		settingsOpen = true
		if (settingsItem) {
			settingsItem.show(requestedPage)
			requestedPage = ""
		}
	}
	function navigate(): void {
		if (!panelExpanded || transitioning)
			return
		settingsOpen = !settingsOpen
	}
	function finishSwipe(horizontal, vertical): void {
		if (Math.abs(horizontal) < 70 || Math.abs(horizontal) < Math.abs(vertical) * 1.3)
			return
		if (settingsOpen && settingsItem && settingsItem.swipeCategory(horizontal < 0 ? 1 : -1))
			return
		navigate()
	}
	onPanelExpandedChanged: {
		if (!panelExpanded) {
			pager.settle()
			wheelQuiet.stop()
			wheelDistance = 0
			wheelConsumed = false
		}
	}

	function settle(): void {
		panelSpring.stop()
		reveal = settingsOpen ? 1 : 0
	}
	onSettingsOpenChanged: {
		if (settingsOpen) {
			outgoingWidth = width
			outgoingHeight = height
		}
		if (!panelExpanded || Preferences.reducedMotion)
			settle()
		else {
			panelSpring.to = settingsOpen ? 1 : 0
			panelSpring.restart()
		}
	}
	SpringAnimation {
		id: panelSpring
		target: pager
		property: "reveal"
		// Scale stiffness and damping together to keep the original motion.
		spring: 4.39
		damping: 0.3981
		mass: 0.6
		epsilon: 0.004
	}

	Connections {
		target: Preferences
		function onReducedMotionChanged() {
			if (Preferences.reducedMotion)
				pager.settle()
		}
	}
	Timer {
		interval: 567
		running: panelSpring.running
		onTriggered: pager.settle()
	}

	Item {
		id: desktop
		width: pager.width
		height: pager.height
		x: -pager.direction * width * 0.35 * pager.reveal + pager.dragOffset
		opacity: 1 - pager.blend
		enabled: !pager.settingsOpen && !pager.transitioning
	}

	Loader {
		id: settings
		// Resizing the outgoing controls would relayout the whole page each frame.
		width: !pager.settingsOpen && pager.transitioning ? pager.outgoingWidth : pager.width
		height: !pager.settingsOpen && pager.transitioning ? pager.outgoingHeight : pager.height
		x: pager.direction * width * 0.35 * (1 - pager.reveal) + pager.dragOffset
		opacity: pager.blend
		active: pager.panelExpanded && (pager.settingsOpen || swipe.active || pager.transitioning)
		asynchronous: !Preferences.reducedMotion
		enabled: pager.settingsOpen && !pager.transitioning
		sourceComponent: pager.settingsComponent
		onLoaded: {
			if (pager.requestedPage) {
				pager.settingsItem.show(pager.requestedPage)
				pager.requestedPage = ""
			}
		}
	}
	ShaderEffectSource {
		id: outgoingSettings
		x: settings.x
		width: settings.width
		height: settings.height
		opacity: settings.opacity
		visible: sourceItem !== null
		sourceItem: !pager.settingsOpen && pager.transitioning && GraphicsInfo.api !== GraphicsInfo.Software ? settings.item as Item : null
		// Keep the exit on the GPU, without a readback or repainting every control.
		live: sourceItem === null
		hideSource: true
		smooth: true
	}

	DragHandler {
		id: swipe
		target: null
		enabled: pager.panelExpanded && !pager.transitioning
		acceptedButtons: Qt.LeftButton
		yAxis.enabled: false
		// Sliders, seeking and child Flickables keep their own grabs.
		grabPermissions: PointerHandler.TakeOverForbidden
		onActiveTranslationChanged: {
			if (!active)
				return
			pager.dragDistance = activeTranslation.x
		}
		onCanceled: pager.dragCanceled = true
		onActiveChanged: {
			if (active) {
				pager.dragCanceled = false
				pager.dragDistance = 0
			} else if (!pager.dragCanceled) {
				pager.finishSwipe(pager.dragDistance, centroid.position.y - centroid.pressPosition.y)
			}
		}
	}

	WheelHandler {
		target: null
		enabled: pager.panelExpanded
		orientation: Qt.Horizontal
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		onWheel: event => {
			const horizontal = event.pixelDelta.x || event.angleDelta.x
			const vertical = event.pixelDelta.y || event.angleDelta.y
			if (!horizontal || Math.abs(vertical) > Math.abs(horizontal)) {
				event.accepted = false
				return
			}
			event.accepted = true
			wheelQuiet.restart()
			if (pager.wheelConsumed || pager.transitioning)
				return
			pager.wheelDistance += horizontal
			if (Math.abs(pager.wheelDistance) < 70)
				return
			pager.finishSwipe(pager.wheelDistance, 0)
			pager.wheelConsumed = true
		}
	}
	Timer {
		id: wheelQuiet
		interval: 220
		onTriggered: {
			pager.wheelDistance = 0
			pager.wheelConsumed = false
		}
	}
}
