import QtQuick
import QtQuick.Controls
import "../components"

AbstractButton {
	id: button
	property bool emphasized: false
	property bool danger: false
	readonly property var theme: SettingsStyle.theme
	implicitWidth: Math.max(40, label.implicitWidth + 28)
	implicitHeight: 32
	activeFocusOnTab: true
	Accessible.name: text
	Accessible.role: Accessible.Button
	contentItem: Text {
		id: label
		text: button.text
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 12
		color: !button.enabled ? button.theme.muted : button.danger ? button.theme.danger : button.theme.foreground
		horizontalAlignment: Text.AlignHCenter
		verticalAlignment: Text.AlignVCenter
		elide: Text.ElideRight
	}
	background: Squircle {
		radius: 10
		power: 4
		fillColor: Qt.rgba(button.theme.accent.r, button.theme.accent.g, button.theme.accent.b, button.down ? 0.3 : button.hovered || button.emphasized ? 0.2 : 0.08)
		strokeColor: button.activeFocus ? button.theme.accent : Qt.rgba(button.theme.foreground.r, button.theme.foreground.g, button.theme.foreground.b, 0.1)
		strokeWidth: 1
		Behavior on fillColor {
			ColorAnimation {
				duration: Preferences.motion(130)
			}
		}
	}
}
