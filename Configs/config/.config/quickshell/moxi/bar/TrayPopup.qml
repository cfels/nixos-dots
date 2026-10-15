import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import "../components"

Scope {
	id: tray

	required property var barWindow
	property bool open: false
	readonly property real push: tray.barWindow.panelOpen ? 0 : Math.max(0, Math.min(1, card.progress))
	readonly property bool available: SystemTray.items.values.length > 0
	readonly property string focusScript: Quickshell.env("HOME") + "/.config/hypr/scripts/focus-app.sh"

	function appNames(app): var {
		var names = []
		var labels = [app.id, app.title, app.tooltipTitle]
		for (var i = 0; i < labels.length; ++i) {
			if (!labels[i]) continue
			var label = String(labels[i]).trim()
			if (label.length === 0) continue
			names.push(label)
			var name = label.replace(/\.desktop$/i, "").replace(/(?:[ _-]?desktop|[ _-]?tray)$/i, "").trim()
			if (name.length >= 3 && name !== label) names.push(name)
		}
		return names
	}

	function openMenu(app, icon): void {
		if (!app.hasMenu) return
		if (appMenu.visible) appMenu.close()
		var position = icon.mapToItem(popup.contentItem, 0, icon.height)
		appMenu.menu = app.menu
		appMenu.anchor.rect.x = position.x
		appMenu.anchor.rect.y = position.y + 4
		appMenu.open()
	}

	function activateApp(app, icon): void {
		if (focusProcess.running) return
		focusProcess.candidates = tray.appNames(app)
		focusProcess.app = app
		focusProcess.icon = icon
		focusProcess.running = true
	}

	function launchApp(app, icon): void {
		if (!app.onlyMenu) {
			app.activate()
			return
		}

		var names = tray.appNames(app)
		var entries = DesktopEntries.applications.values
		for (var i = 0; i < entries.length; ++i) {
			var entry = entries[i]
			var entryId = String(entry.id || "").replace(/\.desktop$/, "").toLowerCase()
			for (var j = 0; j < names.length; ++j) {
				var name = names[j].toLowerCase()
				if (String(entry.name || "").toLowerCase() === name || entryId === name || entryId.endsWith("." + name)) {
					entry.execute()
					return
				}
			}
		}
		tray.openMenu(app, icon)
	}

	Process {
		id: focusProcess
		property var candidates: []
		property var app: null
		property var icon: null
		command: ["bash", tray.focusScript, Hyprland.usingLua ? "lua" : "classic"].concat(focusProcess.candidates)
		onExited: (code, status) => {
			if (code !== 0 && focusProcess.app) tray.launchApp(focusProcess.app, focusProcess.icon)
			focusProcess.app = null
			focusProcess.icon = null
		}
	}

	function updateHover(): void {
		if (!tray.available || tray.barWindow.panelOpen || !tray.barWindow.pillShown) {
			openDelay.stop()
			closeDelay.stop()
			if (appMenu.visible) appMenu.close()
			tray.open = false
			card.hideImmediately()
			return
		}

		if (tray.barWindow.hovered || popupHover.hovered || appMenu.visible) {
			closeDelay.stop()
			if (!tray.open && !openDelay.running) openDelay.restart()
		} else {
			openDelay.stop()
			closeDelay.restart()
		}
	}

	onAvailableChanged: updateHover()

	Connections {
		target: tray.barWindow
		function onHoveredChanged(): void { tray.updateHover() }
		function onPanelOpenChanged(): void { tray.updateHover() }
		function onPillShownChanged(): void { tray.updateHover() }
	}

	Timer {
		id: openDelay
		interval: 160
		onTriggered: tray.open = true
	}

	Timer {
		id: closeDelay
		interval: 320
		onTriggered: tray.open = false
	}

	TrayMenu {
		id: appMenu
		anchor.window: popup
		fontFamily: tray.barWindow.fontFamily
		onVisibleChanged: tray.updateHover()
	}

	PanelWindow {
		id: popup

		anchors { top: true; left: true; right: true }
		screen: tray.barWindow.screen
		margins.top: tray.barWindow.pillScreenTop + tray.barWindow.pillHeight
		implicitHeight: card.height + 16
		visible: !tray.barWindow.panelOpen && (tray.open || card.progress > 0.001)
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		mask: Region { item: hoverBridge }

		Theme { id: theme }

		Item {
			id: hoverBridge
			anchors.horizontalCenter: parent.horizontalCenter
			width: card.width
			height: parent.height
			clip: true

			HoverHandler {
				id: popupHover
				onHoveredChanged: tray.updateHover()
			}

			BarReveal {
				id: card
				anchors.horizontalCenter: parent.horizontalCenter
				y: 8
				width: icons.implicitWidth + 16
				height: icons.implicitHeight + 8
				revealed: tray.open

				Rectangle {
					anchors.fill: parent
					radius: 19
					color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b,
						(popupHover.hovered || tray.barWindow.hovered) ? 0.78 : 0.66)
					border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16)
					border.width: 1

					Behavior on color { ColorAnimation { duration: 200 } }
				}

				Grid {
					id: icons
					anchors.horizontalCenter: parent.horizontalCenter
					y: 4
					columns: Math.min(8, Math.max(1, SystemTray.items.values.length))
					spacing: 4

					Repeater {
						model: SystemTray.items

						delegate: Rectangle {
							id: trayIcon
							required property var modelData
							width: 30
							height: 30
							radius: 10
							color: iconMouse.containsMouse
								? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : "transparent"
							scale: iconMouse.containsMouse ? 1.08 : 1

							Behavior on color { ColorAnimation { duration: 180 } }
							Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

							Image {
								anchors.centerIn: parent
								width: 20
								height: 20
								source: trayIcon.modelData.icon
								sourceSize.width: 40
								sourceSize.height: 40
								fillMode: Image.PreserveAspectFit
							}

							MouseArea {
								id: iconMouse
								anchors.fill: parent
								hoverEnabled: true
								acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
								cursorShape: Qt.PointingHandCursor
								onClicked: (mouse) => {
									var app = trayIcon.modelData
									if (mouse.button === Qt.MiddleButton) app.secondaryActivate()
									else if (mouse.button === Qt.RightButton) tray.openMenu(app, trayIcon)
									else tray.activateApp(app, trayIcon)
								}
								onWheel: (wheel) => {
									var horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
									trayIcon.modelData.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal)
								}
							}
						}
					}
				}
			}
		}
	}
}
