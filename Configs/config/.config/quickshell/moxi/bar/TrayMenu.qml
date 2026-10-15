import Quickshell
import QtQuick
import "../components"

PopupWindow {
	id: popup
	property var menu: null
	property var menuParent: null
	property string fontFamily: ""
	property int selected: -1
	property var submenuEntry: null
	property real submenuY: 0

	visible: false
	color: "transparent"
	grabFocus: true
	anchor.rect.width: 1
	anchor.rect.height: 1
	implicitWidth: Math.max(190, Math.min(380, labelMetrics.advanceWidth + 88))
	implicitHeight: Math.max(52, entries.height + 24)
	mask: Region { item: surface }

	function label(entry): string {
		return String(entry.text || "").replace(/&([^&])/g, "$1").replace(/&&/g, "&")
	}

	function open(): void { visible = true }
	function close(): void { visible = false }
	function focusMenu(): void { keys.forceActiveFocus() }
	function closeTree(): void {
		if (menuParent) menuParent.closeTree()
		else close()
	}

	function closeSubmenu(): void {
		submenuDelay.stop()
		submenuEntry = null
		submenuLoader.active = false
	}

	function showSubmenu(entry, y): void {
		if (!entry || !entry.enabled || !entry.hasChildren) return
		if (submenuEntry === entry && submenuLoader.active) return
		closeSubmenu()
		submenuEntry = entry
		submenuY = y
		submenuLoader.setSource(Qt.resolvedUrl("TrayMenu.qml"), {
			menu: entry, menuParent: popup, fontFamily: popup.fontFamily
		})
		submenuLoader.active = true
	}

	function activateEntry(entry, y): void {
		if (!entry || entry.isSeparator || !entry.enabled) return
		if (entry.hasChildren) showSubmenu(entry, y)
		else {
			entry.triggered()
			closeTree()
		}
	}

	function moveSelection(delta): void {
		var values = opener.children.values
		for (var i = 1; i <= values.length; ++i) {
			var index = (selected + delta * i + values.length) % values.length
			if (values[index].isSeparator || !values[index].enabled) continue
			closeSubmenu()
			selected = index
			return
		}
	}

	onVisibleChanged: {
		if (visible) Qt.callLater(function() { if (popup.visible) popup.focusMenu() })
		else {
			closeSubmenu()
			selected = -1
			if (menuParent && menuParent.visible) Qt.callLater(function() { if (popup.menuParent) popup.menuParent.focusMenu() })
		}
	}

	Theme { id: theme }
	QsMenuOpener {
		id: opener
		menu: popup.visible ? popup.menu : null
		onChildrenChanged: if (popup.visible && popup.selected < 0) popup.moveSelection(1)
	}
	TextMetrics {
		id: labelMetrics
		font.family: popup.fontFamily
		font.pixelSize: 13
		text: {
			var longest = ""
			var values = opener.children.values
			for (var i = 0; i < values.length; ++i) {
				var text = popup.label(values[i])
				if (text.length > longest.length) longest = text
			}
			return longest
		}
	}

	Loader {
		id: submenuLoader
		active: false
		onLoaded: {
			item.anchor.window = popup
			item.anchor.rect.x = popup.width - 8
			item.anchor.rect.y = popup.submenuY + 4
			item.open()
		}
	}

	Item {
		id: keys
		anchors.fill: parent
		focus: popup.visible
		Keys.onEscapePressed: popup.close()
		Keys.onLeftPressed: if (popup.menuParent) popup.close()
		Keys.onUpPressed: popup.moveSelection(-1)
		Keys.onDownPressed: popup.moveSelection(1)
		Keys.onRightPressed: {
			var row = rows.itemAt(popup.selected)
			if (row) popup.showSubmenu(row.modelData, entries.y + row.y)
		}
		Keys.onReturnPressed: {
			var row = rows.itemAt(popup.selected)
			if (row) popup.activateEntry(row.modelData, entries.y + row.y)
		}
		Keys.onEnterPressed: {
			var row = rows.itemAt(popup.selected)
			if (row) popup.activateEntry(row.modelData, entries.y + row.y)
		}
	}

	Timer {
		id: submenuDelay
		property var entry: null
		property real y: 0
		interval: 180
		onTriggered: if (popup.visible) popup.showSubmenu(entry, y)
	}

	Item {
		id: surface
		anchors.fill: parent
		anchors.margins: 4
		Squircle {
			anchors.fill: parent
			radius: 24
			power: 3
			fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.94)
			strokeColor: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
			strokeWidth: 1
		}

		Column {
			id: entries
			x: 8
			y: 8
			width: parent.width - 16
			spacing: 2
			Repeater {
				id: rows
				model: opener.children
				delegate: Rectangle {
					id: row
					required property var modelData
					required property int index
					readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
					readonly property bool hasIcon: modelData.icon.length > 0
					width: entries.width
					height: modelData.isSeparator ? 9 : 32
					radius: 10
					color: !modelData.isSeparator && modelData.enabled && popup.selected === index
						? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.1) : "transparent"
					Behavior on color { ColorAnimation { duration: 110 } }

					Rectangle {
						anchors.verticalCenter: parent.verticalCenter
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.margins: 8
						height: 1
						visible: row.modelData.isSeparator
						color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
					}
					Text {
						x: 10
						anchors.verticalCenter: parent.verticalCenter
						visible: !row.modelData.isSeparator && row.checkable
						text: row.modelData.checkState === Qt.Checked
							? (row.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓")
							: row.modelData.checkState === Qt.PartiallyChecked ? "−" : ""
						color: row.modelData.enabled ? theme.foreground : theme.muted
						font.pixelSize: 13
					}
					Image {
						x: row.checkable ? 32 : 10
						anchors.verticalCenter: parent.verticalCenter
						width: 16
						height: 16
						visible: !row.modelData.isSeparator && row.hasIcon
						source: row.modelData.icon
						fillMode: Image.PreserveAspectFit
					}
					Text {
						x: 10 + (row.checkable ? 22 : 0) + (row.hasIcon ? 24 : 0)
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - x - (row.modelData.hasChildren ? 30 : 12)
						visible: !row.modelData.isSeparator
						text: popup.label(row.modelData)
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: row.modelData.enabled ? theme.foreground : theme.muted
						font.family: popup.fontFamily
						font.pixelSize: 13
					}
					Text {
						anchors.right: parent.right
						anchors.rightMargin: 10
						anchors.verticalCenter: parent.verticalCenter
						visible: !row.modelData.isSeparator && row.modelData.hasChildren
						text: "›"
						font.pixelSize: 19
						color: theme.muted
					}
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						enabled: !row.modelData.isSeparator && row.modelData.enabled
						cursorShape: Qt.PointingHandCursor
						onEntered: {
							popup.selected = row.index
							if (row.modelData.hasChildren) {
								submenuDelay.entry = row.modelData
								submenuDelay.y = entries.y + row.y
								submenuDelay.restart()
							} else popup.closeSubmenu()
						}
						onExited: submenuDelay.stop()
						onClicked: popup.activateEntry(row.modelData, entries.y + row.y)
					}
				}
			}
		}
		Text {
			anchors.centerIn: parent
			visible: opener.children.values.length === 0
			text: "Loading menu…"
			font.family: popup.fontFamily
			font.pixelSize: 13
			color: theme.muted
		}
	}
}
