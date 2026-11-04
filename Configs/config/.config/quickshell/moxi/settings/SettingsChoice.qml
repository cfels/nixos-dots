import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Effects
import "../components"

ComboBox {
	id: control
	implicitWidth: 220
	implicitHeight: 32
	activeFocusOnTab: true
	font.family: SettingsStyle.fontFamily
	font.pixelSize: 12
	leftPadding: 12
	rightPadding: 26
	contentItem: Text {
		text: control.displayText
		font: control.font
		color: SettingsStyle.theme.foreground
		elide: Text.ElideRight
		verticalAlignment: Text.AlignVCenter
	}
	indicator: Text {
		x: control.width - 22
		y: (control.height - height) / 2
		text: "⌄"
		color: SettingsStyle.theme.muted
	}
	background: Squircle {
		radius: 10
		fillColor: Qt.rgba(SettingsStyle.theme.idle.r, SettingsStyle.theme.idle.g, SettingsStyle.theme.idle.b, 0.25)
		strokeColor: control.activeFocus ? SettingsStyle.theme.accent : Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.1)
		strokeWidth: 1
	}
	delegate: ItemDelegate {
		id: entry
		required property int index
		required property var modelData
		width: ListView.view ? ListView.view.width : control.availableWidth
		height: 36
		highlighted: control.highlightedIndex === index
		contentItem: Text {
			text: control.textRole ? modelData[control.textRole] : modelData
			font: control.font
			color: SettingsStyle.theme.foreground
			elide: Text.ElideRight
			verticalAlignment: Text.AlignVCenter
		}
		background: Squircle {
			radius: 10
			power: 4
			fillColor: entry.highlighted ? Qt.rgba(SettingsStyle.theme.accent.r, SettingsStyle.theme.accent.g, SettingsStyle.theme.accent.b, 0.2) : "transparent"
			Behavior on fillColor {
				ColorAnimation {
					duration: Preferences.motion(110)
				}
			}
		}
	}
	popup: Popup {
		id: menu
		y: control.height + 4
		width: control.width
		padding: 8
		margins: 8
		implicitHeight: Math.min(280, contentItem.implicitHeight + 16)
		contentItem: Item {
			implicitHeight: entries.contentHeight
			layer.enabled: menu.visible
			layer.effect: MultiEffect {
				maskEnabled: true
				maskSource: contentMask
			}
			Squircle {
				id: contentMask
				anchors.fill: parent
				visible: false
				layer.enabled: menu.visible
				radius: 10
				power: 4
				fillColor: "white"
			}
			ListView {
				id: entries
				anchors.fill: parent
				clip: true
				model: menu.visible ? control.delegateModel : null
				currentIndex: control.highlightedIndex
				boundsBehavior: Flickable.StopAtBounds
				ScrollIndicator.vertical: ScrollIndicator {}
			}
		}
		background: SettingsPopupSurface {
			opened: menu.visible
			sourceItem: SettingsStyle.popupSource(control, control.Window.window ? control.Window.window.contentItem : null)
		}
		enter: Transition {
			ParallelAnimation {
				NumberAnimation {
					property: "opacity"
					from: 0
					to: 1
					duration: Preferences.motion(160)
					easing.type: Easing.OutCubic
				}
				NumberAnimation {
					property: "scale"
					from: 0.96
					to: 1
					duration: Preferences.motion(220)
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]
				}
			}
		}
		exit: Transition {
			ParallelAnimation {
				NumberAnimation {
					property: "opacity"
					to: 0
					duration: Preferences.motion(120)
					easing.type: Easing.OutCubic
				}
				NumberAnimation {
					property: "scale"
					to: 0.98
					duration: Preferences.motion(140)
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
