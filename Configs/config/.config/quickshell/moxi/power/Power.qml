import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../components"

PanelWindow {
	id: power

	Theme {
		id: theme
	}

	property bool open: false
	property bool hovered: false

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property real cornerRadius: 34
	readonly property string symbolDir: Quickshell.env("HOME") + "/.config/quickshell/moxi/assets/symbols/"

	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}

	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: power.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: power.open ? cardHost : hidden }

	function show(): void {
		power.open = true
		focusTimer.restart()
	}

	function hide(): void {
		power.open = false
	}

	function toggle(): void {
		if (power.open) power.hide()
		else power.show()
	}

	IpcHandler {
		target: "power"

		function toggle(): void {
			power.toggle()
		}

		function show(): void {
			power.show()
		}

		function hide(): void {
			power.hide()
		}
	}

	Process {
		id: action
	}

	Timer {
		id: focusTimer
		interval: 60
		onTriggered: keys.forceActiveFocus()
	}

	Item {
		id: hidden
		width: 0
		height: 0
	}

	Item {
		id: keys

		anchors.fill: parent
		focus: power.open

		Keys.onEscapePressed: power.hide()
	}

	Rectangle {
		anchors.fill: parent
		color: Qt.rgba(theme.background.r * 0.65, theme.background.g * 0.65, theme.background.b * 0.65, power.open ? 0.55 : 0)
		visible: opacity > 0.01

		Behavior on color {
			ColorAnimation { duration: 180 }
		}

		MouseArea {
			anchors.fill: parent
			onClicked: power.hide()
		}
	}

	Item {
		id: cardHost

		anchors.centerIn: parent
		width: 360
		height: 150
		opacity: power.open ? 1 : 0
		scale: power.open ? 1 : 0.94

		Behavior on opacity {
			NumberAnimation { duration: power.open ? 220 : 150 }
		}

		Behavior on scale {
			NumberAnimation {
				duration: power.open ? 300 : 180
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.2, 0.9, 0.25, 1]
			}
		}

		Item {
			id: cardSource

			visible: true
			width: cardHost.width
			height: cardHost.height

			Squircle {
				anchors.fill: parent
				power: 4
				radius: power.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.5)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.26)
				strokeWidth: 1
			}

			Row {
				anchors.centerIn: parent
				spacing: 14

				Repeater {
					model: [
						{ symbol: "suspend", command: "systemctl suspend" },
						{ symbol: "reboot", command: "systemctl reboot" },
						{ symbol: "shutdown", command: "systemctl poweroff" }
					]

					delegate: Rectangle {
						id: button

						required property var modelData

						width: 100
						height: 100
						radius: 24
						color: buttonMouse.containsMouse
							? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.26)
							: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35)
						scale: buttonMouse.containsMouse ? 1.1 : 1

						Behavior on color {
							ColorAnimation { duration: 130 }
						}

						Behavior on scale {
							NumberAnimation {
								duration: 190
								easing.type: Easing.Bezier
								easing.bezierCurve: [0.22, 1.12, 0.36, 1]
							}
						}

						Image {
							anchors.centerIn: parent
							width: 54
							height: 54
							source: power.symbolDir + button.modelData.symbol + ".png"
							fillMode: Image.PreserveAspectFit
							asynchronous: true
							layer.enabled: true
							layer.effect: MultiEffect {
								colorization: 1
								colorizationColor: theme.accent
							}
						}

						MouseArea {
							id: buttonMouse

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: {
								power.hide()
								action.command = ["bash", "-c", button.modelData.command]
								action.running = true
							}
						}
					}
				}
			}
		}
	}
}
