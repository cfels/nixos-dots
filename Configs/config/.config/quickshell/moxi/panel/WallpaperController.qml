import Quickshell
import Quickshell.Io
import QtQuick

Scope {
	id: wallpapers

	property bool expanded: false

	property var wallpapers: []
	property var wallThumbs: ({})
	property var wallPreviews: ({})
	property bool wallpaperTool: false
	property string previewWallpaper: ""
	property string hoveredWallpaper: ""

	function wallpaperIsVideo(path): bool {
		return /\.(mp4|m4v|webm|mkv|mov|avi)$/i.test("" + path)
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
		setter.target = path
		setter.running = true
	}

	Process {
		id: scan

		property var found: []
		property var thumbs: ({})
		property var previews: ({})
		property string signature: ""

		command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-list.sh"]

		running: true

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
			}
		}

		onExited: {
			var signature = scan.found.join("\n") + "|" + JSON.stringify(scan.thumbs) + "|" + JSON.stringify(scan.previews)

			if (signature !== scan.signature) {
				scan.signature = signature
				wallpapers.wallpapers = scan.found
				wallpapers.wallThumbs = scan.thumbs
				wallpapers.wallPreviews = scan.previews
			}

			scan.found = []
			scan.thumbs = ({})
			scan.previews = ({})

			if (wallpapers.wallpapers.indexOf(wallpapers.previewWallpaper) === -1 && wallpapers.wallpapers.length > 0)
				wallpapers.previewWallpaper = wallpapers.wallpapers[0]
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

		command: ["bash", "-c", "command -v awww || command -v swww || true"]
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

		command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-set.sh", setter.target]
	}

	Timer {
		interval: 4000
		running: wallpapers.expanded
		repeat: true
		onTriggered: scan.running = true
	}
}
