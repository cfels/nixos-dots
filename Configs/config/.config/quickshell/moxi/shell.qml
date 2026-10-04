import Quickshell
import Quickshell.Io
import QtQuick
import "bar" as BarModule
import "clipboard" as ClipboardModule
import "launcher" as LauncherModule
import "emoji" as EmojiModule
import "notifications" as NotificationModule
import "panel" as PanelModule
import "power" as PowerModule
import "screenshot" as ScreenshotModule

ShellRoot {
	id: root

	property bool shotFlash: false
	property bool panelExpanded: false
	property bool panelEntered: false
	property string openOverlay: ""

	function updatePanel(): void {
		if (panel.hovered) {
			root.panelEntered = true
			closeTimer.stop()
			return
		}

		if (openGrace.running) return

		if (root.panelExpanded && root.panelEntered) closeTimer.restart()
	}

	function closeOverlay(name): void {
		if (name === "launcher") launcher.hide()
		else if (name === "clipboard") clipboard.hide()
		else if (name === "emoji") emojiPicker.hide()
		else if (name === "power") powerMenu.hide()
		else if (name === "panel") {
			closeTimer.stop()
			root.panelExpanded = false
		}
	}

	function overlayOpened(name, opened): void {
		if (!opened) {
			if (root.openOverlay === name) root.openOverlay = ""
			return
		}

		if (root.openOverlay === name) return

		var previous = root.openOverlay

		root.openOverlay = name

		if (previous !== "") root.closeOverlay(previous)
	}

	onPanelExpandedChanged: {
		if (root.panelExpanded) root.panelEntered = false

		root.overlayOpened("panel", root.panelExpanded)
	}

	Timer {
		id: flashTimer
		interval: 1400
		onTriggered: root.shotFlash = false
	}

	Timer {
		id: closeTimer
		interval: 320
		onTriggered: root.panelExpanded = false
	}

	Timer {
		id: openGrace
		interval: 260
	}

	BarModule.Bar {
		id: pill

		flash: root.shotFlash
		panelOpen: root.openOverlay !== ""
		notificationsMuted: notifications.muted
		onHoveredChanged: root.updatePanel()
			onPanelRequested: {
				closeTimer.stop()
				openGrace.restart()
				panel.setAnchor(pill.pillWidth, pill.pillHeight, pill.pillTop)
				root.panelExpanded = true
			}
		onNotificationsToggle: notifications.setMuted(!notifications.muted)
	}

	Connections {
		target: launcher

		function onOpenChanged(): void {
			if (launcher.open) launcher.setAnchor(pill.pillWidth, pill.pillHeight, pill.pillTop)

			root.overlayOpened("launcher", launcher.open)
		}
	}

	Connections {
		target: clipboard

		function onOpenChanged(): void {
			if (clipboard.open) clipboard.setAnchor(pill.pillWidth, pill.pillHeight, pill.pillTop)

			root.overlayOpened("clipboard", clipboard.open)
		}
	}

	Connections {
		target: emojiPicker

		function onOpenChanged(): void {
			root.overlayOpened("emoji", emojiPicker.open)
		}
	}

	Connections {
		target: powerMenu

		function onOpenChanged(): void {
			root.overlayOpened("power", powerMenu.open)
		}
	}

	NotificationModule.Notifications {
		id: notifications
	}

		PanelModule.Panel {
			id: panel

			expanded: root.panelExpanded
			onHoveredChanged: root.updatePanel()
		}

	ScreenshotModule.Screenshot {
		onCaptured: {
			root.shotFlash = true
			flashTimer.restart()
		}
	}

	LauncherModule.Launcher {
		id: launcher

	}

	ClipboardModule.Clipboard {
		id: clipboard

	}

	PowerModule.Power {
		id: powerMenu
	}

	EmojiModule.Emoji {
		id: emojiPicker

	}

	IpcHandler {
		target: "panel"

		function toggle(): void {
			root.panelExpanded = !root.panelExpanded
		}

		function show(): void {
			closeTimer.stop()
			root.panelExpanded = true
		}

		function hide(): void {
			root.panelExpanded = false
		}
	}

	IpcHandler {
		target: "shell"

		function reload(): void {
			Quickshell.reload(true)
		}
	}

}
