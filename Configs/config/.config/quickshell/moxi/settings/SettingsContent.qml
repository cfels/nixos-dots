pragma ComponentBehavior: Bound
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import "../components"

Item {
	id: window
	property bool active: visible
	required property var wallpaperLibrary
	readonly property bool transitioning: pageCrossover.busy
	property bool embedded: true
	property bool confirmRestore: false
	signal closeRequested
	property string category: "appearance"
	property string query: ""
	property bool confirmClear: false
	property string actionError: ""
	property var project: ({})
	property string selectedWallpaper: wallpaperLibrary.currentWallpaper
	property var selectedManifest: wallpaperLibrary.currentManifest
	property bool wallpaperVisited: false
	readonly property var categories: [
		{
			key: "appearance",
			label: "Appearance",
			icon: "palette"
		},
		{
			key: "wallpaper",
			label: "Wallpapers",
			icon: "wallpaper"
		},
		{
			key: "bar",
			label: "Bar & panel",
			icon: "bar_panels"
		},
		{
			key: "notifications",
			label: "Notifications",
			icon: "bell"
		},
		{
			key: "desktop",
			label: "Desktop & input",
			icon: "monitor-cog"
		},
		{
			key: "audio",
			label: "Audio & media",
			icon: "volume-2"
		},
		{
			key: "advanced",
			label: "About",
			icon: "info"
		}
	]
	readonly property var rows: Preferences.definitions.filter(item => (query.trim().length ? (!item.key.startsWith("premium.") || selectedManifest.manifestPath) && (item.label + " " + item.description + " " + item.key).toLowerCase().includes(query.toLowerCase().trim()) : !item.key.startsWith("premium.") && item.category === category))
	implicitWidth: 1040
	implicitHeight: 740
	onCategoryChanged: {
		if (category === "wallpaper")
			wallpaperVisited = true
		if (category === "advanced" && active)
			projectInfo.running = true
	}
	Component.onCompleted: wallpaperVisited = category === "wallpaper"
	function show(page) {
		selectCategory(page || "appearance")
	}
	function selectCategory(page) {
		const next = categories.findIndex(item => item.key === page)
		if (next < 0)
			return
		const previous = categories.findIndex(item => item.key === category)
		if (previous === next && !query)
			return
		pageScroll.stop()
		pageCrossover.change(function () {
			window.category = page
			search.clear()
			window.query = ""
			window.confirmClear = false
			content.contentY = 0
		}, -1)
	}
	function swipeCategory(direction) {
		if (confirmRestore || confirmClear)
			return true
		const index = categories.findIndex(item => item.key === category) + direction
		if (index < 0 || index >= categories.length)
			return false
		selectCategory(categories[index].key)
		return true
	}
	function requestRestore() {
		confirmRestore = true
	}
	function action(command) {
		if (!actionProcess.running) {
			actionError = ""
			actionProcess.command = command
			actionProcess.running = true
		}
	}

	Rectangle {
		anchors.fill: parent
		color: window.embedded ? "transparent" : Qt.rgba(SettingsStyle.theme.background.r, SettingsStyle.theme.background.g, SettingsStyle.theme.background.b, Preferences.opacity(0.94))
		radius: 30
		border.width: window.embedded ? 0 : 1
		border.color: Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.12)
		Keys.onEscapePressed: window.closeRequested()
		Shortcut {
			sequence: "Escape"
			enabled: window.active && !window.confirmRestore && !window.confirmClear
			onActivated: window.closeRequested()
		}
		Shortcut {
			sequence: "Ctrl+F"
			enabled: window.active
			onActivated: search.forceActiveFocus()
		}
		RowLayout {
			anchors.fill: parent
			anchors.margins: 16
			spacing: 16
			ColumnLayout {
				Layout.preferredWidth: window.width < 780 ? 148 : 176
				Layout.minimumWidth: window.width < 780 ? 148 : 176
				Layout.maximumWidth: window.width < 780 ? 148 : 176
				Layout.fillHeight: true
				spacing: 8
				RowLayout {
					Layout.fillWidth: true
					Text {
						Layout.fillWidth: true
						text: "Settings"
						color: SettingsStyle.theme.foreground
						font.family: SettingsStyle.fontFamily
						font.pixelSize: 18
					}
					SettingsButton {
						text: "Back"
						Accessible.name: "Back to panel"
						onClicked: window.closeRequested()
					}
				}
				SettingsField {
					id: search
					Layout.fillWidth: true
					placeholderText: "Search settings"
					Accessible.name: "Search settings"
					onTextChanged: {
						pageScroll.stop()
						window.query = text
						content.contentY = 0
					}
				}
				ListView {
					id: categoriesList
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					spacing: 4
					boundsBehavior: Flickable.StopAtBounds
					model: window.categories
					currentIndex: window.categories.findIndex(item => item.key === window.category)
					highlightFollowsCurrentItem: false
					highlight: Rectangle {
						width: categoriesList.width
						height: categoriesList.currentItem ? categoriesList.currentItem.height : 36
						y: categoriesList.currentItem ? categoriesList.currentItem.y : 0
						radius: 8
						color: Qt.rgba(SettingsStyle.theme.accent.r, SettingsStyle.theme.accent.g, SettingsStyle.theme.accent.b, 0.16)
						visible: !window.query
						Behavior on y {
							SmoothedAnimation {
								duration: Preferences.motion(230)
								velocity: -1
								maximumEasingTime: 110
							}
						}
					}
					delegate: SettingsCategoryButton {
						required property var modelData
						width: ListView.view.width
						text: modelData.label
						iconName: modelData.icon
						selected: window.category === modelData.key && !window.query
						onClicked: window.selectCategory(modelData.key)
					}
				}
				Text {
					Layout.fillWidth: true
					text: Preferences.saving ? "Saving…" : Preferences.applying ? "Applying…" : ""
					wrapMode: Text.WordWrap
					color: SettingsStyle.theme.muted
					font.family: SettingsStyle.fontFamily
					font.pixelSize: 10
				}
				SettingsButton {
					Layout.fillWidth: true
					text: "Restore defaults…"
					leftPadding: 32
					SettingsIcon {
						x: 8
						anchors.verticalCenter: parent.verticalCenter
						name: "undo-2"
					}
					enabled: !Preferences.saving && !Preferences.applying
					onClicked: window.requestRestore()
				}
			}
			Rectangle {
				Layout.fillHeight: true
				Layout.preferredWidth: 1
				color: Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.12)
			}
			ColumnLayout {
				id: settingsColumn
				Layout.fillWidth: true
				Layout.fillHeight: true
				spacing: 12
				RowLayout {
					Layout.fillWidth: true
					Text {
						Layout.fillWidth: true
						text: window.query ? "Search results" : window.categories.find(item => item.key === window.category).label
						font.family: SettingsStyle.fontFamily
						font.pixelSize: 18
						color: SettingsStyle.theme.foreground
					}
				}
				Item {
					id: statusMessage
					Layout.fillWidth: true
					Layout.topMargin: -settingsColumn.spacing * (1 - space)
					Layout.minimumHeight: 0
					Layout.preferredHeight: implicitHeight
					Layout.maximumHeight: implicitHeight
					readonly property string failure: Preferences.saveError || Preferences.applyError || Preferences.error || window.actionError
					readonly property string currentText: failure || Preferences.message
					property string shownText: ""
					property bool shownError: false
					property real reveal: currentText ? 1 : 0
					property real space: currentText || reveal > 0 ? 1 : 0
					implicitHeight: statusLabel.implicitHeight * space
					visible: space > 0 || reveal > 0
					function updateMessage(): void {
						if (currentText) {
							shownText = currentText
							shownError = failure.length > 0
						}
					}
					onCurrentTextChanged: updateMessage()
					Component.onCompleted: updateMessage()
					onSpaceChanged: if (space === 0 && !currentText && reveal === 0) shownText = ""
					Behavior on reveal {
						NumberAnimation {
							duration: Preferences.motion(300)
							easing.type: Easing.OutCubic
						}
					}
					Behavior on space {
						NumberAnimation {
							duration: Preferences.motion(180)
							easing.type: Easing.OutCubic
						}
					}
					Text {
						id: statusLabel
						width: parent.width
						text: statusMessage.shownText
						color: statusMessage.shownError ? SettingsStyle.theme.danger : SettingsStyle.theme.accent
						font.family: SettingsStyle.fontFamily
						font.pixelSize: 11
						wrapMode: Text.WordWrap
						opacity: statusMessage.reveal
						scale: 0.98 + 0.02 * statusMessage.reveal
						transformOrigin: Item.Left
						transform: Translate { y: -10 * (1 - statusMessage.reveal) }
						layer.enabled: statusMessage.reveal > 0 && statusMessage.reveal < 1
						layer.effect: MultiEffect {
							blurEnabled: true
							blurMax: 12
							blur: 0.65 * (1 - statusMessage.reveal)
							autoPaddingEnabled: true
						}
					}
				}
				Text {
					Layout.fillWidth: true
					visible: !window.query && (window.category === "appearance" || window.category === "desktop")
					text: window.category === "appearance" ? "Window changes apply automatically. Hyprland reloads briefly." : "Keyboard and pointer changes apply after a brief Hyprland reload."
					color: SettingsStyle.theme.muted
					font.family: SettingsStyle.fontFamily
					font.pixelSize: 10
					wrapMode: Text.WordWrap
				}
				Text {
					visible: !Preferences.ready
					text: "Loading settings…"
					color: SettingsStyle.theme.muted
					font.family: SettingsStyle.fontFamily
				}
				SettingsButton {
					visible: Preferences.applyError.length > 0
					text: "Try applying changes again"
					enabled: !Preferences.saving && !Preferences.applying
					onClicked: Preferences.applyHyprland()
				}
				SettingsCrossover {
					id: pageCrossover
					Layout.fillWidth: true
					Layout.fillHeight: true
					Flickable {
						id: content
						parent: pageCrossover.contentHost
						anchors.fill: parent
						enabled: !Preferences.restoring
						clip: true
						contentWidth: width
						contentHeight: pageContent.implicitHeight
						boundsBehavior: Flickable.StopAtBounds
						ScrollBar.vertical: ScrollBar {}
						SmoothScroll {
							id: pageScroll
							view: content
							step: 150
							duration: 90
						}
						ColumnLayout {
							id: pageContent
							width: content.width - 12
							spacing: 0
							Loader {
								id: wallpaperPage
								Layout.fillWidth: true
								active: window.active && window.wallpaperVisited
								visible: active && !window.query && window.category === "wallpaper"
								sourceComponent: WallpapersPage {
									controller: window.wallpaperLibrary
								}
							}
							Loader {
								Layout.fillWidth: true
								active: window.active && !window.query && window.category === "audio"
								visible: active
								sourceComponent: AudioPage {}
							}

							Repeater {
								model: window.rows
								SettingRow {
									required property var modelData
									Layout.fillWidth: true
									definition: modelData
									wallpaper: window.selectedManifest.manifestPath || ""
									manifest: window.selectedManifest.defaults || ({})
								}
							}
							Text {
								visible: window.query.length > 0 && window.rows.length === 0
								text: "No matching settings"
								color: SettingsStyle.theme.muted
								font.family: SettingsStyle.fontFamily
							}

							SettingsButton {
								visible: !window.query && window.category === "notifications"
								Layout.topMargin: 12
								Layout.bottomMargin: 12
								text: "Send test notification"
								onClicked: window.action(["notify-send", "-a", "Settings", "Test notification", "This is a test notification. Do not disturb hides it too."])
							}
							SettingsButton {
								visible: !window.query && window.category === "desktop" && !window.confirmClear
								Layout.topMargin: 12
								Layout.bottomMargin: 12
								text: "Clear clipboard history…"
								danger: true
								onClicked: window.confirmClear = true
							}
							RowLayout {
								visible: !window.query && window.category === "desktop" && window.confirmClear
								Layout.topMargin: 12
								Layout.bottomMargin: 12
								Text {
									Layout.fillWidth: true
									text: "Clear all saved clipboard entries and the current clipboard?"
									color: SettingsStyle.theme.danger
									wrapMode: Text.WordWrap
									font.family: SettingsStyle.fontFamily
									font.pixelSize: 12
								}
								SettingsButton {
									text: "Cancel"
									onClicked: window.confirmClear = false
								}
								SettingsButton {
									text: "Clear history"
									danger: true
									onClicked: {
										window.action(["qs", "-c", "moxi", "ipc", "call", "--", "clipboard", "clear"])
										window.confirmClear = false
									}
								}
							}
							ColumnLayout {
								Layout.fillWidth: true
								visible: !window.query && window.category === "advanced"
								spacing: 8
								Text {
									text: "Rice version"
									color: SettingsStyle.theme.foreground
									font.family: SettingsStyle.fontFamily
									font.pixelSize: 13
								}
								Text {
									Layout.fillWidth: true
									text: window.project.commit || "Version information unavailable"
									color: SettingsStyle.theme.muted
									font.family: SettingsStyle.fontFamily
									font.pixelSize: 12
									wrapMode: Text.WordWrap
								}
							}
						}
					}
				}
			}
		}
	}
	Popup {
		id: restoreDialog
		anchors.centerIn: parent
		width: Math.min(window.width - 48, 440)
		padding: 24
		modal: true
		focus: true
		visible: window.confirmRestore
		onClosed: window.confirmRestore = false
		closePolicy: Popup.CloseOnEscape
		background: SettingsPopupSurface {
			radius: 20
			opened: restoreDialog.visible
			sourceItem: SettingsStyle.popupSource(window, window.Window.window ? window.Window.window.contentItem : null)
		}
		contentItem: ColumnLayout {
			spacing: 16
			Text {
				Layout.fillWidth: true
				text: "Restore all defaults?"
				color: SettingsStyle.theme.foreground
				font.family: SettingsStyle.fontFamily
				font.pixelSize: 16
				wrapMode: Text.WordWrap
			}
			Text {
				Layout.fillWidth: true
				text: "Reset appearance, panel, notification, input, media and PremiumWalls settings to their original defaults. Your wallpapers, files, clipboard history, device volumes and mouse DPI are kept. Hyprland changes apply automatically."
				color: SettingsStyle.theme.muted
				font.family: SettingsStyle.fontFamily
				font.pixelSize: 12
				wrapMode: Text.WordWrap
			}
			RowLayout {
				Layout.alignment: Qt.AlignRight
				spacing: 8
				SettingsButton {
					text: "Cancel"
					onClicked: restoreDialog.close()
				}
				SettingsButton {
					text: "Restore defaults"
					emphasized: true
					enabled: !Preferences.saving && !Preferences.applying
					onClicked: {
						Preferences.restoreDefaults()
						restoreDialog.close()
					}
				}
			}
		}
	}

	Process {
		id: actionProcess
		stderr: StdioCollector {
			id: actionStderr
		}
		onExited: (code, status) => {
			if (code !== 0)
				window.actionError = actionStderr.text.trim() || "Couldn't complete this action"
		}
	}
	Process {
		id: projectInfo
		command: ["python3", Preferences.helper, "info"]
		stdout: StdioCollector {
			id: projectOutput
		}
		stderr: StdioCollector {
			id: projectError
		}
		onExited: (code, status) => {
			if (code !== 0) {
				window.actionError = projectError.text.trim()
				return
			}
			try {
				window.project = JSON.parse(projectOutput.text)
			} catch (problem) {
				window.actionError = String(problem)
			}
		}
	}
}
