import QtQuick
import QtQuick.Controls
import "../components"

AbstractButton {
	id: button
	required property string iconName
	property bool selected: false
	implicitHeight: 36
	activeFocusOnTab: true
	Accessible.name: text
	background: Rectangle {
		radius: 8
		color: Qt.rgba(SettingsStyle.theme.accent.r, SettingsStyle.theme.accent.g, SettingsStyle.theme.accent.b, button.hovered && !button.selected ? 0.07 : 0)
		border.width: button.activeFocus ? 1 : 0
		border.color: SettingsStyle.theme.accent
		Behavior on color {
			ColorAnimation {
				duration: Preferences.motion(130)
			}
		}
	}
	contentItem: Item {
		SettingsIcon {
			id: icon
			x: 8
			anchors.verticalCenter: parent.verticalCenter
			name: button.iconName
		}
		Text {
			anchors {
				left: icon.right
				leftMargin: 8
				right: parent.right
				rightMargin: 4
				verticalCenter: parent.verticalCenter
			}
			text: button.text
			font.family: SettingsStyle.fontFamily
			font.contextFontMerging: true
			renderTypeQuality: Text.HighRenderTypeQuality
			font.pixelSize: 11
			color: button.selected ? SettingsStyle.theme.foreground : SettingsStyle.theme.muted
			elide: Text.ElideRight
		}
	}
}
