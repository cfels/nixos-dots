import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import "../components"

PanelWindow {
	id: root

	Theme {
		id: theme
	}

	property var items: []
	property bool muted: false

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color mutedColor: theme.muted
	readonly property color danger: theme.danger
	readonly property string glyphFont: Qt.fontFamilies().indexOf("Symbols Nerd Font") !== -1 ? "Symbols Nerd Font" : ""
	readonly property string focusScript: Quickshell.env("HOME") + "/.config/hypr/scripts/focus-app.sh"
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""

	FontLoader {
		id: momo

		source: "../fonts/momotrust.ttf"
	}

	anchors {
		top: true
		right: true
	}

	margins {
		top: 56
		right: 12
	}

	implicitWidth: 360
	implicitHeight: list.height
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	color: "transparent"
	mask: Region { item: list }

	function push(notification): void {
		if (root.muted) return

		notification.tracked = true

		var next = [notification]

		for (var i = 0; i < root.items.length && i < 3; ++i) next.push(root.items[i])

		root.items = next
	}

	function remove(notification): void {
		var next = []

		for (var i = 0; i < root.items.length; ++i) {
			if (root.items[i] !== notification) next.push(root.items[i])
		}

		root.items = next
	}

	function setMuted(value): void {
		root.muted = value

		if (value) root.items = []

		stateWrite.command = ["bash", "-c", value ? "mkdir -p \"$HOME/.cache\" && touch \"$HOME/.cache/moxi-dnd\"" : "rm -f \"$HOME/.cache/moxi-dnd\""]
		stateWrite.running = true
	}

	function expireMs(notification): int {
		if (!notification) return 0

		return 5000
	}

	function defaultAction(notification): var {
		if (!notification || !notification.actions) return null

		for (var i = 0; i < notification.actions.length; ++i) {
			if (notification.actions[i].identifier === "default") return notification.actions[i]
		}

		return null
	}

	function iconSource(notification): string {
		var icon = notification && notification.appIcon ? notification.appIcon : ""

		if (icon.length === 0) return ""
		if (icon.charAt(0) === "/") return "file://" + icon

		var resolved = Quickshell.iconPath(icon, true)

		return resolved ? resolved : ""
	}

	function focusNotification(notification): void {
		if (!notification) return

		var names = []
		var entry = notification.desktopEntry ? notification.desktopEntry : ""

		if (entry.length > 0) {
			names.push(entry)
			names.push(entry.replace(/\.desktop$/, ""))
			names.push(entry.replace(/^org\./, ""))

			var parts = entry.split(".")

			for (var i = 0; i < parts.length; ++i) {
				if (parts[i].length > 2 && parts[i] !== "desktop") names.push(parts[i])
			}
		}

		if (notification.appName) names.push(notification.appName)

		focusProcess.candidates = names
		focusProcess.fallback = root.defaultAction(notification)
		focusProcess.running = true
	}

	ScriptModel {
		id: model

		values: root.items
		comparisonMode: ObjectComparison.Identity
	}

	NotificationServer {
		id: server

		keepOnReload: false
		actionsSupported: true
		bodySupported: true
		bodyMarkupSupported: false
		imageSupported: true

		onNotification: (notification) => root.push(notification)
	}

	Process {
		id: stateRead

		command: ["bash", "-c", "test -f \"$HOME/.cache/moxi-dnd\" && echo on || echo off"]
		running: true

		stdout: SplitParser {
			onRead: (line) => root.muted = line === "on"
		}
	}

	Process {
		id: stateWrite
	}

	Process {
		id: focusProcess

		property var candidates: []
		property var fallback: null

		command: ["bash", root.focusScript, Hyprland.usingLua ? "lua" : "classic"].concat(focusProcess.candidates)

		onExited: (code, status) => {
			if (code === 0) {
				focusProcess.fallback = null
				return
			}

			if (focusProcess.fallback) focusProcess.fallback.invoke()

			focusProcess.fallback = null
		}
	}

	IpcHandler {
		target: "notifications"

		function toggle(): void {
			root.setMuted(!root.muted)
		}

		function enable(): void {
			root.setMuted(true)
		}

		function disable(): void {
			root.setMuted(false)
		}

		function clear(): void {
			root.items = []
		}
	}

	Column {
		id: list

		width: root.implicitWidth
		spacing: 10

		Repeater {
			model: model

			delegate: Item {
				id: card

				required property var modelData

				width: list.width
				height: body.height + 26

				property bool ready: false
				property bool closing: false
				property bool hovered: false
				property bool swiped: false

				Component.onCompleted: card.ready = true

				opacity: Math.max(0.1, 1 - Math.abs(card.x) / card.width)

				Behavior on opacity {
					NumberAnimation {
						duration: 200
						easing.type: Easing.Bezier
						easing.bezierCurve: [0.22, 1, 0.36, 1]
					}
				}

				Behavior on y {
					NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
				}

				Behavior on height {
					NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
				}

				transform: Translate {
					x: card.ready ? 0 : card.width

					Behavior on x {
						NumberAnimation {
							duration: 160
							easing.type: Easing.Bezier
							easing.bezierCurve: [0.05, 0.7, 0.1, 1]
						}
					}
				}

				Connections {
					target: card.modelData

					function onClosed(reason) {
						if (card.closing) return

						card.closing = true
						vanish.restart()
					}
				}

				SequentialAnimation {
					id: vanish

					NumberAnimation {
						target: card
						property: "x"
						to: card.x >= 0 ? card.width : -card.width
						duration: 160
						easing.type: Easing.Bezier
						easing.bezierCurve: [0.3, 0, 0.8, 0.15]
					}
					NumberAnimation { target: card; property: "height"; to: 0; duration: 180; easing.type: Easing.OutCubic }
					ScriptAction { script: root.remove(card.modelData) }
				}

				NumberAnimation {
					id: springBack

					target: card
					property: "x"
					to: 0
					duration: 260
					easing.type: Easing.OutCubic
				}

				Timer {
					id: expiry

					interval: root.expireMs(card.modelData)
					running: interval > 0 && !card.closing
					onTriggered: card.modelData.expire()
				}

				HoverHandler {
					id: cardHover
					onHoveredChanged: card.hovered = cardHover.hovered
				}

				Squircle {
					anchors.fill: parent
					power: 4
					radius: 24
					fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.72)
					strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, card.hovered ? 0.42 : 0.22)
					strokeWidth: 1
				}

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.LeftButton
					drag.target: card
					drag.axis: Drag.XAxis
					drag.minimumX: -28
					drag.maximumX: card.width
					cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
					onPressed: card.swiped = false
					onPositionChanged: if (pressed && Math.abs(card.x) > 3) card.swiped = true
					onReleased: {
						if (!card.swiped) return

						if (card.x > card.width * 0.35) {
							card.modelData.dismiss()
							return
						}

						springBack.restart()
					}
					onClicked: {
						if (card.swiped) return

						root.focusNotification(card.modelData)

						card.modelData.dismiss()
					}
				}

				Column {
					id: body

					x: 13
					y: 13
					width: parent.width - 26
					spacing: 7
					clip: true

					Row {
						id: header

						width: parent.width
						height: 20
						spacing: 8

						Image {
							id: appIcon

							width: 18
							height: 18
							anchors.verticalCenter: parent.verticalCenter
							source: root.iconSource(card.modelData)
							visible: status === Image.Ready
							fillMode: Image.PreserveAspectFit
							asynchronous: true
						}

						Text {
							width: Math.max(0, header.width - (appIcon.visible ? 26 : 0))
							anchors.verticalCenter: parent.verticalCenter
							color: root.mutedColor
							elide: Text.ElideRight
							font.family: root.fontFamily
							font.pixelSize: 11
							text: card.modelData && card.modelData.appName ? card.modelData.appName.toUpperCase() : ""
						}
					}

					Text {
						width: parent.width
						visible: text.length > 0
						color: root.foreground
						font.family: root.fontFamily
						font.pixelSize: 14
						font.weight: Font.DemiBold
						text: card.modelData && card.modelData.summary ? card.modelData.summary : ""
						wrapMode: Text.WordWrap
					}

					Text {
						width: parent.width
						visible: text.length > 0
						color: root.mutedColor
						font.family: root.fontFamily
						font.pixelSize: 12
						text: card.modelData && card.modelData.body ? card.modelData.body : ""
						wrapMode: Text.WordWrap
						maximumLineCount: 6
						elide: Text.ElideRight
					}

					SquircleImage {
						width: parent.width
						height: 150
						visible: card.modelData && card.modelData.image && card.modelData.image.length > 0
						source: card.modelData ? card.modelData.image : ""
						radius: 18
						power: 4
						sourceWidth: 640
						sourceHeight: 360
					}
				}
			}
		}
	}
}
