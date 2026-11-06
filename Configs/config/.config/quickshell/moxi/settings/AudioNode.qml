pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
	id: card
	required property var nodeData
	required property string kind
	required property AudioBackend backend
	implicitHeight: layout.implicitHeight + 24
	readonly property bool stream: kind === "sink-input"
	Rectangle {
		anchors {
			left: parent.left
			right: parent.right
			bottom: parent.bottom
		}
		height: 1
		color: Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.07)
	}
	ColumnLayout {
		id: layout
		anchors {
			left: parent.left
			right: parent.right
			top: parent.top
			topMargin: 12
		}
		spacing: 8
		RowLayout {
			Layout.fillWidth: true
			Image {
				visible: card.stream && source.toString().length > 0
				source: card.nodeData.icon ? Quickshell.iconPath(card.nodeData.icon, true) : ""
				Layout.preferredWidth: 24
				Layout.preferredHeight: 24
				fillMode: Image.PreserveAspectFit
			}
			ColumnLayout {
				Layout.fillWidth: true
				Text {
					Layout.fillWidth: true
					text: card.nodeData.label
					font.family: SettingsStyle.fontFamily
					font.pixelSize: 13
					color: SettingsStyle.theme.foreground
					wrapMode: Text.WordWrap
				}
				Text {
					Layout.fillWidth: true
					text: card.stream ? card.nodeData.detail : (({ RUNNING: "In use", IDLE: "Ready", SUSPENDED: "Idle" })[card.nodeData.state] || card.nodeData.state || "Status unknown") + (card.nodeData.availability === "not available" ? " · Unavailable" : card.nodeData.availability === "unknown" ? " · Availability unknown" : "")
					font.family: SettingsStyle.fontFamily
					font.pixelSize: 10
					color: SettingsStyle.theme.muted
					wrapMode: Text.WordWrap
				}
			}
			SettingsButton {
				visible: !card.stream
				text: card.nodeData.default ? "Default" : "Set as default"
				emphasized: card.nodeData.default === true
				enabled: !card.nodeData.default && card.nodeData.availability !== "not available"
				onClicked: card.backend.change("default", card.kind, card.nodeData, null)
			}
		}
		RowLayout {
			Layout.fillWidth: true
			SettingsSlider {
				id: volume
				Layout.fillWidth: true
				from: 0
				to: 150
				stepSize: 1
				value: card.nodeData.volume === null ? 0 : card.nodeData.volume
				enabled: card.nodeData.volume !== null && (!card.stream || card.nodeData.writable)
				Accessible.name: card.nodeData.label + " volume"
				onMoved: if (!pressed)
					card.backend.change("volume", card.kind, card.nodeData, value)
				onPressedChanged: if (!pressed && enabled)
					card.backend.change("volume", card.kind, card.nodeData, value)
			}
			Text {
				Layout.preferredWidth: 48
				text: card.nodeData.volume === null ? "—" : Math.round(volume.pressed ? volume.value : card.nodeData.volume) + "%"
				color: SettingsStyle.theme.foreground
				font.family: SettingsStyle.fontFamily
				font.pixelSize: 12
			}
			SettingsButton {
				text: card.nodeData.muted ? "Unmute" : "Mute"
				emphasized: card.nodeData.muted
				onClicked: card.backend.change("mute", card.kind, card.nodeData, !card.nodeData.muted)
			}
		}
		SettingsChoice {
			Layout.fillWidth: true
			visible: card.stream
			model: card.backend.outputs
			textRole: "label"
			currentIndex: model.findIndex(output => output.id === card.nodeData.sink)
			Accessible.name: card.nodeData.label + " output device"
			onActivated: card.backend.change("route", card.kind, card.nodeData, model[currentIndex].id)
		}
		SettingsChoice {
			Layout.fillWidth: true
			visible: !card.stream && (card.nodeData.ports || []).length > 1
			model: card.nodeData.ports || []
			textRole: "description"
			currentIndex: model.findIndex(port => port.name === card.nodeData.port)
			Accessible.name: card.nodeData.label + " port"
			onActivated: card.backend.change("port", card.kind, card.nodeData, model[currentIndex].name)
		}
	}
}
