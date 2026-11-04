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
	property string previewWallpaper: ""
	property string hoveredWallpaper: ""

	onExpandedChanged: {
		if (wallpapers.expanded && initialized)
			refreshDebounce.restart()
	}

	function wallpaperIsVideo(path): bool {
		return /\.(mp4|m4v|webm|mkv|mov|avi|premiumwall\.json)$/i.test("" + path)
	}

	function wallpaperIsAnimated(path): bool {
		return /\.gif$/i.test("" + path)
	}

	function wallpaperThumb(path): string {
		var thumb = wallpapers.wallThumbs["" + path]
		return thumb === undefined ? "" : thumb
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

		return "" + path
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

			if (wallpapers.wallpapers.indexOf(wallpapers.previewWallpaper) === -1)
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

	Process {
		id: currentWallpaper

		command: ["bash", "-c", "cat \"$HOME/.cache/current-wallpaper\" 2>/dev/null || true"]
		running: true

		stdout: SplitParser {
			onRead: line => {
				if (line.length > 0)
					wallpapers.previewWallpaper = line
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
