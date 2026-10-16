import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../components"

PanelWindow {
	id: clipboard

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
		clipboard.anchorWidth = width
		clipboard.anchorHeight = height
		clipboard.anchorTop = y
	}
	property var entries: []
	property int selected: 0
	property int previewVersion: 0
	property var readyIds: []
	property var screenshotIds: []
	property var stagedEntries: []
	property bool previewsDirty: true
	property string pendingSelection: ""
	property string previewDir: Quickshell.env("HOME") + "/.cache/moxi-clip"
	property var revealedIds: []
	readonly property var selectedEntry: selected >= 0 && selected < entries.length ? entries[selected] : null
	readonly property bool selectedImage: selectedEntry !== null && clipboard.isImage(selectedEntry.preview)

	function isImage(preview): bool {
		return clipboard.isBinary(preview) && /\b(?:png|jpe?g|webp|gif|bmp|tiff|image\/[a-z0-9.+-]+)\b/i.test(preview)
	}

	function isEmojiOnly(preview): bool {
		var emoji = /[\u00A9\u00AE\u203C\u2049\u2122\u2139\u2194-\u2199\u21A9\u21AA\u231A\u231B\u2328\u23CF\u23E9-\u23F3\u23F8-\u23FA\u24C2\u25AA\u25AB\u25B6\u25C0\u25FB-\u25FE\u2600-\u27BF\u2934\u2935\u2B05-\u2B07\u2B1B\u2B1C\u2B50\u2B55\u3030\u303D\u3297\u3299\u{1F000}-\u{1FAFF}][\uFE0E\uFE0F]?[\u{1F3FB}-\u{1F3FF}]?/gu
		var text = preview.trim().replace(emoji, "").replace(/[0-9#*]\uFE0F?\u20E3/g, "")
		return text.length < preview.trim().length && /^[\s\u200D\u{E0020}-\u{E007F}]*$/u.test(text)
	}

	function looksSensitive(preview): bool {
		var text = String(preview || "").trim()
		if (/-----BEGIN (?:[A-Z ]*PRIVATE KEY|OPENSSH PRIVATE KEY)-----/.test(text)) return true
		if (/\b(?:password|passwd|pwd|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|secret|token)\b\s*[=:]\s*\S+/i.test(text)) return true
		if (/\b(?:Bearer\s+\S+|(?:sk-(?:proj-|ant-)?|github_pat_|gh[pousr]_|xox[baprs]-)[A-Za-z0-9_-]{12,}|(?:AKIA|ASIA)[A-Z0-9]{16})/.test(text)) return true
		if (/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/.test(text)) return true
		if (/\b(?:cvv2?|cvc2?|security[ _-]?code|(?:card[ _-]?)?pin(?:[ _-]?code)?|iban|bank[ _-]?account(?:[ _-]?(?:number|no|num))?)\b\s*(?:[:=]\s*|\s+)(?:[A-Z]{2}\d{2}|\d{3,})/i.test(text)) return true

		var numberRuns = text.match(/\b\d(?:[ \t\u00a0\u202f\u2009-]*\d){12,18}\b/g) || []
		for (var numberIndex = 0; numberIndex < numberRuns.length; ++numberIndex) {
			var number = numberRuns[numberIndex]
			if (/\b(?:\d{4}-\d{2}-\d{2}|\d{2}-\d{2}-\d{4})\b/.test(number)) continue
			return true
		}

		if (/\s/.test(text) || /^\w+:\/\//.test(text) || text.charAt(0) === "/") return false
		if (/^[a-f0-9]{32,}$/i.test(text)) return true
		if (text.length < 12 || /[^\x21-\x7e]/.test(text)) return false

		var lower = /[a-z]/.test(text)
		var upper = /[A-Z]/.test(text)
		var digit = /[0-9]/.test(text)
		var symbol = /[^A-Za-z0-9]/.test(text)
		if (!(lower && upper && digit && (symbol || text.length >= 20))) return false

		var counts = ({})
		for (var i = 0; i < text.length; ++i) counts[text[i]] = (counts[text[i]] || 0) + 1
		var entropy = 0
		for (var character in counts) {
			var probability = counts[character] / text.length
			entropy -= probability * Math.log(probability) / Math.LN2
		}
		return entropy >= 3.2
	}

	function toggleReveal(id): void {
		var position = clipboard.revealedIds.indexOf(id)
		if (position === -1) clipboard.revealedIds = clipboard.revealedIds.concat([id])
		else clipboard.revealedIds = clipboard.revealedIds.filter(function(value) { return value !== id })
	}

	function hasPreview(entry): bool {
		return entry && entry.binary && clipboard.readyIds.indexOf(entry.id) !== -1
	}

	function isBinary(preview): bool {
		return preview.indexOf("[[ binary data") === 0
	}

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property real cornerRadius: clipboard.open ? 30 : 19

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
	WlrLayershell.keyboardFocus: !clipboard.surfaceHost && clipboard.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
	focusable: true
	color: "transparent"
	mask: Region { item: inputArea }

	function refresh(keepSelection): void {
		if (lister.running) return
		var previous = clipboard.entries.length > clipboard.selected && clipboard.selected >= 0
			? clipboard.entries[clipboard.selected].id
			: ""

		clipboard.stagedEntries = []
		lister.binaryIds = []
		clipboard.pendingSelection = keepSelection === true ? previous : ""
		lister.running = true
	}

	function show(): void {
		clipboard.revealedIds = []
		clipboard.open = true
		clipboard.refresh()
		focusTimer.restart()
	}

	function hide(): void {
		clipboard.revealedIds = []
		clipboard.open = false
	}

	function toggle(): void {
		if (clipboard.open) clipboard.hide()
		else clipboard.show()
	}

	function copy(id): void {
		if (id === undefined || id === null || id === "") return

		copier.entryId = String(id)
		copier.running = true
		clipboard.hide()
	}

	IpcHandler {
		target: "clipboard"

		function toggle(): void {
			clipboard.toggle()
		}

		function show(): void {
			clipboard.show()
		}

		function hide(): void {
			clipboard.hide()
		}

		function clear(): void {
			clearer.running = true
		}
	}

	Process {
		id: lister

		property var binaryIds: []

		command: ["bash", "-c", "cliphist list 2>/dev/null | head -200"]

		stdout: SplitParser {
			onRead: (line) => {
				var separator = line.indexOf("\t")

				if (separator <= 0) return

				var id = line.substring(0, separator)
				var preview = line.substring(separator + 1)
				var binary = clipboard.isBinary(preview)

				clipboard.stagedEntries = clipboard.stagedEntries.concat([{
					id: id,
					preview: preview,
					binary: binary
				}])

				if (binary && clipboard.isImage(preview)) lister.binaryIds = lister.binaryIds.concat([id])
			}
		}
	}

	Process {
		id: previewDump
		property var requestedIds: []

		command: [
			"bash",
			Quickshell.shellDir + "/clipboard/preview-images.sh",
			clipboard.previewDir,
			Quickshell.env("HOME") + "/screenshots"
		].concat(previewDump.requestedIds)

		stdout: SplitParser {
			onRead: (line) => {
				var fields = line.split("\t")
				var id = fields[0]
				if (!id.length) return
				if (fields[1] === "Screenshot" && clipboard.screenshotIds.indexOf(id) === -1) clipboard.screenshotIds = clipboard.screenshotIds.concat([id])
				if (clipboard.readyIds.indexOf(id) === -1) clipboard.readyIds = clipboard.readyIds.concat([id])
			}
		}

		onExited: (code, status) => clipboard.previewVersion++
	}

	Process {
		id: copier

		property string entryId: ""

		command: ["bash", "-c", "cliphist decode \"$1\" | wl-copy", "clipboard", copier.entryId]
	}

	Process {
		id: clearer

		command: ["bash", "-c", "cliphist wipe && wl-copy --clear"]

		onExited: (code, status) => clipboard.refresh()
	}

	Connections {
		target: lister

		function onRunningChanged() {
			if (lister.running) return

			var staged = clipboard.stagedEntries
			var ids = staged.map(function(entry) { return entry.id })
			clipboard.readyIds = clipboard.readyIds.filter(function(id) { return ids.indexOf(id) !== -1 })
			clipboard.screenshotIds = clipboard.screenshotIds.filter(function(id) { return ids.indexOf(id) !== -1 })
			var changed = staged.length !== clipboard.entries.length

			if (!changed) {
				for (var i = 0; i < staged.length; ++i) {
					if (staged[i].id !== clipboard.entries[i].id
						|| staged[i].preview !== clipboard.entries[i].preview) {
						changed = true
						break
					}
				}
			}

			if (changed) {
				clipboard.entries = staged
				clipboard.previewsDirty = true
			}

			if (clipboard.pendingSelection.length > 0) {
				for (var j = 0; j < clipboard.entries.length; ++j) {
					if (clipboard.entries[j].id === clipboard.pendingSelection) {
						clipboard.selected = j
						break
					}
				}

				clipboard.pendingSelection = ""
			}

			if (!previewDump.running && (clipboard.previewsDirty || lister.binaryIds.some(function(id) { return clipboard.readyIds.indexOf(id) === -1 }))) {
				clipboard.previewsDirty = false
				previewDump.requestedIds = lister.binaryIds
				previewDump.running = true
			}
		}
	}

	Timer {
		id: liveRefresh

		interval: 1000
		running: clipboard.open
		repeat: true

		onTriggered: clipboard.refresh(true)
	}

	Timer {
		id: focusTimer
		interval: 80
		onTriggered: if (clipboard.open) keys.forceActiveFocus()
	}

	Item {
		id: keys
		parent: cardSource

		anchors.fill: parent
		focus: clipboard.open

		Keys.onDownPressed: clipboard.selected = Math.min(clipboard.selected + 1, clipboard.entries.length - 1)
		Keys.onUpPressed: clipboard.selected = Math.max(clipboard.selected - 1, 0)
		Keys.onReturnPressed: clipboard.copy(clipboard.entries[clipboard.selected] ? clipboard.entries[clipboard.selected].id : "")
		Keys.onEnterPressed: clipboard.copy(clipboard.entries[clipboard.selected] ? clipboard.entries[clipboard.selected].id : "")
		Keys.onEscapePressed: clipboard.hide()
	}

	Item {
		id: cardHost

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: clipboard.open ? 50 : clipboard.anchorTop
		width: clipboard.open ? 640 : clipboard.anchorWidth
		height: clipboard.open ? 460 : clipboard.anchorHeight
		opacity: clipboard.open ? 1 : 0

		Behavior on width {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on y {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		scale: clipboard.open ? 1 : 0.94
		transformOrigin: Item.Center

		Behavior on scale {
			NumberAnimation {
				duration: clipboard.open ? 300 : 210
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.16, 1, 0.3, 1]
			}
		}

		Behavior on opacity {
			NumberAnimation { duration: clipboard.open ? 220 : 160 }
		}

		Item {
			id: cardSource

			parent: clipboard.surfaceHost || cardHost
			visible: true
			width: parent.width
			height: parent.height

			Squircle {
				visible: !clipboard.surfaceHost
				anchors.fill: parent
				power: 4
				radius: clipboard.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.74)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.26)
				strokeWidth: 1
			}

			Item {
				anchors.fill: parent
				anchors.margins: 22

				Text {
					id: title

					anchors.left: parent.left
					anchors.verticalCenter: headerRow.verticalCenter
					color: clipboard.foreground
					font.family: clipboard.fontFamily
					font.pixelSize: 16
					font.weight: Font.DemiBold
					text: "Clipboard"
				}

				Item {
					id: headerRow

					anchors.top: parent.top
					anchors.left: parent.left
					anchors.right: parent.right
					height: 34
				}

				Rectangle {
					id: clearButton

					anchors.right: parent.right
					anchors.verticalCenter: headerRow.verticalCenter
					width: clearLabel.implicitWidth + 26
					height: 30
					radius: 15
					color: clearMouse.containsMouse
						? Qt.rgba(theme.danger.r, theme.danger.g, theme.danger.b, 0.3)
						: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35)

					Behavior on color {
						ColorAnimation { duration: 130 }
					}

					Text {
						id: clearLabel

						anchors.centerIn: parent
						color: theme.danger
						font.family: clipboard.fontFamily
						font.pixelSize: 12
						text: "Clear all"
					}

					MouseArea {
						id: clearMouse

						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: clearer.running = true
					}
				}

				ListView {
					id: list

					anchors.top: headerRow.bottom
					anchors.topMargin: 12
					anchors.left: parent.left
					width: parent.width - (imagePreview.width + 12) * imagePreview.layoutPresence
					anchors.bottom: parent.bottom
					clip: true
					spacing: 4
					model: clipboard.entries
					currentIndex: clipboard.selected
					highlightFollowsCurrentItem: false
					highlight: Rectangle {
						width: list.width
						height: list.currentItem ? list.currentItem.height : 0
						y: list.currentItem ? list.currentItem.y : 0
						radius: 13
						color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
						visible: list.currentItem !== null
						Behavior on y { SmoothedAnimation { duration: 180; velocity: -1 } }
						Behavior on height { SmoothedAnimation { duration: 180; velocity: -1 } }
					}

					delegate: Rectangle {
						id: row

						required property var modelData
						required property int index
						readonly property bool sensitive: !modelData.binary && clipboard.looksSensitive(modelData.preview)
						readonly property bool concealed: sensitive && clipboard.revealedIds.indexOf(modelData.id) === -1
						readonly property bool emojiOnly: !modelData.binary && clipboard.isEmojiOnly(modelData.preview)

						width: list.width
						height: row.modelData.binary && thumb.ready ? 72 : 42
						radius: 13
						color: index !== clipboard.selected && rowMouse.containsMouse
							? Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.35) : "transparent"

						Behavior on color {
							ColorAnimation { duration: 120 }
						}

						Behavior on height {
							SmoothedAnimation { duration: 250; velocity: -1 }
						}

						Text {
							anchors.left: parent.left
							anchors.leftMargin: row.modelData.binary && thumb.ready ? 104 : 14
							anchors.right: parent.right
							anchors.rightMargin: row.sensitive ? 86 : 14
							anchors.verticalCenter: parent.verticalCenter
							color: clipboard.foreground
							elide: Text.ElideRight
							font.family: row.emojiOnly ? "Noto Color Emoji" : clipboard.fontFamily
							font.pixelSize: row.emojiOnly ? 26 : 15
							text: row.concealed ? "••••••••••••" : row.modelData.binary && thumb.ready
								? (clipboard.screenshotIds.indexOf(row.modelData.id) !== -1 ? "Screenshot" : "Image") : row.modelData.preview
							textFormat: Text.PlainText
							wrapMode: Text.NoWrap
							Behavior on anchors.leftMargin { SmoothedAnimation { duration: 250; velocity: -1 } }
						}

						SquircleImage {
							id: thumb

							anchors.left: parent.left
							anchors.leftMargin: 8
							anchors.verticalCenter: parent.verticalCenter
							width: 84
							height: 56
							radius: 9
							power: 4
							sourceWidth: 168
							sourceHeight: 112
							opacity: row.modelData.binary && thumb.ready ? 1 : 0
							visible: opacity > 0.001
							Behavior on opacity { SmoothedAnimation { duration: 220; velocity: -1 } }
							source: clipboard.isImage(row.modelData.preview) && clipboard.hasPreview(row.modelData)
								? "file://" + clipboard.previewDir + "/" + row.modelData.id + ".png"
								: ""
						}

						MouseArea {
							id: rowMouse

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onEntered: clipboard.selected = row.index
							onClicked: clipboard.copy(row.modelData.id)
						}

						Rectangle {
							anchors.right: parent.right
							anchors.rightMargin: 10
							anchors.verticalCenter: parent.verticalCenter
							width: 64
							height: 26
							radius: 13
							visible: row.sensitive
							color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, revealMouse.containsMouse ? 0.28 : 0.14)

							Text {
								anchors.centerIn: parent
								text: row.concealed ? "Show" : "Hide"
								color: clipboard.foreground
								font.family: clipboard.fontFamily
								font.pixelSize: 11
							}

							MouseArea {
								id: revealMouse
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: clipboard.toggleReveal(row.modelData.id)
							}
						}
					}
				}

				Rectangle {
					id: imagePreview
					property real presence: clipboard.selectedImage ? 1 : 0
					readonly property real layoutPresence: Math.max(0, Math.min(1, presence))
					anchors.top: headerRow.bottom
					anchors.topMargin: 12
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					width: 230
					radius: 20
					visible: presence > 0.001
					opacity: layoutPresence
					scale: 0.985 + layoutPresence * 0.015
					transformOrigin: Item.Right
					transform: Translate { x: (1 - imagePreview.layoutPresence) * 6 }
					color: Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, 0.28)
					border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.08)
					border.width: 1

					Behavior on presence {
						SmoothedAnimation { duration: 330; velocity: -1; reversingMode: SmoothedAnimation.Eased }
					}

					ImagePreview {
						anchors.fill: parent
						anchors.margins: 12
						active: clipboard.open && clipboard.selectedImage
						source: clipboard.selectedImage && clipboard.hasPreview(clipboard.selectedEntry)
							? "file://" + clipboard.previewDir + "/" + clipboard.selectedEntry.id + ".png" : ""
						textColor: clipboard.muted
						fontFamily: clipboard.fontFamily
					}
				}

				Text {
					anchors.centerIn: parent
					visible: clipboard.entries.length === 0
					color: clipboard.muted
					font.family: clipboard.fontFamily
					font.pixelSize: 13
					text: "Clipboard history is empty"
				}
			}
		}

	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: cardHost.top
		width: clipboard.open ? cardHost.width : 0
		height: clipboard.open ? cardHost.height : 0
	}
}
