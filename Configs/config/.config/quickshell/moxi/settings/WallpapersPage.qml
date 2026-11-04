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
	property string selectedWallpaper: ""
	property var manifest: ({})
	property string error: ""
	property string status: ""
	readonly property bool premium: /\.premiumwall\.json$/i.test(selectedWallpaper)
	readonly property string manifestPath: manifest.manifestPath || selectedWallpaper
	spacing: 12
	PanelFonts {
		id: fonts
	}
	FileView {
		id: current
		path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: {
			page.selectedWallpaper = text().trim()
			if (page.premium)
				metadata.running = true
			else
				page.manifest = ({})
		}
	}
	FileView {
		path: page.premium ? page.selectedWallpaper : ""
		watchChanges: true
		printErrors: false
		onFileChanged: {
			reload()
			metadata.running = true
		}
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
			text: "Choose file…"
			onClicked: chooser.open()
		}
		SettingsButton {
			text: "Renderer status"
			enabled: !diagnostic.running
			onClicked: diagnostic.running = true
		}
	}
	Text {
		Layout.fillWidth: true
		text: library.error || page.error || page.status
		visible: text.length > 0
		font.family: SettingsStyle.fontFamily
		font.pixelSize: 11
		color: library.error || page.error ? SettingsStyle.theme.danger : SettingsStyle.theme.muted
		wrapMode: Text.WrapAnywhere
	}
	Repeater {
		model: Preferences.definitions.filter(item => item.key.startsWith("premium."))
		SettingRow {
			required property var modelData
			Layout.fillWidth: true
			visible: page.premium
			definition: modelData
			wallpaper: page.manifestPath
			manifest: page.manifest.defaults || page.manifest
		}
	}
	FileDialog {
		id: chooser
		title: "Select wallpaper"
		nameFilters: ["Wallpapers (*.png *.jpg *.jpeg *.webp *.gif *.mp4 *.m4v *.webm *.mkv *.mov *.avi *.premiumwall.json)"]
		onAccepted: library.setWallpaper(decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
	}
	Process {
		id: metadata
		command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/premium-wallpaper.py", "describe", page.selectedWallpaper]
		stdout: StdioCollector {
			id: metadataOutput
		}
		stderr: StdioCollector {
			id: metadataError
		}
		onExited: (code, exitStatus) => {
			if (code !== 0) {
				page.error = metadataError.text.trim()
				return
			}
			try {
				page.manifest = JSON.parse(metadataOutput.text)
				page.error = ""
			} catch (problem) {
				page.error = String(problem)
			}
		}
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
				page.error = diagnosticError.text.trim() || "Wallpaper renderer is not running"
				return
			}
			try {
				const data = JSON.parse(diagnosticOutput.text)
				page.status = data.state + " · " + data.outputs.length + " output(s)"
				page.error = data.error || ""
			} catch (problem) {
				page.error = String(problem)
			}
		}
	}
}
