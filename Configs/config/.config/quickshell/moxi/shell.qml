import Quickshell
import Quickshell.Io
import QtQuick
import "bar" as BarModule
import "clipboard" as ClipboardModule
import "launcher" as LauncherModule
import "emoji" as EmojiModule
import "panel" as PanelModule
import "power" as PowerModule
import "screenshot" as ScreenshotModule

ShellRoot {
	id: root

	property bool shotFlash: false
	property bool panelExpanded: false

	function updatePanel(): void {
		if (panel.hovered || pill.hovered) {
			closeTimer.stop()
			return
		}

		if (root.panelExpanded) closeTimer.restart()
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

	BarModule.Bar {
		id: pill

		flash: root.shotFlash
		panelOpen: root.panelExpanded
		onHoveredChanged: root.updatePanel()
			onPanelRequested: {
				closeTimer.stop()
				panel.setAnchor(pill.pillWidth, pill.pillHeight, pill.pillTop)
				root.panelExpanded = true
			}
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
