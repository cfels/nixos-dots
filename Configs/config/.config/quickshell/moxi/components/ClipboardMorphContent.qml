import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
	id: clipboard

	property bool active: false
	property var entries: []
	property int selected: 0
	property int limit: 200

	signal dismissed()

	function rebuild(): void {
		clipboard.entries = []
		clipboard.selected = 0
		lister.running = true
	}

	function copy(id): void {
		if (id === undefined || id === null || id === "") return

		launcher_copy.entryId = String(id)
		launcher_copy.running = true
		clipboard.dismissed()
	}

	onActiveChanged: if (clipboard.active) {
		clipboard.rebuild()
		focusTimer.restart()
	}

	Timer {
		id: focusTimer
		interval: 40
		onTriggered: keys.forceActiveFocus()
	}

	Process {
		id: lister

		command: ["bash", "-c", "cliphist list | head -n " + clipboard.limit]
		running: false

		stdout: SplitParser {
			onRead: (line) => {
				var tab = line.indexOf("\t")
				if (tab < 1) return

				clipboard.entries = clipboard.entries.concat([{
					id: line.substring(0, tab),
					preview: line.substring(tab + 1)
				}])
			}
		}
	}

	Process {
		id: launcher_copy

		property string entryId: ""
		command: ["bash", "-c", "cliphist decode " + launcher_copy.entryId + " | wl-copy"]
	}

	Item {
		id: keys

		anchors.fill: parent
		focus: true

		Keys.onDownPressed: clipboard.selected = Math.min(clipboard.selected + 1, clipboard.entries.length - 1)
		Keys.onUpPressed: clipboard.selected = Math.max(clipboard.selected - 1, 0)
		Keys.onReturnPressed: clipboard.copy(clipboard.entries[clipboard.selected] ? clipboard.entries[clipboard.selected].id : "")
		Keys.onEscapePressed: clipboard.dismissed()

		ColumnLayout {
			anchors.fill: parent
			spacing: 12

			Text {
				color: "white"
				font.pixelSize: 16
				font.weight: Font.DemiBold
				text: "Clipboard"
			}

			ListView {
				id: list

				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				spacing: 6
				model: clipboard.entries
				boundsBehavior: Flickable.StopAtBounds
				currentIndex: clipboard.selected

				delegate: Rectangle {
					required property var modelData
					required property int index

					width: list.width
					height: 46
					radius: 14
					color: index === clipboard.selected ? Qt.rgba(1, 1, 1, 0.16) : (hover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))

					Behavior on color {
						ColorAnimation { duration: 120 }
					}

					Text {
						anchors.left: parent.left
						anchors.leftMargin: 14
						anchors.right: parent.right
						anchors.rightMargin: 14
						anchors.verticalCenter: parent.verticalCenter
						elide: Text.ElideRight
						color: "white"
						font.pixelSize: 13
						text: modelData.preview
					}

					HoverHandler {
						id: hover
						onHoveredChanged: if (hover.hovered) clipboard.selected = index
					}

					MouseArea {
						anchors.fill: parent
						onClicked: clipboard.copy(modelData.id)
					}
				}
			}
		}
	}
}
