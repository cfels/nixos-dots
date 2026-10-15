import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "components"

Scope {
	id: root

	required property var barWindow

	property bool failed: false
	property string errorString: ""
	readonly property real push: popupLoader.item ? popupLoader.item.push : 0

	readonly property string uiFont: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property string glyphFont: Qt.fontFamilies().indexOf("Symbols Nerd Font") !== -1 ? "Symbols Nerd Font" : ""

	FontLoader {
		id: momo
		source: "fonts/momotrust.ttf"
	}

	function announce(failed: bool, error: string): void {
		Quickshell.inhibitReloadPopup()
		root.failed = failed
		root.errorString = error
		popupLoader.active = false
		popupLoader.active = true
	}

	Connections {
		target: Quickshell

		function onReloadCompleted(): void {
			root.announce(false, "")
		}

		function onReloadFailed(error: string): void {
			root.announce(true, error)
		}
	}

	LazyLoader {
		id: popupLoader

		PanelWindow {
			id: popup
			readonly property real push: Math.max(0, Math.min(1, card.progress))

			anchors {
				top: true
				left: true
				right: true
			}

			screen: root.barWindow.screen
			margins.top: root.barWindow.pillScreenTop + root.barWindow.pillHeight
			implicitHeight: card.height + 16
			color: "transparent"
			exclusionMode: ExclusionMode.Ignore
			mask: Region { item: card }

			Theme {
				id: theme
			}

			Item {
				anchors.fill: parent
				clip: true

				BarReveal {
					id: card

					anchors.horizontalCenter: parent.horizontalCenter
					y: 8
					width: layout.implicitWidth + 36
					height: layout.implicitHeight + 28
					Squircle {
						anchors.fill: parent
						radius: 18
						power: 4
						fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.7)
						strokeColor: root.failed
							? Qt.rgba(theme.danger.r, theme.danger.g, theme.danger.b, 0.24)
							: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.24)
						strokeWidth: 1
					}

					property real progressRatio: 1

					RowLayout {
						id: layout

						anchors.horizontalCenter: parent.horizontalCenter
						anchors.top: parent.top
						anchors.topMargin: 14
						spacing: 10

						Item {
							Layout.alignment: Qt.AlignVCenter
							Layout.preferredWidth: 26
							Layout.preferredHeight: 26

							Text {
								anchors.centerIn: parent
								visible: root.failed
								text: "\u{f071}"
								color: theme.danger
								font.family: root.glyphFont
								font.pixelSize: 15
							}

							AnimatedImage {
								id: tick

								anchors.horizontalCenter: parent.horizontalCenter
								anchors.verticalCenter: parent.verticalCenter
								anchors.verticalCenterOffset: -2
								width: parent.width
								height: parent.height
								visible: !root.failed
								source: "assets/kita.gif"
								fillMode: Image.PreserveAspectCrop
								sourceSize.width: 52
								sourceSize.height: 52
								layer.enabled: true
								layer.effect: MultiEffect {
									maskEnabled: true
									maskSource: tickMask
								}
							}

							Rectangle {
								id: tickMask

								anchors.fill: tick
								radius: 8
								color: "white"
								visible: false
								layer.enabled: true
							}
						}

						ColumnLayout {
							Layout.alignment: Qt.AlignVCenter
							spacing: 2

							Text {
								text: root.failed ? "Reload failed" : "Shell reloaded"
								color: theme.foreground
								font.family: root.uiFont
								font.pixelSize: 13
								font.weight: Font.DemiBold
							}

							Text {
								visible: root.errorString.length > 0
								text: root.errorString
								color: theme.muted
								font.family: root.uiFont
								font.pixelSize: 11
								wrapMode: Text.Wrap
								Layout.maximumWidth: 520
							}
						}
					}

					Rectangle {
						id: progress

						anchors.left: parent.left
						anchors.leftMargin: 14
						anchors.bottom: parent.bottom
						anchors.bottomMargin: 8
						height: 3
						radius: 1.5
						width: (parent.width - 28) * card.progressRatio
						color: root.failed ? theme.danger : theme.accent
						opacity: 0.75
					}

					HoverHandler {
						id: hover
					}

					TapHandler {
						onTapped: {
							life.stop()
							card.revealed = false
						}
					}

					onHidden: popupLoader.active = false

					NumberAnimation {
						id: life

						target: card
						property: "progressRatio"
						from: 1
						to: 0
						duration: root.failed ? 9000 : 3000
						paused: hover.hovered
						onFinished: card.revealed = false
					}

					Component.onCompleted: {
						Qt.callLater(function() { card.revealed = true })
						life.start()
					}
				}
			}
		}
	}
}
