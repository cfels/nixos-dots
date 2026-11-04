import QtQuick
import QtQuick.Controls
import "../components"

TextField {
	id: control
	property bool invalid: false
	implicitHeight: 32
	activeFocusOnTab: true
	font.family: SettingsStyle.fontFamily
	font.pixelSize: 12
	color: SettingsStyle.theme.foreground
	selectionColor: SettingsStyle.theme.accent
	selectedTextColor: SettingsStyle.theme.background
	placeholderTextColor: SettingsStyle.theme.muted
	leftPadding: 12
	rightPadding: 12
	background: Squircle {
		radius: 10
		fillColor: Qt.rgba(SettingsStyle.theme.idle.r, SettingsStyle.theme.idle.g, SettingsStyle.theme.idle.b, 0.25)
		strokeWidth: 1
		strokeColor: control.invalid ? SettingsStyle.theme.danger : control.activeFocus ? SettingsStyle.theme.accent : Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.1)
	}
}
