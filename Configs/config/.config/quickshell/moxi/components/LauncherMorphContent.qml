import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
	id: launcher

	property bool active: false
	property string query: ""
	property var results: []
	property int selected: 0

	readonly property var apps: DesktopEntries.applications.values

	signal dismissed()

	function rebuild(): void {
		var needle = launcher.query.trim().toLowerCase()
		var found = []

		for (var i = 0; i < launcher.apps.length; ++i) {
			var app = launcher.apps[i]
			if (!app || !app.name) continue
			if (needle.length > 0 && app.name.toLowerCase().indexOf(needle) === -1) continue

			found.push(app)
			if (found.length >= 200) break
		}

		launcher.results = found
		launcher.selected = 0
	}

	function launch(): void {
		var app = launcher.results[launcher.selected]
		if (!app) return

		launcher.dismissed()
		app.execute()
	}

	onActiveChanged: if (launcher.active) {
		launcher.query = ""
		launcher.rebuild()
		focusTimer.restart()
	}

	Timer {
		id: focusTimer
		interval: 40
		onTriggered: input.forceActiveFocus()
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 14

		Rectangle {
			Layout.fillWidth: true
			height: 46
			radius: 23
			color: Qt.rgba(1, 1, 1, 0.08)
			border.width: 1
			border.color: Qt.rgba(1, 1, 1, 0.1)

			Text {
				anchors.left: parent.left
				anchors.leftMargin: 18
				anchors.verticalCenter: parent.verticalCenter
				color: Qt.rgba(1, 1, 1, 0.45)
				font.pixelSize: 15
				text: "Search"
				visible: input.text.length === 0
			}

			TextInput {
				id: input

				anchors.fill: parent
				anchors.leftMargin: 18
				anchors.rightMargin: 18
				verticalAlignment: TextInput.AlignVCenter
				color: "white"
				font.pixelSize: 15
				selectByMouse: true
				onTextChanged: {
					launcher.query = text
					launcher.rebuild()
				}

				Keys.onDownPressed: launcher.selected = Math.min(launcher.selected + 1, launcher.results.length - 1)
				Keys.onUpPressed: launcher.selected = Math.max(launcher.selected - 1, 0)
				Keys.onReturnPressed: launcher.launch()
				Keys.onEnterPressed: launcher.launch()
				Keys.onEscapePressed: launcher.dismissed()
			}
		}

		GridView {
			id: grid

			Layout.fillWidth: true
			Layout.fillHeight: true
			clip: true
			cellWidth: 108
			cellHeight: 108
			model: launcher.results
			boundsBehavior: Flickable.StopAtBounds

			delegate: Item {
				required property var modelData
				required property int index

				width: grid.cellWidth
				height: grid.cellHeight

				Rectangle {
					anchors.fill: parent
					anchors.margins: 6
					radius: 18
					color: index === launcher.selected ? Qt.rgba(1, 1, 1, 0.16) : (hover.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent")

					Behavior on color {
						ColorAnimation { duration: 120 }
					}

					ColumnLayout {
						anchors.centerIn: parent
						spacing: 8

						Image {
							Layout.alignment: Qt.AlignHCenter
							width: 40
							height: 40
							source: modelData.icon ? "image://icon/" + modelData.icon : ""
							fillMode: Image.PreserveAspectFit
							asynchronous: true
						}

						Text {
							Layout.alignment: Qt.AlignHCenter
							Layout.maximumWidth: grid.cellWidth - 24
							elide: Text.ElideRight
							color: "white"
							font.pixelSize: 12
							horizontalAlignment: Text.AlignHCenter
							text: modelData.name
						}
					}
				}

				HoverHandler {
					id: hover
					onHoveredChanged: if (hover.hovered) launcher.selected = index
				}

				MouseArea {
					anchors.fill: parent
					onClicked: {
						launcher.selected = index
						launcher.launch()
					}
				}
			}
		}
	}
}
