pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../components"

PanelWindow {
	id: launcher

	Theme {
		id: theme
	}

	property bool open: false
	property var surfaceHost: null
	visible: surfaceHost === null
	property real anchorWidth: 210
	property real anchorHeight: 38
	property real anchorTop: 4

	function setAnchor(width: real, height: real, y: real): void {
		launcher.anchorWidth = width
		launcher.anchorHeight = height
		launcher.anchorTop = y
	}
	property string query: ""
	property var results: []
	property int selected: 0
	property var index: []
	property var defaultResults: []
	property string resultsQuery: "\u0000"
	property bool indexReady: false
	property var iconFiles: ({})
	property var iconPending: ({})
	property double lastKeyNav: 0
	readonly property int resultLimit: 200
	readonly property real preferredHeight: 104 + (results.length === 0 ? 80 : Math.min(356, results.length * 50 - 4))

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property real cornerRadius: launcher.open ? 30 : 19
	readonly property string iconScanScript: Quickshell.shellDir + "/launcher/icon-scan.sh"

	Component.onCompleted: {
		launcher.buildIndex()
		launcher.refresh(true)
		iconScan.running = true
	}

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: 6
	implicitHeight: 530
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: !launcher.surfaceHost && launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
		launcher.defaultResults = built.slice(0, launcher.resultLimit).map(function(item) { return item.entry })
		launcher.resultsQuery = "\u0000"
		launcher.indexReady = true
	}

	function refresh(reset): void {
		if (!launcher.indexReady) launcher.buildIndex()

		var needle = launcher.query.toLowerCase()
		if (needle !== launcher.resultsQuery) {
			var found = launcher.defaultResults
			if (needle.length > 0) {
				found = []
				var entries = launcher.index
				for (var i = 0; i < entries.length && found.length < launcher.resultLimit; ++i) {
					var item = entries[i]
					if (item.lower.indexOf(needle) !== -1 || item.id.indexOf(needle) !== -1 || item.terms.indexOf(needle) !== -1) found.push(item.entry)
				}
			}
			if (found.length !== launcher.results.length || found.some(function(entry, index) { return entry !== launcher.results[index] })) {
				resultsBackdrop.update()
				launcher.results = found
			}
			launcher.resultsQuery = needle
		}

		if (reset === true || launcher.selected >= launcher.results.length) launcher.selected = 0
		if (launcher.selected < 0) launcher.selected = 0
	}

	function move(delta): void {
		launcher.lastKeyNav = Date.now()

		if (launcher.results.length === 0) return

		var next = launcher.selected + delta

		list.followSelection = true
		launcher.selected = Math.max(0, Math.min(next, launcher.results.length - 1))
	}

	function show(): void {
		input.clear()
		launcher.query = ""
		launcher.refresh(true)
		list.followSelection = true
		list.positionViewAtBeginning()
		launcher.open = true
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

	function collectIcon(line): void {
		var tab = line.indexOf("\t")

		if (tab < 1) return

		launcher.iconPending[line.substring(0, tab)] = line.substring(tab + 1)
	}

	function iconSource(icon): string {
		if (!icon || icon.length === 0) return ""
		if (icon.indexOf("file:") === 0 || icon.indexOf("image:") === 0) return icon
		if (icon.charAt(0) === "/") return "file://" + icon

		var file = launcher.iconFiles[icon] || launcher.iconFiles[icon.replace(/\.(svg|png|xpm)$/i, "")]

		if (file) return "file://" + file

		return Quickshell.iconPath(icon, true)
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
		onTriggered: if (launcher.open) input.forceActiveFocus()
	}

	Process {
		id: iconScan

		command: ["bash", launcher.iconScanScript]

		stdout: SplitParser {
			onRead: (line) => launcher.collectIcon(line)
		}

		onExited: (code, status) => {
			launcher.iconFiles = launcher.iconPending
			launcher.iconPending = ({})
		}
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: launcher.open ? 50 : launcher.anchorTop
		width: launcher.open ? 660 : launcher.anchorWidth
		height: launcher.open ? launcher.preferredHeight : launcher.anchorHeight
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

			parent: launcher.surfaceHost || cardHost
			visible: true
			width: parent.width
			height: parent.height

			Squircle {
				visible: !launcher.surfaceHost
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
					property real focusPresence: input.activeFocus ? 1 : 0

					anchors.top: parent.top
					anchors.left: parent.left
					anchors.right: parent.right
					height: 46
					radius: 23
					color: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35 + 0.07 * focusPresence)
					border.width: 1
					border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18 * focusPresence)

					Behavior on focusPresence {
						NumberAnimation {
							duration: 180
							easing.type: Easing.OutCubic
						}
					}

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

				SearchBackdrop {
					id: resultsBackdrop
					view: list
					active: launcher.open
				}

				ListView {
					id: list
					property bool followSelection: true

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
					highlightMoveDuration: 180
					highlightMoveVelocity: -1
					highlightResizeDuration: 180
					highlightResizeVelocity: -1
					highlightRangeMode: followSelection ? ListView.ApplyRange : ListView.NoHighlightRange
					preferredHighlightBegin: Math.max(0, (height - 46) / 2)
					preferredHighlightEnd: preferredHighlightBegin + 46
					cacheBuffer: 184

					onCountChanged: positionViewAtBeginning()

					WheelHandler {
						target: null
						blocking: false
						onWheel: (event) => {
							list.followSelection = false
							event.accepted = false
						}
					}

					highlight: Rectangle {
						width: list.width
						radius: 14
						color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
						visible: list.currentItem !== null
					}

					delegate: Rectangle {
						id: row

						required property var modelData
						required property int index

						width: list.width
						height: 46
						radius: 14
						color: index !== launcher.selected && rowMouse.containsMouse
							? Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35) : "transparent"

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
							source: launcher.iconSource(row.modelData.icon)
							fillMode: Image.PreserveAspectFit
							asynchronous: source.toString().indexOf("image://") !== 0
							visible: status === Image.Ready
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
								if (list.moving || Date.now() - launcher.lastKeyNav < 400) return

								list.followSelection = false
								launcher.selected = row.index
							}
							onClicked: {
								launcher.selected = row.index
								launcher.launch()
							}
						}
					}
				}

				Text {
					id: emptyResults
					anchors.centerIn: list
					visible: opacity > 0.001
					opacity: launcher.results.length === 0 ? 1 : 0
					transform: Translate { y: 6 * (1 - emptyResults.opacity) }
					color: launcher.muted
					font.family: launcher.fontFamily
					font.pixelSize: 13
					text: "no apps found"
					Behavior on opacity {
						NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
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
