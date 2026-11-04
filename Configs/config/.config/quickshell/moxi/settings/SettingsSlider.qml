import QtQuick
import QtQuick.Controls

Slider {
	id: control
	implicitWidth: 220
	implicitHeight: 32
	activeFocusOnTab: true
	readonly property var theme: SettingsStyle.theme
	background: Rectangle {
		x: control.leftPadding
		y: (control.height - height) / 2
		width: control.availableWidth
		height: 5
		radius: 2.5
		color: control.theme.idle
		Rectangle {
			width: parent.width * control.visualPosition
			height: parent.height
			radius: parent.radius
			color: control.theme.accent
		}
	}
	handle: Rectangle {
		x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
		y: (control.height - height) / 2
		width: control.pressed ? 20 : 16
		height: width
		radius: width / 2
		color: control.theme.accent
		border.width: control.activeFocus ? 2 : 0
		border.color: control.theme.foreground
	}
}
