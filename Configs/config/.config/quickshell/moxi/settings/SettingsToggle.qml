import QtQuick
import QtQuick.Controls
import "../components"

AbstractButton {
	id: control
	checkable: true
	activeFocusOnTab: true
	implicitWidth: 40
	implicitHeight: 24
	Accessible.role: Accessible.CheckBox
	Accessible.checkable: true
	Accessible.checked: checked
	readonly property var theme: SettingsStyle.theme
	background: Rectangle {
		radius: height / 2
		color: control.checked ? control.theme.accent : control.theme.idle
		opacity: control.enabled ? 1 : 0.4
		border.width: control.activeFocus ? 2 : 1
		border.color: control.activeFocus ? control.theme.foreground : "transparent"
		Behavior on color {
			ColorAnimation {
				duration: Preferences.motion(130)
			}
		}
		Rectangle {
			width: 16
			height: 16
			radius: 8
			y: 4
			x: control.checked ? parent.width - width - 4 : 4
			color: control.checked ? control.theme.background : control.theme.foreground
			Behavior on x {
				NumberAnimation {
					duration: Preferences.motion(190)
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
