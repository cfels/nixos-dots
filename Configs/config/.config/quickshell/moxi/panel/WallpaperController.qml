import Quickshell
import Quickshell.Io
import QtQuick
import "../components"
import Qt.labs.folderlistmodel

Scope {
	id: wallpapers

	property bool expanded: false
	property bool initialized: false
	property string error: ""
	readonly property string libraryDirectory: Preferences.value("wallpaper.libraryDirectory", "~/walls").replace(/^~(?=\/)/, Quickshell.env("HOME"))
	onLibraryDirectoryChanged: if (initialized)
		refreshDebounce.restart()
	Component.onCompleted: {
		initialized = true
		startScan(true)
	}
	function startScan(cachedOnly): void {
		if (scan.running) {
			scan.pending = true
			return
		}
		scan.directory = libraryDirectory
		scan.cachedOnly = cachedOnly
		scan.running = true
	}

	property var wallpapers: []
	property var wallThumbs: ({})
	property var wallPreviews: ({})
	property bool wallpaperTool: false
	property string currentWallpaper: ""
	property string previewWallpaper: ""
	property string hoveredWallpaper: ""
	property var manifests: ({})
	property string metadataError: ""
	readonly property var currentManifest: manifests[currentWallpaper] || ({})
	readonly property bool currentPremium: /\.premiumwall\.json$/i.test(currentWallpaper)

	onCurrentWallpaperChanged: {
		metadataError = ""
		if (currentWallpaper && !hoveredWallpaper)
			previewWallpaper = currentWallpaper
		loadManifest(false)
	}

	onExpandedChanged: {
		if (expanded && currentWallpaper)
			previewWallpaper = currentWallpaper
	}

	function rememberManifest(path, data): void {
		if (path === currentWallpaper)
			metadataError = ""
		if (JSON.stringify(manifests[path]) === JSON.stringify(data))
			return
		const updated = Object.assign({}, manifests)
		updated[path] = data
		manifests = updated
	}

	function loadManifest(refresh): void {
		if (!/\.premiumwall\.json$/i.test(currentWallpaper))
			return
		if (refresh) {
			const updated = Object.assign({}, manifests)
			delete updated[currentWallpaper]
			manifests = updated
		}
		if (manifests[currentWallpaper])
			return
		if (metadata.running) {
			metadata.pending = true
			metadata.refreshPending = metadata.refreshPending || refresh
			return
		}
		metadata.target = currentWallpaper
		metadata.running = true
	}

	function wallpaperIsVideo(path): bool {
		return /\.(mp4|m4v|webm|mkv|mov|avi|premiumwall\.json)$/i.test("" + path)
	}

	function wallpaperIsAnimated(path): bool {
		return /\.gif$/i.test("" + path)
	}

	function wallpaperThumb(path): string {
		var thumb = wallpapers.wallThumbs["" + path]
		return thumb || (manifests[path] || {}).posterPath || ""
	}

	function wallpaperPreview(path): string {
		var preview = wallpapers.wallPreviews["" + path]
		return preview === undefined ? "" : preview
	}

	function wallpaperSource(path): string {
		if (("" + path).length === 0)
			return ""

		if (wallpapers.wallpaperIsVideo(path)) {
			var preview = wallpapers.wallpaperPreview(path)
			return preview.length > 0 ? preview : wallpapers.wallpaperThumb(path)
		}

		return wallpapers.wallpaperIsAnimated(path) ? "" + path : wallpapers.wallpaperThumb(path) || "" + path
	}

	function wallpaperSourceAnimated(path): bool {
		if (wallpapers.wallpaperIsVideo(path))
			return wallpapers.wallpaperPreview(path).length > 0

		return wallpapers.wallpaperIsAnimated(path)
	}

	function setWallpaper(path): void {
		if (setter.running) {
			setter.pendingTarget = path
			return
		}
		setter.target = path
		setter.running = true
	}

	FolderListModel {
		folder: "file://" + wallpapers.libraryDirectory
		showDirs: false
		showHidden: true

		onCountChanged: refreshDebounce.restart()
		onDataChanged: refreshDebounce.restart()
	}

	Process {
		id: scan

		property var found: []
		property var thumbs: ({})
		property var previews: ({})
		property string signature: ""
		property bool pending: false
		property bool cachedOnly: true
		property string directory: ""

		command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-list.sh", directory].concat(cachedOnly ? ["--cached"] : [])

		stdout: SplitParser {
			onRead: line => {
				const fields = line.split("\t")
				const path = fields[0]

				if (path.length === 0 || scan.found.indexOf(path) !== -1)
					return
				scan.found = scan.found.concat([path])

				if (fields[1] && fields[1].length > 0)
					scan.thumbs[path] = fields[1]
				if (fields[2] && fields[2].length > 0)
					scan.previews[path] = fields[2]
				if (fields[3]) {
					try {
						wallpapers.rememberManifest(path, JSON.parse(fields[3]))
					} catch (problem) {
						wallpapers.metadataError = "Couldn't read wallpaper details: " + problem
					}
				}
				if (!scan.cachedOnly && scan.directory === wallpapers.libraryDirectory) {
					if (fields[1] && wallpapers.wallThumbs[path] !== fields[1]) {
						const thumbs = Object.assign({}, wallpapers.wallThumbs)
						thumbs[path] = fields[1]
						wallpapers.wallThumbs = thumbs
					}
					if (fields[2] && wallpapers.wallPreviews[path] !== fields[2]) {
						const previews = Object.assign({}, wallpapers.wallPreviews)
						previews[path] = fields[2]
						wallpapers.wallPreviews = previews
					}
				}
			}
		}

		onExited: {
			var signature = scan.found.join("\n") + "|" + JSON.stringify(scan.thumbs) + "|" + JSON.stringify(scan.previews)

			if (scan.directory === wallpapers.libraryDirectory && signature !== scan.signature) {
				scan.signature = signature
				if (JSON.stringify(wallpapers.wallpapers) !== JSON.stringify(scan.found))
					wallpapers.wallpapers = scan.found
				wallpapers.wallThumbs = scan.thumbs
				wallpapers.wallPreviews = scan.previews
			}

			scan.found = []
			scan.thumbs = ({})
			scan.previews = ({})

			if (!wallpapers.previewWallpaper || (wallpapers.previewWallpaper !== wallpapers.currentWallpaper && wallpapers.wallpapers.indexOf(wallpapers.previewWallpaper) === -1))
				wallpapers.previewWallpaper = wallpapers.wallpapers.length > 0 ? wallpapers.wallpapers[0] : ""
			if (wallpapers.wallpapers.indexOf(wallpapers.hoveredWallpaper) === -1)
				wallpapers.hoveredWallpaper = ""

			const refresh = scan.pending || scan.directory !== wallpapers.libraryDirectory
			scan.pending = false
			if (refresh || scan.cachedOnly)
				Qt.callLater(function () {
					wallpapers.startScan(refresh)
				})
		}
	}

	FileView {
		path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: wallpapers.currentWallpaper = text().trim()
	}

	FileView {
		path: wallpapers.currentPremium ? wallpapers.currentWallpaper : ""
		watchChanges: true
		printErrors: false
		onFileChanged: {
			reload()
			wallpapers.loadManifest(true)
		}
	}

	Process {
		id: metadata
		property string target: ""
		property bool pending: false
		property bool refreshPending: false
		command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/premium-wallpaper.py", "describe", target]
		stdout: StdioCollector {
			id: manifestOutput
		}
		stderr: StdioCollector {
			id: manifestError
		}
		onExited: (code, status) => {
			if (code === 0) {
				try {
					wallpapers.rememberManifest(target, JSON.parse(manifestOutput.text))
				} catch (problem) {
					wallpapers.metadataError = "Couldn't read wallpaper details: " + problem
				}
			} else if (target === wallpapers.currentWallpaper) {
				wallpapers.metadataError = manifestError.text.trim()
			}
			if (pending || target !== wallpapers.currentWallpaper) {
				const refresh = refreshPending
				pending = false
				refreshPending = false
				Qt.callLater(function () {
					wallpapers.loadManifest(refresh)
				})
			}
		}
	}

	Process {
		id: availability

		command: ["bash", "-c", "command -v qs || true"]
		running: true

		stdout: SplitParser {
			onRead: line => {
				wallpapers.wallpaperTool = line.length > 0
			}
		}
	}

	Process {
		id: setter

		property string target: ""
		property string pendingTarget: ""

		command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-set.sh", setter.target]
		stderr: StdioCollector {
			id: switchError
		}

		onExited: (code, status) => {
			wallpapers.error = code === 0 ? "" : switchError.text.trim() || "Wallpaper selection failed"
			if (setter.pendingTarget.length > 0) {
				setter.target = setter.pendingTarget
				setter.pendingTarget = ""
				setter.running = true
			}
		}
	}

	Timer {
		id: refreshDebounce

		interval: 100
		onTriggered: {
			if (scan.running)
				scan.pending = true
			else
				wallpapers.startScan(true)
		}
	}
}
