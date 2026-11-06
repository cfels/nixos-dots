import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import "../components"
import "../panel"

ColumnLayout {
	id: page
	required property WallpaperController controller
	readonly property var library: controller
	readonly property string selectedWallpaper: controller.currentWallpaper
	readonly property var manifest: controller.currentManifest
	property var optionsManifest: ({})
	property string error: ""
	property string status: ""
	readonly property bool premium: /\.premiumwall\.json$/i.test(selectedWallpaper)
	readonly property string manifestPath: optionsManifest.manifestPath || selectedWallpaper
	function rememberOptions(): void {
		if (premium && manifest.manifestPath)
			optionsManifest = manifest
	}
	onManifestChanged: rememberOptions()
	onPremiumChanged: rememberOptions()
	Component.onCompleted: rememberOptions()
	spacing: 12
	PanelFonts {
		id: fonts
	}
	WallpaperView {
		Layout.fillWidth: true
		Layout.preferredHeight: implicitHeight
		expandedGallery: true
		columns: 3
		previewHeight: Math.round(width * 9 / 16)
		controller: library
		active: page.visible
		theme: SettingsStyle.theme
		fontFamily: fonts.fontFamily
	}
	RowLayout {
		SettingsButton {
			text: "Choose a wallpaper…"
			onClicked: chooser.open()
		}
		SettingsButton {
			text: "Wallpaper status"
			enabled: !diagnostic.running
			onClicked: diagnostic.running = true
		}
	}
	Text {
		Layout.fillWidth: true
		text: library.error || library.metadataError || page.error || page.status
		visible: text.length > 0
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 11
		color: library.error || library.metadataError || page.error ? SettingsStyle.theme.danger : SettingsStyle.theme.muted
		wrapMode: Text.WrapAnywhere
	}
	Item {
		id: premiumOptions
		Layout.fillWidth: true
		Layout.minimumHeight: 0
		implicitHeight: optionsContent.implicitHeight * reveal
		Layout.preferredHeight: implicitHeight
		Layout.maximumHeight: implicitHeight
		property real reveal: page.premium && page.manifest.manifestPath ? 1 : 0
		opacity: reveal
		clip: true
		enabled: page.premium && !!page.manifest.manifestPath
		Behavior on reveal {
			NumberAnimation {
				duration: Preferences.motion(page.premium ? 240 : 180)
				easing.type: Easing.OutCubic
			}
		}
		ColumnLayout {
			id: optionsContent
			width: parent.width
			y: -8 * (1 - premiumOptions.reveal)
			spacing: page.spacing
			Repeater {
				model: Preferences.definitions.filter(item => item.key.startsWith("premium."))
				SettingRow {
					required property var modelData
					Layout.fillWidth: true
					definition: modelData
					wallpaper: page.manifestPath
					manifest: page.optionsManifest.defaults || page.optionsManifest
				}
			}
		}
	}
	FileDialog {
		id: chooser
		title: "Choose a wallpaper"
		nameFilters: ["Wallpapers (*.png *.jpg *.jpeg *.webp *.gif *.mp4 *.m4v *.webm *.mkv *.mov *.avi *.premiumwall.json)"]
		onAccepted: library.setWallpaper(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
	}
	Process {
		id: diagnostic
		command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-render.py", "--status"]
		stdout: StdioCollector {
			id: diagnosticOutput
		}
		stderr: StdioCollector {
			id: diagnosticError
		}
		onExited: (code, exitStatus) => {
			if (code !== 0) {
				page.error = diagnosticError.text.trim() || "The wallpaper renderer isn't running"
				return
			}
			try {
				const data = JSON.parse(diagnosticOutput.text)
				page.status = data.state + " · " + data.outputs.length + (data.outputs.length === 1 ? " screen" : " screens")
				page.error = data.error || ""
			} catch (problem) {
				page.error = String(problem)
			}
		}
	}
}
