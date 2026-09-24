import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../components"

PanelWindow {
	id: launcher

	Theme {
		id: theme
	}

	property bool open: false
	property string query: ""
	property var results: []
	property int selected: 0
	property var index: []
	property bool indexReady: false
	property double lastKeyNav: 0
	readonly property int resultLimit: 200

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property real cornerRadius: launcher.open ? 30 : 19

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: 56
	implicitHeight: 620
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: inputArea }

	Connections {
		target: DesktopEntries

		function onApplicationsChanged(): void {
			launcher.buildIndex()
			launcher.refresh(false)
		}
	}

	function buildIndex(): void {
		var apps = DesktopEntries.applications.values
		var built = []

		for (var i = 0; i < apps.length; ++i) {
			var entry = apps[i]

			if (entry.noDisplay) continue

			var name = entry.name ? entry.name : ""
			var terms = name.toLowerCase()

			if (entry.genericName) terms += " " + entry.genericName.toLowerCase()
			if (entry.comment) terms += " " + entry.comment.toLowerCase()

			var keywords = entry.keywords || []

			for (var k = 0; k < keywords.length; ++k) terms += " " + keywords[k].toLowerCase()

			built.push({
				"entry": entry,
				"lower": name.toLowerCase(),
				"id": entry.id ? entry.id.toLowerCase() : "",
				"terms": terms
			})
		}

		built.sort(function(left, right) {
			return left.lower < right.lower ? -1 : (left.lower > right.lower ? 1 : 0)
		})

		launcher.index = built
		launcher.indexReady = built.length > 0
	}

	function refresh(reset): void {
		if (!launcher.indexReady) launcher.buildIndex()

		var needle = launcher.query.toLowerCase()
		var entries = launcher.index
		var found = []

		for (var i = 0; i < entries.length; ++i) {
			var item = entries[i]

			if (needle.length === 0 || item.lower.indexOf(needle) !== -1 || item.id.indexOf(needle) !== -1 || item.terms.indexOf(needle) !== -1) found.push(item.entry)
		}

		launcher.results = found.slice(0, launcher.resultLimit)

		if (reset === true || launcher.selected >= launcher.results.length) launcher.selected = 0
		if (launcher.selected < 0) launcher.selected = 0
	}

	function move(delta): void {
		launcher.lastKeyNav = Date.now()

		if (launcher.results.length === 0) return

		var next = launcher.selected + delta

		launcher.selected = Math.max(0, Math.min(next, launcher.results.length - 1))
	}

	function show(): void {
		launcher.open = true
		launcher.query = ""
		launcher.refresh(true)
		focusTimer.restart()
	}

	function hide(): void {
		launcher.open = false
	}

	function toggle(): void {
		if (launcher.open) launcher.hide()
		else launcher.show()
	}

	function launch(): void {
		if (launcher.results.length === 0) return

		var index = Math.max(0, Math.min(launcher.selected, launcher.results.length - 1))
		var entry = launcher.results[index]

		launcher.hide()
		entry.execute()
	}

	IpcHandler {
		target: "launcher"

		function toggle(): void {
			launcher.toggle()
		}

		function show(): void {
			launcher.show()
		}

		function hide(): void {
			launcher.hide()
		}
	}

	Timer {
		id: focusTimer
		interval: 80
		onTriggered: input.forceActiveFocus()
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: launcher.open ? 0 : -30
		width: launcher.open ? 660 : 210
		height: launcher.open ? 460 : 38
		opacity: launcher.open ? 1 : 0

		Behavior on width {
			NumberAnimation {
				duration: launcher.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: launcher.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on y {
			NumberAnimation {
				duration: launcher.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		scale: launcher.open ? 1 : 0.94
		transformOrigin: Item.Center

		Behavior on scale {
			NumberAnimation {
				duration: launcher.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on opacity {
			NumberAnimation { duration: launcher.open ? 220 : 160 }
		}

		Item {
			id: cardSource

			visible: true
			width: cardHost.width
			height: cardHost.height

			Squircle {
				anchors.fill: parent
				power: 4
				radius: launcher.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.74)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.26)
				strokeWidth: 1
			}

			Item {
				anchors.fill: parent
				anchors.margins: 22

				Rectangle {
					id: searchFrame

					anchors.top: parent.top
					anchors.left: parent.left
					anchors.right: parent.right
					height: 46
					radius: 23
					color: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35)

					Text {
						anchors.left: parent.left
						anchors.leftMargin: 18
						anchors.verticalCenter: parent.verticalCenter
						color: launcher.muted
						font.family: launcher.fontFamily
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
						color: launcher.foreground
						font.family: launcher.fontFamily
						font.pixelSize: 15
						selectionColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4)
						selectedTextColor: launcher.foreground
						clip: true
						focus: launcher.open

						onTextChanged: {
							launcher.query = text
							launcher.refresh(true)
						}

						Keys.onDownPressed: launcher.move(1)
						Keys.onUpPressed: launcher.move(-1)
						Keys.onReturnPressed: launcher.launch()
						Keys.onEnterPressed: launcher.launch()
						Keys.onEscapePressed: launcher.hide()

						Keys.onPressed: function(event) {
							if (event.key === Qt.Key_PageDown) {
								launcher.move(6)
								event.accepted = true
							} else if (event.key === Qt.Key_PageUp) {
								launcher.move(-6)
								event.accepted = true
							}
						}
					}
				}

				ListView {
					id: list

					anchors.top: searchFrame.bottom
					anchors.topMargin: 14
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					clip: true
						spacing: 4
						model: launcher.results
						currentIndex: launcher.selected
						highlightFollowsCurrentItem: true
						cacheBuffer: 900

						onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
						onCountChanged: positionViewAtBeginning()

					delegate: Rectangle {
						id: row

						required property var modelData
						required property int index

						width: list.width
						height: 46
						radius: 14
						color: index === launcher.selected
							? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
							: (rowMouse.containsMouse ? Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35) : "transparent")

						Behavior on color {
							ColorAnimation { duration: 120 }
						}

						Image {
							id: appIcon

							anchors.left: parent.left
							anchors.leftMargin: 12
							anchors.verticalCenter: parent.verticalCenter
							width: 26
							height: 26
							sourceSize.width: 52
							sourceSize.height: 52
							source: row.modelData.icon ? "image://icon/" + row.modelData.icon : ""
							fillMode: Image.PreserveAspectFit
							asynchronous: true
							visible: row.modelData.icon !== ""
						}

						Text {
							anchors.left: appIcon.visible ? appIcon.right : parent.left
							anchors.leftMargin: appIcon.visible ? 14 : 16
							anchors.right: parent.right
							anchors.rightMargin: 16
							anchors.verticalCenter: parent.verticalCenter
							color: launcher.foreground
							elide: Text.ElideRight
							font.family: launcher.fontFamily
							font.pixelSize: 14
							text: row.modelData.name
							wrapMode: Text.NoWrap
						}

						MouseArea {
							id: rowMouse

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onEntered: {
								if (Date.now() - launcher.lastKeyNav < 400) return

								launcher.selected = row.index
							}
							onClicked: {
								launcher.selected = row.index
								launcher.launch()
							}
						}
					}
				}
			}
		}

	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: cardHost.top
		width: launcher.open ? cardHost.width : 0
		height: launcher.open ? cardHost.height : 0
	}
}
