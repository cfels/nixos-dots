pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import "../components"

Item {
	id: row
	required property var definition
	property string wallpaper: ""
	property var manifest: ({})
	readonly property bool premium: definition.key.startsWith("premium.")
	readonly property var current: premium ? Preferences.premium(wallpaper, definition.key, manifest[definition.key.substring(8)] === undefined ? definition.default : manifest[definition.key.substring(8)]) : Preferences.value(definition.key, definition.default)
	readonly property bool compact: width < 500
	implicitHeight: layout.implicitHeight + 24
	function save(value) {
		Preferences.set(definition.key, value, premium ? wallpaper : "")
	}

	Rectangle {
		anchors {
			left: parent.left
			right: parent.right
			bottom: parent.bottom
		}
		height: 1
		color: Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.07)
	}
	GridLayout {
		id: layout
		anchors {
			left: parent.left
			right: parent.right
			top: parent.top
			leftMargin: 0
			rightMargin: 0
			topMargin: 12
		}
		columns: row.compact ? 1 : 2
		rowSpacing: 8
		columnSpacing: 16
		ColumnLayout {
			Layout.fillWidth: true
			spacing: 4
			Text {
				Layout.fillWidth: true
				text: row.definition.label
				color: SettingsStyle.theme.foreground
				font.family: SettingsStyle.fontFamily
				font.pixelSize: 13
				wrapMode: Text.WordWrap
			}
			Text {
				Layout.fillWidth: true
				text: row.definition.description || ""
				visible: text.length > 0
				color: SettingsStyle.theme.muted
				font.family: SettingsStyle.fontFamily
				font.pixelSize: 11
				wrapMode: Text.WordWrap
			}
		}
		RowLayout {
			Layout.fillWidth: row.compact
			Layout.preferredWidth: row.compact ? -1 : 240
			Layout.alignment: Qt.AlignRight
			spacing: 8
			Loader {
				readonly property Item control: item as Item
				Layout.fillWidth: true
				Layout.preferredWidth: 220
				Layout.preferredHeight: control ? control.implicitHeight : 38
				sourceComponent: row.definition.kind === "toggle" ? toggle : row.definition.kind === "slider" ? slider : row.definition.kind === "choice" ? choice : row.definition.kind === "application" ? application : row.definition.kind === "player" ? player : field
			}
		}
	}
	Component {
		id: toggle
		Item {
			implicitHeight: 32
			SettingsToggle {
				anchors.right: parent.right
				checked: row.current === true
				Accessible.name: row.definition.label
				onClicked: row.save(checked)
			}
		}
	}
	Component {
		id: slider
		RowLayout {
			implicitHeight: 32
			spacing: 8
			SettingsSlider {
				id: range
				Layout.fillWidth: true
				from: row.definition.min
				to: row.definition.max
				stepSize: row.definition.step
				value: row.current
				Accessible.name: row.definition.label
				onMoved: if (!pressed)
					row.save(Number(value.toFixed(3)))
				onPressedChanged: if (!pressed)
					row.save(Number(value.toFixed(3)))
			}
			SettingsField {
				Layout.preferredWidth: 64
				Layout.minimumWidth: 64
				implicitHeight: 32
				text: String(range.pressed ? Number(range.value.toFixed(3)) : row.current)
				invalid: !acceptableInput
				Accessible.name: row.definition.label + " value"
				validator: DoubleValidator {
					bottom: row.definition.min
					top: row.definition.max
					decimals: row.definition.integer ? 0 : 3
					locale: "C"
				}
				onEditingFinished: if (acceptableInput)
					row.save(Number(text))
			}
		}
	}
	Component {
		id: choice
		SettingsChoice {
			model: row.definition.choices
			currentIndex: model.indexOf(row.current)
			Accessible.name: row.definition.label
			onActivated: row.save(model[currentIndex])
		}
	}
	Component {
		id: field
		RowLayout {
			SettingsField {
				id: input
				Layout.fillWidth: true
				text: row.current
				Accessible.name: row.definition.label
				onEditingFinished: if (text !== row.current)
					row.save(text)
			}
			SettingsButton {
				text: row.definition.kind === "path" ? "…" : "Save"
				Accessible.name: row.definition.kind === "path" ? "Choose " + row.definition.label : "Save " + row.definition.label
				onClicked: {
					if (row.definition.kind === "path")
						folder.open()
					else
						row.save(input.text)
				}
			}
			SettingsButton {
				visible: row.definition.kind === "path"
				text: "Save"
				onClicked: row.save(input.text)
			}
			FolderDialog {
				id: folder
				title: row.definition.label
				onAccepted: row.save(decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, "")))
			}
		}
	}
	Component {
		id: application
		SettingsChoice {
			readonly property var entries: [
				{
					label: row.current,
					id: row.current
				}
			].concat(DesktopEntries.applications.values.filter(entry => !entry.noDisplay).map(entry => ({
						label: entry.name,
						id: entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop"
					})))
			model: entries
			textRole: "label"
			currentIndex: 0
			Accessible.name: row.definition.label
			onActivated: row.save(entries[currentIndex].id)
		}
	}
	Component {
		id: player
		SettingsChoice {
			readonly property var players: Mpris.players
			readonly property var entries: [
				{
					label: "Auto",
					id: ""
				}
			].concat(row.current && !players.values.some(node => node.dbusName === row.current) ? [
				{
					label: row.current + " (not running)",
					id: row.current
				}
			] : []).concat(players.values.map(node => ({
						label: node.identity,
						id: node.dbusName
					})))
			model: entries
			textRole: "label"
			currentIndex: Math.max(0, entries.findIndex(item => item.id === row.current))
			Accessible.name: row.definition.label
			onActivated: row.save(entries[currentIndex].id)
		}
	}
}
