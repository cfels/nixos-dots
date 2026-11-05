pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
	id: page
	spacing: 12
	AudioBackend {
		id: audio
	}
	Text {
		Layout.fillWidth: true
		text: audio.error || (audio.ready ? audio.server : "Connecting to audio…")
		color: audio.error ? SettingsStyle.theme.danger : SettingsStyle.theme.muted
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 12
		wrapMode: Text.WordWrap
	}
	SettingsButton {
		text: "Reconnect audio"
		visible: audio.error.length > 0
		onClicked: audio.reconnect()
	}
	Text {
		text: "Output devices"
		color: SettingsStyle.theme.accent
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 15
	}
	Repeater {
		model: audio.outputModel
		AudioNode {
			Layout.fillWidth: true
			kind: "sink"
			backend: audio
		}
	}
	Text {
		visible: audio.ready && audio.outputModel.count === 0
		text: "No output devices connected"
		color: SettingsStyle.theme.muted
		font.family: SettingsStyle.fontFamily
	}
	Text {
		text: "Microphones"
		color: SettingsStyle.theme.accent
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 15
	}
	Repeater {
		model: audio.inputModel
		AudioNode {
			Layout.fillWidth: true
			kind: "source"
			backend: audio
		}
	}
	Text {
		visible: audio.ready && audio.inputModel.count === 0
		text: "No microphones connected"
		color: SettingsStyle.theme.muted
		font.family: SettingsStyle.fontFamily
	}
	Text {
		text: "Applications"
		color: SettingsStyle.theme.accent
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 15
	}
	Repeater {
		model: audio.streamModel
		AudioNode {
			Layout.fillWidth: true
			kind: "sink-input"
			backend: audio
		}
	}
	Text {
		visible: audio.ready && audio.streamModel.count === 0
		text: "No applications are playing audio"
		color: SettingsStyle.theme.muted
		font.family: SettingsStyle.fontFamily
	}
}
