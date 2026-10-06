import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import "../components"

PanelWindow {
	id: panel

	Theme {
		id: theme
	}

	readonly property bool hovered: cardHover.hovered || playHover.hovered
		|| previousHover.hovered || nextHover.hovered
		|| lyricsHover.hovered || gridHover.hovered || trackHover.hovered
	property bool expanded: false
	property var wallpapers: []
	property var wallThumbs: ({})
	property var wallPreviews: ({})
	property bool wallpaperTool: false
	property string previewWallpaper: ""
	property string hoveredWallpaper: ""

	property var lyrics: []
	property bool syncedLyrics: true
	property bool lyricsWanted: false
	property bool lyricsEstimated: false
	property var lyricsPlain: []
	property real lyricsPlainDuration: -1
	property string lyricsKey: ""
	property string lyricsFetchKey: ""
	property string lyricsLoadedKey: ""
	property var lyricsMissing: ({})
	readonly property bool lyricsUnavailable: panel.lyricsMissing[panel.lyricsKey] === true
	property var lyricsDurations: ({})
	readonly property bool lyricsSearching: panel.hasPlayer && panel.lyrics.length === 0 && !panel.lyricsUnavailable
		&& (lyricsFetch.running || panel.lyricsWanted || lyricsDebounce.running)
	property bool artWanted: false
	property real lookupDuration: 0
	property int activeLyric: -1
	property bool showLyrics: false
	property real lyricsOffset: 0
	property real lyricsSyncOffset: 0
	property real lyricsMix: panel.showLyrics ? 1 : 0
	readonly property real lyricsFade: Math.max(0, Math.min(1, panel.lyricsMix))
	readonly property real lyricsBlur: Math.sin(Math.PI * panel.lyricsFade)

	Behavior on lyricsMix {
		SpringAnimation {
			spring: 2.9
			damping: 0.25
			mass: 1
			epsilon: 0.0008
		}
	}

	property real playerOffsetX: -1
	property real playerOffsetY: 0
	property bool contentVisible: false
	property bool surfaceVisible: false
	property real anchorWidth: 210
	property real anchorHeight: 38
	property real anchorY: 4

	onExpandedChanged: {
		if (panel.expanded) {
			surfaceTimer.stop()
			panel.surfaceVisible = true
			contentTimer.restart()
		} else {
			panel.contentVisible = false
			panel.hoveredWallpaper = ""
			surfaceTimer.restart()
		}
	}

	function setAnchor(width: real, height: real, y: real): void {
		panel.anchorWidth = width
		panel.anchorHeight = height
		panel.anchorY = y
	}

	function wallpaperIsVideo(path): bool {
		return /\.(mp4|m4v|webm|mkv|mov|avi)$/i.test("" + path)
	}

	function wallpaperIsAnimated(path): bool {
		return /\.gif$/i.test("" + path)
	}

	function wallpaperThumb(path): string {
		var thumb = panel.wallThumbs["" + path]
		return thumb === undefined ? "" : thumb
	}

	function wallpaperPreview(path): string {
		var preview = panel.wallPreviews["" + path]
		return preview === undefined ? "" : preview
	}

	function wallpaperSource(path): string {
		if (("" + path).length === 0) return ""

		if (panel.wallpaperIsVideo(path)) {
			var preview = panel.wallpaperPreview(path)
			return preview.length > 0 ? preview : panel.wallpaperThumb(path)
		}

		return "" + path
	}

	function wallpaperSourceAnimated(path): bool {
		if (panel.wallpaperIsVideo(path)) return panel.wallpaperPreview(path).length > 0

		return panel.wallpaperIsAnimated(path)
	}

	function updateWallpaperHover(pos): void {
		if (!panel.expanded || panel.wallpapers.length === 0) return

		var cw = grid.cellWidth
		var ch = grid.cellHeight

		if (cw <= 0 || ch <= 0) return

		var columns = Math.max(1, Math.floor(grid.width / cw))
		var col = Math.floor((grid.contentX + pos.x) / cw)
		var row = Math.floor((grid.contentY + pos.y) / ch)
		var index = row * columns + col

		if (col < 0 || col >= columns || index < 0 || index >= panel.wallpapers.length) {
			panel.hoveredWallpaper = ""
			return
		}

		var path = panel.wallpapers[index]

		if (panel.hoveredWallpaper === path) return

		panel.hoveredWallpaper = path
		panel.previewWallpaper = path
	}

	property int artVersion: 0
	property string artSource: ""
	property string artFetchKey: ""
	property string artShownFile: ""
	property int artRetries: 0

	readonly property string artCachePath: Quickshell.env("HOME") + "/.cache/moxi/art"
	readonly property string artCacheKey: {
		var source = panel.trackArtist + "|" + panel.trackTitle + "|" + panel.trackAlbum + "|" + panel.trackUrl + "|" + panel.artUrl
		var hash = 5381

		for (var i = 0; i < source.length; ++i) hash = ((hash * 33) ^ source.charCodeAt(i)) >>> 0

		return hash.toString(16)
	}
	readonly property string artCacheFile: panel.artCachePath + "/art-" + panel.artCacheKey + ".img"

	readonly property color accent: theme.accent
	readonly property color foreground: theme.foreground
	readonly property color muted: theme.muted
	readonly property color idle: theme.idle
	readonly property string fontFamily: momo.status === FontLoader.Ready ? momo.name : ""
	readonly property string cyrillicFont: ruFont.status === FontLoader.Ready ? ruFont.name : panel.fontFamily
	readonly property string japaneseFont: jpFont.status === FontLoader.Ready ? jpFont.name : panel.fontFamily
	readonly property string koreanFont: krFont.status === FontLoader.Ready ? krFont.name : panel.fontFamily
	readonly property string symbolDir: Quickshell.env("HOME") + "/.config/quickshell/moxi/assets/symbols/"

	function lyricFont(text): string {
		var value = "" + text

		if (/[\uAC00-\uD7A3\u1100-\u11FF\u3130-\u318F]/.test(value)) return panel.koreanFont
		if (/[\u3040-\u30FF\u31F0-\u31FF\u4E00-\u9FFF\uF900-\uFAFF]/.test(value)) return panel.japaneseFont
		if (/[\u0400-\u04FF\u0500-\u052F]/.test(value)) return panel.cyrillicFont

		return panel.fontFamily
	}

	function lyricWeight(text, active): int {
		if (panel.lyricFont(text) !== panel.fontFamily) return Font.ExtraBold

		return active ? Font.DemiBold : Font.Normal
	}

	property real cornerRadius: panel.expanded ? 30 : panel.anchorHeight / 2
	readonly property real cornerPower: 4

	readonly property real playerSideWidth: Math.max(180, Math.round((layout.width - 422) / 2))

	Behavior on cornerRadius {
		NumberAnimation {
			duration: panel.expanded ? 240 : 150
			easing.type: Easing.Bezier
			easing.bezierCurve: [0.32, 0.72, 0, 1]
		}
	}

	readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
	readonly property bool hasPlayer: panel.player !== null
	property bool locallyPlaying: false
	property bool hasLocalOverride: false
	readonly property bool playing: panel.hasLocalOverride
		? panel.locallyPlaying
		: (panel.hasPlayer && panel.player.playbackState === MprisPlaybackState.Playing)

	function togglePlayback(): void {
		if (!panel.hasPlayer || !panel.player.canTogglePlaying) return

		panel.locallyPlaying = !panel.playing
		panel.hasLocalOverride = true
		panel.player.togglePlaying()
	}
	readonly property string trackTitle: panel.hasPlayer && panel.player.trackTitle ? panel.player.trackTitle : ""
	readonly property string trackArtist: panel.hasPlayer && panel.player.trackArtist ? panel.player.trackArtist : ""
	readonly property string trackAlbum: panel.hasPlayer && panel.player.trackAlbum ? panel.player.trackAlbum : ""
	readonly property string trackKey: panel.trackArtist + " — " + panel.trackTitle

	readonly property real metadataLength: {
		if (!panel.hasPlayer) return 0

		var raw = panel.player.metadata["mpris:length"]
		return raw ? raw / 1000000 : 0
	}
	readonly property real trackDuration: {
		if (panel.hasPlayer && panel.player.lengthSupported && panel.player.length > 0) return panel.player.length
		if (panel.metadataLength > 0) return panel.metadataLength

		return panel.lookupDuration
	}
	property real trackPosition: 0
	property real dragPosition: 0
	property bool positionFallback: false
	property bool positionTrusted: false
	property bool seekSettling: false
	property real seekTarget: -1
	property double seekAt: 0
	property real trustBase: -1
	property real lastReported: -1
	property int stallTicks: 0
	property bool progressFast: false
	readonly property real progress: panel.trackDuration > 0
		? Math.max(0, Math.min(1, panel.trackPosition / panel.trackDuration))
		: 0
	readonly property string artUrl: {
		if (!panel.hasPlayer) return ""

		var art = panel.player.metadata["mpris:artUrl"]
		return art ? art : ""
	}
	readonly property string trackUrl: {
		if (!panel.hasPlayer) return ""

		var url = panel.player.metadata["xesam:url"]
		return url ? url : ""
	}

	function timeText(seconds): string {
		if (!isFinite(seconds) || seconds <= 0) return "--:--"

		var total = Math.round(seconds)
		var minutes = Math.floor(total / 60)
		var rest = total % 60

		return minutes + ":" + (rest < 10 ? "0" : "") + rest
	}

	function positionText(seconds): string {
		if (!isFinite(seconds) || seconds < 0) return "--:--"

		var total = Math.floor(seconds)
		var minutes = Math.floor(total / 60)
		var rest = total % 60

		return minutes + ":" + (rest < 10 ? "0" : "") + rest
	}

	function parseLyrics(raw): var {
		var lines = raw.split("\n")
		var result = []
		var pattern = /^\[(\d+):(\d+(?:[.:]\d+)?)\](.*)$/

		for (var i = 0; i < lines.length; ++i) {
			var match = pattern.exec(lines[i])
			if (!match) continue

			var seconds = parseInt(match[1], 10) * 60 + parseFloat(match[2].replace(":", "."))
			var text = match[3].trim()
			if (text.length === 0) continue

			result.push({ time: seconds, text: text })
		}

		return result
	}

	function normKey(value): string {
		var raw = ("" + value).toLowerCase()
		var clean = raw.replace(/[^a-z0-9]+/g, "")

		return clean.length > 0 ? clean : raw
	}

	function lyricHeader(text): bool {
		return /^\[[^\]]*\]$/.test(("" + text).trim())
	}

	function noteMissingLyrics(): void {
		var key = panel.lyricsKey

		if (key.length === 0) return

		var map = {}
		var known = Object.keys(panel.lyricsMissing)

		for (var i = 0; i < known.length && i < 128; ++i) map[known[i]] = true

		map[key] = true
		panel.lyricsMissing = map
	}

	function forgetMissingLyrics(): void {
		var key = panel.lyricsKey

		if (key.length === 0 || panel.lyricsMissing[key] !== true) return

		var map = {}
		var known = Object.keys(panel.lyricsMissing)

		for (var i = 0; i < known.length; ++i) {
			if (known[i] !== key) map[known[i]] = true
		}

		panel.lyricsMissing = map
	}

	function rememberDuration(seconds): void {
		var key = panel.lyricsKey

		if (!(seconds > 0) || key.length === 0) return
		if (panel.lyricsDurations[key] === seconds) return

		var map = {}
		var known = Object.keys(panel.lyricsDurations)

		for (var i = 0; i < known.length && i < 256; ++i) map[known[i]] = panel.lyricsDurations[known[i]]

		map[key] = seconds
		panel.lyricsDurations = map
	}

	function applyPlainLyrics(): void {
		var raw = panel.lyricsPlain
		var duration = panel.trackDuration
		var timed = duration > 0
		var content = []
		var result = []
		var i

		for (i = 0; i < raw.length; ++i) {
			var text = ("" + raw[i]).trim()
			var entry = { time: -1, text: text }

			result.push(entry)

			if (text.length > 0 && !panel.lyricHeader(text)) content.push(entry)
		}

		if (timed) {
			for (i = 0; i < content.length; ++i) {
				content[i].time = duration * (i + 1) / (content.length + 1)
			}
		}

		panel.lyricsPlainDuration = timed ? duration : 0
		panel.lyrics = result
		panel.syncedLyrics = timed
		panel.activeLyric = -1
		panel.lyricsLoadedKey = panel.lyricsKey
		panel.showLyrics = true

		panel.updateActiveLyric()
	}

	function applyLyrics(payload): void {
		if (!payload || payload.length === 0) return

		var data = null
		try {
			data = JSON.parse(payload)
		} catch (error) {
			return
		}

		if (!data) return
		if (panel.lyricsFetchKey !== panel.lyricsKey) return

		if (data.duration && data.duration > 0) {
			panel.lookupDuration = data.duration
			panel.rememberDuration(data.duration)
		}

		var hasSynced = data.syncedLyrics && data.syncedLyrics.length > 0
		var hasPlain = data.plainLyrics && data.plainLyrics.length > 0

		if (!hasSynced && !hasPlain) {
			if (panel.lyrics.length > 0 && panel.lyricsLoadedKey === panel.lyricsKey) return

			panel.lyrics = []
			panel.lyricsPlain = []
			panel.lyricsEstimated = false
			panel.lyricsPlainDuration = -1
			panel.lyricsLoadedKey = ""
			panel.noteMissingLyrics()

			return
		}

		if (hasSynced) {
			var parsed = panel.parseLyrics(data.syncedLyrics)

			if (parsed.length > 0) {
				panel.lyrics = parsed
				panel.lyricsPlain = []
				panel.lyricsEstimated = false
				panel.syncedLyrics = true
				panel.lyricsLoadedKey = panel.lyricsKey
				panel.showLyrics = true
				panel.updateActiveLyric()
				return
			}
		}

		if (hasPlain) {
			panel.lyricsPlain = data.plainLyrics.split("\n")
			panel.lyricsEstimated = true
			panel.applyPlainLyrics()
		}
	}

	function updateActiveLyric(): void {
		if (!panel.syncedLyrics || panel.lyrics.length === 0) {
			panel.activeLyric = -1
			return
		}

		var position = panel.trackPosition + panel.lyricsSyncOffset
		var index = -1

		for (var i = 0; i < panel.lyrics.length; ++i) {
			if (panel.lyrics[i].time < 0) continue
			if (panel.lyrics[i].time <= position) index = i
			else break
		}

		if (index !== panel.activeLyric) panel.activeLyric = index
	}

	function seekTo(seconds): void {
		if (!panel.hasPlayer || !panel.player.canSeek || !(seconds >= 0)) return

		panel.player.position = seconds
		panel.trackPosition = seconds
		panel.dragPosition = seconds
		panel.lastReported = -1
		panel.stallTicks = 0
		panel.progressFast = true
		progressFastTimer.restart()
		panel.seekSettling = true
		panel.seekTarget = seconds
		panel.seekAt = Date.now()
		seekSettleTimer.restart()
		lyricsView.manual = false
		panel.updateActiveLyric()
	}

	function fetchLyrics(): void {
		if (panel.trackTitle.length === 0) return
		if (panel.lyrics.length > 0 && panel.lyricsLoadedKey === panel.lyricsKey) return
		if (panel.lyricsUnavailable) return
		if (panel.trackDuration > 0 && panel.trackDuration < 30) return

		if (lyricsFetch.running) {
			if (panel.lyricsFetchKey === panel.lyricsKey) return

			panel.lyricsWanted = true
			lyricsFetch.running = false
			return
		}

		panel.lyricsFetchKey = panel.lyricsKey
		panel.lyricsWanted = false
		lyricsFetch.running = true
	}

	function fetchArtwork(): void {
		if (panel.artUrl.length === 0) return

		panel.artFetchKey = panel.artCacheKey

		if (artCache.running) {
			panel.artWanted = true
			artCache.running = false
			return
		}

		panel.artWanted = false
		artCache.running = true
	}

	function scheduleArt(delay): void {
		artDebounce.interval = delay
		artDebounce.restart()
	}

	Timer {
		id: progressFastTimer

		interval: 360
		onTriggered: panel.progressFast = false
	}

	Timer {
		id: seekSettleTimer

		interval: 2500
		onTriggered: {
			panel.seekSettling = false
			panel.seekTarget = -1
			panel.trustBase = -1
			panel.positionTrusted = false
		}
	}

	Timer {
		id: lyricsDebounce

		interval: 1800
		onTriggered: panel.fetchLyrics()
	}

	Timer {
		id: lyricsWatchdog

		interval: 11000
		running: lyricsFetch.running
		onTriggered: {
			if (!lyricsFetch.running) return

			panel.lyricsWanted = false
			lyricsFetch.running = false
			panel.noteMissingLyrics()
		}
	}

	Timer {
		id: artDebounce

		interval: 180
		onTriggered: panel.fetchArtwork()
	}

	Timer {
		id: contentTimer
		interval: 140
		onTriggered: panel.contentVisible = true
	}

	Timer {
		id: surfaceTimer
		interval: 210
		onTriggered: panel.surfaceVisible = false
	}

	FontLoader {
		id: momo
		source: "../fonts/momotrust.ttf"
	}

	FontLoader {
		id: ruFont
		source: "../fonts/NotoSans-ExtraBold-RU.ttf"
	}

	FontLoader {
		id: jpFont
		source: "../fonts/NotoSansJP-ExtraBold.ttf"
	}

	FontLoader {
		id: krFont
		source: "../fonts/NotoSansKR-ExtraBold.ttf"
	}

	anchors {
		top: true
		left: true
		right: true
	}

	margins.top: 6
	implicitHeight: 490
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	mask: Region { item: inputArea }

	Timer {
		interval: 250
		running: panel.hasPlayer && !panel.positionFallback
		repeat: true
		onTriggered: {
			if (!panel.player.positionSupported) {
				if (!panel.playing) return

				panel.stallTicks += 1

				if (panel.stallTicks > 8) panel.positionFallback = true

				return
			}

			panel.player.positionChanged()

			var reported = panel.player.position

			if (reported < 0) return
			if (panel.trackDuration > 0 && reported > panel.trackDuration + 1) return

			var advanced = reported > panel.lastReported + 0.05

			if (advanced) {
				panel.stallTicks = 0
			} else if (panel.playing) {
				panel.stallTicks += 1

				if (panel.stallTicks > 8) panel.positionFallback = true
			}

			if (panel.trustBase < 0) panel.trustBase = reported
			else if (reported - panel.trustBase > 0.3) panel.positionTrusted = true

			panel.lastReported = reported

			if (panel.seekTarget >= 0) {
				if (Math.abs(reported - panel.seekTarget) < 1.5) {
					panel.seekTarget = -1
					panel.seekSettling = false
					seekSettleTimer.stop()

					return
				}

				if (Date.now() - panel.seekAt < 2200) return

				panel.seekTarget = -1
				panel.seekSettling = false
				seekSettleTimer.stop()
				panel.trustBase = -1
				panel.positionTrusted = false

				return
			}

			if (!panel.positionTrusted) return
			if (progressTrack.dragging) return

			var drift = reported - panel.trackPosition

			if (Math.abs(drift) > 1.5) panel.trackPosition = reported
			else if (Math.abs(drift) > 0.35) panel.trackPosition += drift * 0.5
		}
	}

	Timer {
		interval: 100
		running: panel.hasPlayer && panel.playing && !progressTrack.dragging
		repeat: true

		property double lastTick: 0

		onRunningChanged: lastTick = 0

		onTriggered: {
			var now = Date.now()

			if (lastTick === 0) {
				lastTick = now
				return
			}

			var delta = (now - lastTick) / 1000

			lastTick = now

			var next = panel.trackPosition + delta

			panel.trackPosition = panel.trackDuration > 0 ? Math.min(panel.trackDuration, next) : next
		}
	}

	Timer {
		interval: 100
		running: panel.syncedLyrics && panel.lyrics.length > 0
		repeat: true
		onTriggered: panel.updateActiveLyric()
	}

	onTrackKeyChanged: {
		var key = panel.normKey(panel.trackKey)

		if (key.length === 0) return
		if (key === panel.lyricsKey) return

		panel.lyricsKey = key
		panel.trackPosition = 0
		panel.positionFallback = false
		panel.positionTrusted = false
		panel.trustBase = -1
		panel.lastReported = -1
		panel.stallTicks = 0
		panel.progressFast = true
		progressFastTimer.restart()
		panel.seekSettling = false
		panel.seekTarget = -1
		seekSettleTimer.stop()
		panel.lookupDuration = panel.lyricsDurations[key] > 0 ? panel.lyricsDurations[key] : 0
		panel.syncedLyrics = false
		panel.lyrics = []
		panel.lyricsEstimated = false
		panel.lyricsPlain = []
		panel.lyricsPlainDuration = -1
		panel.activeLyric = -1
		panel.showLyrics = false
		panel.lyricsLoadedKey = ""
		panel.lyricsFetchKey = ""
		lyricsView.manual = false
		panel.forgetMissingLyrics()

		if (panel.trackTitle.length > 0) lyricsDebounce.restart()
		panel.artRetries = 0
		if (panel.artUrl.length > 0) panel.scheduleArt(80)
	}

	onArtUrlChanged: if (panel.artUrl.length > 0) panel.scheduleArt(80)

	onTrackDurationChanged: if (panel.lyricsEstimated && panel.trackDuration > 0 && panel.trackDuration !== panel.lyricsPlainDuration) panel.applyPlainLyrics()

	onActiveLyricChanged: lyricsView.scrollToActive()

	Connections {
		target: panel.player

		function onPlaybackStateChanged() {
			if (!panel.hasLocalOverride) return

			var reported = panel.player.playbackState === MprisPlaybackState.Playing

			if (reported === panel.locallyPlaying) panel.hasLocalOverride = false
		}
	}

	Process {
		id: lyricsFetch

		command: [
			Quickshell.env("HOME") + "/.config/hypr/scripts/lyrics-fetch.sh",
			panel.trackArtist,
			panel.trackTitle,
			panel.trackAlbum,
			String(panel.hasPlayer && panel.player.lengthSupported ? panel.player.length : 0),
			panel.trackUrl
		]

		running: false

		stdout: SplitParser {
			onRead: (line) => panel.applyLyrics(line)
		}

		onExited: (code, status) => {
			if (panel.lyricsFetchKey !== panel.lyricsKey) return
			if (panel.lyricsLoadedKey === panel.lyricsKey) return

			panel.noteMissingLyrics()
		}

		onRunningChanged: {
			if (running || !panel.lyricsWanted) return

			panel.lyricsWanted = false
			panel.lyricsFetchKey = panel.lyricsKey
			lyricsFetch.running = true
		}
	}

	Process {
		id: artCache

		command: [
			Quickshell.env("HOME") + "/.config/hypr/scripts/artwork-fetch.sh",
			panel.artUrl,
			panel.trackUrl,
			panel.trackArtist,
			panel.trackTitle,
			panel.artCacheFile,
			panel.artShownFile
		]

		onExited: (code, status) => {
			if (panel.artFetchKey !== panel.artCacheKey) return

			if (code === 2) {
				if (panel.artRetries < 6) {
					panel.artRetries = panel.artRetries + 1
					panel.scheduleArt(200)

					return
				}

				panel.artRetries = 0

				return
			}

			panel.artRetries = 0
			panel.artVersion = panel.artVersion + 1

			if (code === 0) {
				panel.artShownFile = panel.artCacheFile
				panel.artSource = "file://" + panel.artCacheFile + "?v=" + panel.artVersion
			} else if (artwork.shown.length === 0 && panel.artUrl.length > 0) {
				panel.artShownFile = ""
				panel.artSource = panel.artUrl
			}
		}

		onRunningChanged: {
			if (running || !panel.artWanted) return

			panel.artWanted = false
			panel.artFetchKey = panel.artCacheKey
			artCache.running = true
		}
	}

	Process {
		id: scan

		property var found: []
		property var thumbs: ({})
		property var previews: ({})
		property string signature: ""

		command: [
			"bash",
			Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-list.sh"
		]

		running: false

		stdout: SplitParser {
			onRead: (line) => {
				const fields = line.split("\t")
				const path = fields[0]

				if (path.length === 0 || scan.found.indexOf(path) !== -1) return

				scan.found = scan.found.concat([path])

				if (fields[1] && fields[1].length > 0) scan.thumbs[path] = fields[1]
				if (fields[2] && fields[2].length > 0) scan.previews[path] = fields[2]
			}
		}

		onExited: {
			var signature = scan.found.join("\n") + "|" + JSON.stringify(scan.thumbs) + "|" + JSON.stringify(scan.previews)

			if (signature !== scan.signature) {
				scan.signature = signature
				panel.wallpapers = scan.found
				panel.wallThumbs = scan.thumbs
				panel.wallPreviews = scan.previews
			}

			scan.found = []
			scan.thumbs = ({})
			scan.previews = ({})

			if (panel.wallpapers.indexOf(panel.previewWallpaper) === -1 && panel.wallpapers.length > 0)
				panel.previewWallpaper = panel.wallpapers[0]
		}
	}

	Timer {
		interval: 4000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: scan.running = true
	}

	Process {
		id: currentWallpaper

		command: ["bash", "-c", "cat \"$HOME/.cache/current-wallpaper\" 2>/dev/null || true"]
		running: true

		stdout: SplitParser {
			onRead: (line) => {
				if (line.length > 0) panel.previewWallpaper = line
			}
		}
	}

	Process {
		id: availability

		command: ["bash", "-c", "command -v awww || command -v swww || true"]
		running: true

		stdout: SplitParser {
			onRead: (line) => {
				panel.wallpaperTool = line.length > 0
			}
		}
	}

	Process {
		id: setter

		property string target: ""

		command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper-set.sh", setter.target]
	}

	Item {
		id: cardHost

		HoverHandler {
			id: cardHover
			blocking: false
		}

		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: parent.top
		y: panel.expanded ? 50 : panel.anchorY
		width: panel.expanded ? 920 : panel.anchorWidth
		height: panel.expanded ? 420 : panel.anchorHeight
		opacity: panel.surfaceVisible ? 1 : 0

		Behavior on opacity {
			NumberAnimation { duration: panel.surfaceVisible ? 120 : 150 }
		}

		Behavior on y {
			NumberAnimation {
				duration: panel.expanded ? 300 : 220
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Behavior on width {
			NumberAnimation {
				duration: panel.expanded ? 300 : 220
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Behavior on height {
			NumberAnimation {
				duration: panel.expanded ? 300 : 220
				easing.type: Easing.Bezier
				easing.bezierCurve: [0.32, 0.72, 0, 1]
			}
		}

		Item {
			id: cardSource

			visible: true
			width: cardHost.width
			height: cardHost.height


			Squircle {
				anchors.fill: parent
				power: panel.cornerPower
				radius: panel.cornerRadius
				fillColor: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.7)
				strokeColor: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.24)
				strokeWidth: 1
			}

			RowLayout {
				id: layout

				anchors.fill: parent
				anchors.margins: 20
				spacing: 20
				opacity: panel.contentVisible ? 1 : 0

				Behavior on opacity {
					NumberAnimation {
						duration: 150
						easing.type: Easing.OutCubic
					}
				}

				Calendar {
					id: calendar

					Layout.preferredWidth: panel.playerSideWidth
					Layout.fillHeight: true
					accent: panel.accent
					foreground: panel.foreground
					muted: panel.muted
					fontFamily: panel.fontFamily
				}

				Rectangle {
					Layout.fillHeight: true
					width: 1
					color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
				}

				Item {
					Layout.preferredWidth: 340
					Layout.fillHeight: true

					Rectangle {
						id: mediaFrame

						anchors.top: parent.top
						anchors.horizontalCenter: parent.horizontalCenter
						width: 170
						height: 170
						color: "transparent"

						Item {
							id: artwork

							anchors.fill: parent
							anchors.margins: 2
							clip: true
							visible: opacity > 0.01
							opacity: artwork.ready ? 1 - panel.lyricsFade : 0
							scale: 1 - 0.06 * panel.lyricsFade
							layer.enabled: true
							layer.effect: MultiEffect {
								maskEnabled: true
								maskSource: artworkMask
								blurEnabled: panel.lyricsBlur > 0.01
								blur: panel.lyricsBlur
								blurMax: 20
								autoPaddingEnabled: true
							}

							Squircle {
								id: artworkMask

								anchors.fill: parent
								visible: false
								layer.enabled: true
								radius: 26
								power: 4
								fillColor: "white"
							}

							readonly property bool ready: artworkIn.ready || artworkOut.ready
							property string shown: ""
							property string incoming: ""
							property bool pending: false
							property real swapDir: 1

							function artSourceNow(): string {
								return panel.artSource.length > 0 ? panel.artSource : panel.artUrl
							}

							function swap(dir): void {
								var next = artwork.artSourceNow()

								if (next === artwork.shown && !artwork.pending) return
								if (next === artwork.incoming) return

								artwork.swapDir = dir
								artwork.incoming = next
								artwork.pending = true
								artwork.maybeStart()
							}

							function maybeStart(): void {
								if (!artwork.pending) return
								if (artwork.incoming.length > 0 && !artworkIn.ready) return

								artwork.pending = false
								artworkOut.source = artwork.shown
								artworkOut.x = 0
								artworkOut.opacity = artwork.shown.length > 0 ? 1 : 0
								artworkIn.x = 170 * artwork.swapDir
								artSwap.restart()
							}

							function finish(): void {
								artwork.shown = artwork.incoming
								artworkOut.source = artwork.shown
								artworkOut.x = 0
								artworkOut.opacity = 1
								artworkIn.x = 0
								artworkIn.opacity = 1
							}

							Connections {
								target: panel

								function onArtUrlChanged() {
									artwork.swap(playButton.transportDir !== 0 ? playButton.transportDir : 1)
								}

								function onArtSourceChanged() {
									artwork.swap(playButton.transportDir !== 0 ? playButton.transportDir : 1)
								}
							}

							Connections {
								target: artworkIn

								function onReadyChanged() {
									artwork.maybeStart()
								}
							}

							SquircleImage {
								id: artworkOut

								x: 0
								y: 0
								width: parent.width
								height: parent.height
								radius: 26
								power: 4
								sourceWidth: 400
								sourceHeight: 400
							}

							SquircleImage {
								id: artworkIn

								x: 0
								y: 0
								width: parent.width
								height: parent.height
								source: artwork.incoming
								radius: 26
								power: 4
								sourceWidth: 400
								sourceHeight: 400
							}

							SequentialAnimation {
								id: artSwap

								ParallelAnimation {
									NumberAnimation {
										target: artworkOut
										property: "x"
										to: -170 * artwork.swapDir
										duration: 320
										easing.type: Easing.OutCubic
									}
									NumberAnimation {
										target: artworkIn
										property: "x"
										from: 170 * artwork.swapDir
										to: 0
										duration: 320
										easing.type: Easing.OutCubic
									}
								}

								onFinished: artwork.finish()
							}
						}


						ListView {
							id: lyricsView

						anchors.top: parent.top
						anchors.bottom: parent.bottom
						anchors.topMargin: 6 + panel.lyricsOffset
						anchors.bottomMargin: 6 - panel.lyricsOffset
						anchors.horizontalCenter: parent.horizontalCenter
						anchors.horizontalCenterOffset: 20 // lyricsbox left pos
						width: 310
						transformOrigin: Item.Center
						scale: 0.92 + 0.08 * panel.lyricsFade
						clip: true
						spacing: 4
						model: panel.lyrics
						visible: opacity > 0.01
						opacity: panel.lyricsFade
						boundsBehavior: Flickable.StopAtBounds
						pixelAligned: false
						cacheBuffer: 2400
						property bool manual: false
						layer.enabled: panel.lyricsBlur > 0.01
						layer.effect: MultiEffect {
							blurEnabled: true
							blur: panel.lyricsBlur
							blurMax: 20
							autoPaddingEnabled: true
						}

							function scrollToActive() {
								if (!panel.syncedLyrics || panel.activeLyric < 0 || manual) return

								var entry = itemAtIndex(panel.activeLyric)

								if (!entry) {
									scrollAnimation.to = Math.max(
										0,
										Math.min(contentHeight - height, panel.activeLyric / Math.max(1, count) * contentHeight - height / 2)
									)
									scrollAnimation.restart()
									return
								}

								scrollAnimation.to = snapped(entry.y - (height - entry.height) / 2)
								scrollAnimation.restart()
							}

							function snapped(target): real {
								var best = target
								var bestDelta = -1

								for (var i = 0; i < count; ++i) {
									var item = itemAtIndex(i)

									if (!item) continue

									var delta = Math.abs(item.y - target)

									if (bestDelta < 0 || delta < bestDelta) {
										bestDelta = delta
										best = item.y
									}
								}

								return Math.max(0, Math.min(contentHeight - height, best))
							}

							function glideBy(delta): void {
								manual = true
								resumeTimer.restart()
								scrollAnimation.to = Math.max(0, Math.min(contentHeight - height, contentY + delta))
								scrollAnimation.restart()
							}

							onMovementStarted: {
								manual = true
								resumeTimer.restart()
							}

							WheelHandler {
								onWheel: (event) => {
									var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 70

									lyricsView.glideBy(-delta)
									event.accepted = true
								}
							}

							NumberAnimation {
								id: scrollAnimation

								target: lyricsView
								property: "contentY"
								duration: 420
								easing.type: Easing.Bezier
								easing.bezierCurve: [0.32, 0.72, 0, 1]
							}

							Timer {
								id: resumeTimer
								interval: 3500

								onTriggered: {
									lyricsView.manual = false
									lyricsView.scrollToActive()
								}
							}

							delegate: Text {
								id: lyricLine

								required property var modelData
								required property int index

								x: 20
								width: ListView.view.width - 40
								text: modelData.text
								color: index === panel.activeLyric
									? panel.accent
									: lineMouse.containsMouse ? panel.foreground : panel.muted
								font.family: panel.lyricFont(modelData.text)
								font.pixelSize: 12
								font.weight: panel.lyricWeight(modelData.text, false)
								horizontalAlignment: Text.AlignHCenter
								wrapMode: Text.WordWrap
								transformOrigin: Item.Center
								scale: index === panel.activeLyric ? 1.04 : 0.97

								Behavior on scale {
									NumberAnimation {
										duration: 300
										easing.type: Easing.Bezier
										easing.bezierCurve: [0.32, 0.72, 0, 1]
									}
								}

								layer.enabled: index === panel.activeLyric
								layer.effect: MultiEffect {
									shadowEnabled: true
									shadowColor: panel.accent
									shadowBlur: 0.7
									shadowOpacity: 0.9
									shadowHorizontalOffset: 0
									shadowVerticalOffset: 0
									autoPaddingEnabled: true
								}

								Behavior on color {
									ColorAnimation { duration: 160 }
								}

								MouseArea {
									id: lineMouse

									anchors.fill: parent
									enabled: modelData.time >= 0 && panel.hasPlayer && panel.player.canSeek
									hoverEnabled: true
									cursorShape: Qt.PointingHandCursor
									onClicked: panel.seekTo(modelData.time)
								}
							}
						}

						Text {
							anchors.centerIn: parent
							visible: opacity > 0.01
							opacity: panel.showLyrics && panel.lyrics.length === 0 ? panel.lyricsFade : 0
							color: panel.muted
							font.family: panel.fontFamily
							font.pixelSize: 12
							text: panel.trackTitle.length > 0 ? "no lyrics found" : "play sum shii-"
						}

						Text {
							anchors.centerIn: parent
							visible: opacity > 0.01
							opacity: artwork.ready ? 0 : 1 - panel.lyricsFade
							color: panel.muted
							font.family: panel.fontFamily
							font.pixelSize: 12
							text: panel.hasPlayer ? "no artwork" : "play sum shii-"
						}

					}
					
					Text {
						id: title

						anchors.top: mediaFrame.bottom
						anchors.topMargin: 14
						anchors.left: parent.left
						anchors.right: parent.right
						color: panel.foreground
						elide: Text.ElideRight
						font.family: panel.lyricFont(title.text)
						font.pixelSize: 15
						font.weight: panel.lyricWeight(title.text, true)
						horizontalAlignment: Text.AlignHCenter
						text: panel.trackTitle.length > 0 ? panel.trackTitle : "play sum shii-"
						wrapMode: Text.NoWrap
					}

					Text {
						id: artist

						anchors.top: title.bottom
						anchors.topMargin: 2
						anchors.left: parent.left
						anchors.right: parent.right
						color: panel.trackArtist.length > 0 ? panel.accent : panel.muted
						elide: Text.ElideRight
						font.family: panel.lyricFont(artist.text)
						font.pixelSize: 13
						font.weight: panel.lyricWeight(artist.text, false)
						horizontalAlignment: Text.AlignHCenter
						text: panel.trackArtist.length > 0
							? panel.trackArtist
							: (panel.trackAlbum.length > 0 ? panel.trackAlbum : "—")
						wrapMode: Text.NoWrap
					}

					Item {
						id: progressTrack

						anchors.top: artist.bottom
						anchors.topMargin: 16
						anchors.left: parent.left
						anchors.right: parent.right
						height: 16

						property bool hovered: false
						property bool dragging: false
						property real dragBase: 0
						property real dragBaseX: 0

						function preview(x): void {
							if (!panel.hasPlayer || !panel.player.canSeek) return

							if (panel.trackDuration > 0) {
								panel.dragPosition = panel.trackDuration * Math.max(0, Math.min(1, x / width))
							} else {
								panel.dragPosition = Math.max(0, progressTrack.dragBase + (x - progressTrack.dragBaseX) / width * 180)
							}

							panel.trackPosition = panel.dragPosition
							panel.updateActiveLyric()
						}

						function commit(): void {
							if (!panel.hasPlayer || !panel.player.canSeek) {
								panel.trackPosition = progressTrack.dragBase
								panel.dragPosition = progressTrack.dragBase
								panel.lastReported = -1
								panel.trustBase = -1
								panel.positionTrusted = false

								return
							}

							if (panel.trackDuration > 0) {
								panel.seekTo(panel.dragPosition)

								return
							}

							if (Math.abs(panel.dragPosition - progressTrack.dragBase) >= 0.5) {
								panel.seekTo(panel.dragPosition)

								return
							}

							panel.trackPosition = progressTrack.dragBase
							panel.dragPosition = progressTrack.dragBase
						}

						HoverHandler {
							id: trackHover
							onHoveredChanged: progressTrack.hovered = trackHover.hovered
						}

						Rectangle {
							id: progressRail

							anchors.left: parent.left
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							height: progressTrack.hovered ? 10 : 5
							radius: height / 2
							color: panel.trackDuration > 0
								? Qt.rgba(theme.idle.r, theme.idle.g, theme.idle.b, progressTrack.hovered ? 0.95 : 0.7)
								: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, progressTrack.hovered ? 0.5 : 0.3)

							Behavior on height {
								NumberAnimation {
									duration: 200
									easing.type: Easing.OutCubic
								}
							}
						}

						Rectangle {
							id: progressFill

							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							width: progressRail.width * panel.progress
							height: progressRail.height
							radius: height / 2
							color: panel.accent

							Behavior on width {
								enabled: !progressTrack.dragging

								NumberAnimation {
									duration: panel.progressFast ? 200 : 150
									easing.type: panel.progressFast ? Easing.OutCubic : Easing.Linear
								}
							}
						}

						Rectangle {
							id: indeterminate

							visible: panel.hasPlayer && panel.trackDuration <= 0 && panel.lyricsSearching
							y: progressRail.y
							width: progressRail.width * 0.25
							height: progressRail.height
							radius: height / 2
							color: panel.accent
							opacity: 0.6

							SequentialAnimation {
								running: indeterminate.visible
								loops: Animation.Infinite

								NumberAnimation {
									target: indeterminate
									property: "x"
									from: 0
									to: progressTrack.width - indeterminate.width
									duration: 1500
									easing.type: Easing.InOutSine
								}
								NumberAnimation {
									target: indeterminate
									property: "x"
									to: 0
									duration: 1500
									easing.type: Easing.InOutSine
								}
							}
						}

						MouseArea {
							anchors.fill: parent
							anchors.topMargin: -6
							anchors.bottomMargin: -6
							enabled: panel.hasPlayer
							hoverEnabled: true
							cursorShape: panel.player && panel.player.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
							onPressed: (mouse) => {
								if (!panel.hasPlayer || !panel.player.canSeek) return

								progressTrack.dragBaseX = mouse.x
								progressTrack.dragBase = panel.trackPosition
								progressTrack.dragging = true
								progressTrack.preview(mouse.x)
							}
							onPositionChanged: (mouse) => {
								if (pressed) progressTrack.preview(mouse.x)
							}
							onReleased: {
								if (!progressTrack.dragging) return

								progressTrack.dragging = false
								progressTrack.commit()
							}
							onCanceled: {
								if (!progressTrack.dragging) return

								progressTrack.dragging = false
								progressTrack.commit()
							}
						}
					}

					Text {
						id: elapsed

						anchors.top: progressTrack.bottom
						anchors.topMargin: 6
						anchors.left: parent.left
						color: progressTrack.dragging ? panel.accent : panel.muted
						font.family: panel.fontFamily
						font.pixelSize: 11
						text: {
							if (!panel.hasPlayer) return "--:--"
							if (panel.trackDuration <= 0 && panel.trackPosition <= 0) return "live"

							return panel.positionText(panel.trackPosition)
						}
					}

					Text {
						anchors.top: progressTrack.bottom
						anchors.topMargin: 6
						anchors.right: parent.right
						color: panel.muted
						font.family: panel.fontFamily
						font.pixelSize: 11
						text: panel.timeText(panel.trackDuration)
					}

					Row {
						id: controls

						anchors.top: elapsed.bottom
						anchors.topMargin: 14 + panel.playerOffsetY
						x: Math.round((parent.width - width) / 2) + panel.playerOffsetX
						spacing: 10

						Item {
							id: previousButton

							width: 56
							height: 56

							property real swipe: 0

							HoverHandler {
								id: previousHover
								cursorShape: Qt.PointingHandCursor
							}

							TapHandler {
								onTapped: {
									if (!panel.hasPlayer || !panel.player.canGoPrevious) return

									playButton.transportDir = -1
									playButton.transportAt = Date.now()
									previousSwipe.restart()
									panel.player.previous()
								}
							}

							Image {
								anchors.centerIn: parent
								anchors.horizontalCenterOffset: previousButton.swipe // prev button
								width: 48
								height: 48
								source: "file://" + panel.symbolDir + "previous-fg.svg"
								sourceSize.width: 68
								sourceSize.height: 68
									layer.enabled: true
									layer.effect: MultiEffect {
										colorization: 1
										colorizationColor: theme.accent
										autoPaddingEnabled: false
								}
								fillMode: Image.PreserveAspectFit
								asynchronous: true
								opacity: (panel.hasPlayer && panel.player.canGoPrevious ? 1 : 0.4)
									* (1 - Math.min(1, Math.abs(previousButton.swipe) / 20))
							}

							SequentialAnimation {
								id: previousSwipe

								NumberAnimation {
									target: previousButton
									property: "swipe"
									to: -20
									duration: 180
									easing.type: Easing.OutBack
								}
								PropertyAction {
									target: previousButton
									property: "swipe"
									value: 20
								}
								NumberAnimation {
									target: previousButton
									property: "swipe"
									to: 0
									duration: 300
									easing.type: Easing.OutBack
								}
								onFinished: previousButton.swipe = 0
							}
						}

						Item {
							id: playButton

							width: 56
							height: 56

							property real swipe: 0
							property real swipeDir: 1
							property int transportDir: 0
							property double transportAt: 0

							Rectangle {
								anchors.fill: parent
								radius: 28
								color: playHover.hovered
									? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.3)
									: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)

								Behavior on color {
									ColorAnimation { duration: 140 }
								}
							}

							HoverHandler {
								id: playHover
								cursorShape: Qt.PointingHandCursor
							}

							TapHandler {
								onTapped: panel.togglePlayback()
							}

							Connections {
								target: panel

								function onPlayingChanged(): void {
									var recent = Date.now() - playButton.transportAt < 900

									playButton.swipeDir = (recent && playButton.transportDir !== 0)
										? playButton.transportDir
										: (panel.playing ? 1 : -1)
									playSwipe.restart()
								}
							}

							SequentialAnimation {
								id: playSwipe

								NumberAnimation {
									target: playButton
									property: "swipe"
									to: playButton.swipeDir * 20
									duration: 180
									easing.type: Easing.OutBack
								}
								PropertyAction {
									target: playButton
									property: "swipe"
									value: -playButton.swipeDir * 20
								}
								NumberAnimation {
									target: playButton
									property: "swipe"
									to: 0
									duration: 300
									easing.type: Easing.OutBack
								}
								onFinished: playButton.swipe = 0
							}

							Image {
								id: playIcon

								anchors.centerIn: parent
								anchors.horizontalCenterOffset: playButton.swipe + 2.4
								opacity: 1 - Math.min(1, Math.abs(playButton.swipe) / 20)
								width: 28
								height: 28
								visible: !panel.playing
								source: "file://" + panel.symbolDir + "play-fg.svg"
								sourceSize.width: 56
								sourceSize.height: 56
									layer.enabled: true
									layer.effect: MultiEffect {
										colorization: 1
										colorizationColor: theme.accent
										autoPaddingEnabled: false
									}
								fillMode: Image.PreserveAspectFit
								asynchronous: true
							}

							Item {
								id: pauseIcon

								anchors.centerIn: parent
								anchors.horizontalCenterOffset: playButton.swipe
								width: 22
								height: 30
								visible: panel.playing
								opacity: 1 - Math.min(1, Math.abs(playButton.swipe) / 20)

								Rectangle {
									anchors.left: parent.left
									anchors.verticalCenter: parent.verticalCenter
									width: 9
									height: 30
									radius: 2
									color: theme.accent
								}

								Rectangle {
									anchors.right: parent.right
									anchors.verticalCenter: parent.verticalCenter
									width: 9
									height: 30
									radius: 2
									color: theme.accent
								}
							}
						}

						Item {
							id: nextButton

							width: 56
							height: 56

							property real swipe: 0

							HoverHandler {
								id: nextHover
								cursorShape: Qt.PointingHandCursor
							}

							TapHandler {
								onTapped: {
									if (!panel.hasPlayer || !panel.player.canGoNext) return

									playButton.transportDir = 1
									playButton.transportAt = Date.now()
									nextSwipe.restart()
									panel.player.next()
								}
							}

							Image {
								anchors.centerIn: parent
								anchors.horizontalCenterOffset: nextButton.swipe // next button
								width: 48
								height: 48
								source: "file://" + panel.symbolDir + "next-fg.svg"
								sourceSize.width: 68
								sourceSize.height: 68
									layer.enabled: true
									layer.effect: MultiEffect {
										colorization: 1
										colorizationColor: theme.accent
										autoPaddingEnabled: false
								}
								fillMode: Image.PreserveAspectFit
								asynchronous: true
								opacity: (panel.hasPlayer && panel.player.canGoNext ? 1 : 0.4)
									* (1 - Math.min(1, Math.abs(nextButton.swipe) / 20))
							}

							SequentialAnimation {
								id: nextSwipe

								NumberAnimation {
									target: nextButton
									property: "swipe"
									to: 20
									duration: 180
									easing.type: Easing.OutBack
								}
								PropertyAction {
									target: nextButton
									property: "swipe"
									value: -20
								}
								NumberAnimation {
									target: nextButton
									property: "swipe"
									to: 0
									duration: 300
									easing.type: Easing.OutBack
								}
								onFinished: nextButton.swipe = 0
							}
						}
					}

					Rectangle {
						id: lyricsToggle

						anchors.top: controls.bottom
						anchors.topMargin: 8.5
						x: controls.x + Math.round((controls.width - width) / 2)
						width: 36
						height: 36
						radius: 15
						readonly property bool loading: panel.lyricsSearching
						property bool pulseOn: false
						transformOrigin: Item.Center
						border.width: 1
						border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.08)
						color: lyricsHover.hovered
							? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.34)
							: panel.showLyrics && panel.lyrics.length > 0
								? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
								: "transparent"
						visible: panel.hasPlayer && (panel.lyrics.length > 0 || lyricsToggle.loading)
						opacity: panel.expanded ? (lyricsToggle.loading ? 0.75 : 1) : 0

						Behavior on opacity {
							NumberAnimation {
								duration: 260
								easing.type: Easing.OutCubic
							}
						}

						Behavior on color {
							ColorAnimation { duration: 160 }
						}

						Behavior on border.color {
							ColorAnimation { duration: 160 }
						}

						Timer {
							interval: 700
							repeat: true
							running: lyricsToggle.loading
							onTriggered: lyricsToggle.pulseOn = !lyricsToggle.pulseOn
						}

						NumberAnimation {
							id: lyricsReveal

							target: lyricsToggle
							property: "scale"
							from: 0.55
							to: 1
							duration: 460
							easing.type: Easing.OutBack
							easing.overshoot: 1.1
						}

						Connections {
							target: panel

							function onLyricsChanged(): void {
								if (panel.lyrics.length > 0) lyricsReveal.restart()
							}
						}

						SequentialAnimation {
							id: lyricsPop

							NumberAnimation {
								target: lyricsToggle
								property: "scale"
								to: 1.08
								duration: 140
								easing.type: Easing.OutBack
								easing.overshoot: 1.1
							}
							NumberAnimation {
								target: lyricsToggle
								property: "scale"
								to: 1
								duration: 300
								easing.type: Easing.OutBack
								easing.overshoot: 1.1
							}
						}

						Image {
							anchors.centerIn: parent
							anchors.horizontalCenterOffset: 0
							anchors.verticalCenterOffset: 2
							width: 24
							height: 24
							source: "file://" + panel.symbolDir + "quotes-fg.svg"
							opacity: lyricsToggle.loading ? (lyricsToggle.pulseOn ? 0.35 : 0.85) : 1

							Behavior on opacity {
								NumberAnimation {
									duration: 680
									easing.type: Easing.InOutSine
								}
							}

							sourceSize.width: 34
							sourceSize.height: 34
							fillMode: Image.PreserveAspectFit
							asynchronous: true
							layer.enabled: true
							layer.effect: MultiEffect {
								colorization: 1
								colorizationColor: panel.showLyrics && panel.lyrics.length > 0 ? panel.accent : panel.muted
								autoPaddingEnabled: false
							}
						}

						HoverHandler {
							id: lyricsHover
							cursorShape: Qt.PointingHandCursor
						}

						TapHandler {
							onTapped: {
								lyricsPop.restart()
								panel.showLyrics = !panel.showLyrics
							}
						}
					}
				}

				Rectangle {
					Layout.fillHeight: true
					width: 1
					color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.12)
				}

				Item {
					Layout.preferredWidth: panel.playerSideWidth
					Layout.fillHeight: true

					Text {
						id: wallTitle

						color: panel.foreground
						font.family: panel.fontFamily
						font.pixelSize: 14
						font.weight: Font.DemiBold
						text: "Wallpaper"
					}

					Rectangle {
						id: previewFrame

						anchors.top: wallTitle.bottom
						anchors.topMargin: 10
						anchors.left: parent.left
						anchors.right: parent.right
						height: 140
						color: "transparent"
						clip: true

						property string shownSource: ""
						property bool shownAnimated: false
						property string previousSource: ""
						property bool previousAnimated: false
						property real ghostProgress: 0
						property bool waitingReady: false

						function cross(): void {
							const nextSource = preview.source
							const nextAnimated = preview.animated

							if (nextSource === previewFrame.shownSource && nextAnimated === previewFrame.shownAnimated) return

							if (previewFrame.shownAnimated) {
								previewFrame.previousSource = previewFrame.shownSource
								previewFrame.previousAnimated = true
							} else {
								previewFrame.previousAnimated = false
								previewFrame.previousSource = previewFrame.shownSource
							}

							previewFrame.shownSource = nextSource
							previewFrame.shownAnimated = nextAnimated

							previewCross.stop()

							if (nextSource.length === 0) {
								previewFrame.waitingReady = false
								previewFrame.ghostProgress = 0
								return
							}

							previewFrame.ghostProgress = 1

							if (preview.ready) {
								previewFrame.waitingReady = false
								previewCross.restart()
							} else {
								previewFrame.waitingReady = true
							}
						}

						SquircleImage {
							id: preview

							anchors.fill: parent
							source: panel.wallpaperSource(panel.previewWallpaper).length > 0 ? "file://" + panel.wallpaperSource(panel.previewWallpaper) : ""
							animated: panel.wallpaperSourceAnimated(panel.previewWallpaper)
							radius: 30
							power: 4
							sourceWidth: 560
							sourceHeight: 320

							onSourceChanged: previewFrame.cross()
							onReadyChanged: {
								if (ready && previewFrame.waitingReady) {
									previewFrame.waitingReady = false
									previewCross.restart()
								}
							}
							Component.onCompleted: {
								previewFrame.shownSource = preview.source
								previewFrame.shownAnimated = preview.animated
							}
						}

						SquircleImage {
							id: previewGhost

							anchors.fill: parent
							source: previewFrame.previousSource
							animated: previewFrame.previousAnimated
							radius: 30
							power: 4
							sourceWidth: 560
							sourceHeight: 320
							opacity: previewFrame.ghostProgress
							visible: previewFrame.ghostProgress > 0.001
							playing: visible
							layer.enabled: visible
							layer.effect: MultiEffect {
								blurEnabled: true
								blur: (1 - previewFrame.ghostProgress) * 0.85
								blurMax: 24
							}
						}

						ParallelAnimation {
							id: previewCross

							NumberAnimation {
								target: previewFrame
								property: "ghostProgress"
								from: 1
								to: 0
								duration: 430
								easing.type: Easing.OutCubic
							}
							NumberAnimation {
								target: preview
								property: "scale"
								from: 1.02
								to: 1
								duration: 430
								easing.type: Easing.OutCubic
							}
						}
					}

					GridView {
						id: grid

						anchors.top: previewFrame.bottom
						anchors.topMargin: 12
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: hint.top
						anchors.bottomMargin: 8
						clip: true
						cellWidth: Math.max(1, Math.floor(width / 2))
						cellHeight: Math.max(1, Math.floor(height / 2))
						boundsBehavior: Flickable.StopAtBounds
						flickDeceleration: 1400
						maximumFlickVelocity: 2600
						model: panel.wallpapers

						HoverHandler {
							id: gridHover

							onPointChanged: panel.updateWallpaperHover(gridHover.point.position)
							onHoveredChanged: if (!hovered) panel.hoveredWallpaper = ""
						}

						function glideBy(delta): void {
							var maximum = Math.max(0, contentHeight - height)
							var base = gridScrollAnimation.running ? gridScrollAnimation.to : contentY

							gridScrollAnimation.to = Math.max(0, Math.min(maximum, base + delta))
							gridScrollAnimation.restart()
						}

						NumberAnimation {
							id: gridScrollAnimation

							target: grid
							property: "contentY"
							duration: 300
							easing.type: Easing.OutCubic
						}

						WheelHandler {
							onWheel: (wheel) => {
								var step = wheel.pixelDelta.y !== 0
									? wheel.pixelDelta.y * 2
									: wheel.angleDelta.y / 120 * grid.cellHeight

								if (step === 0) return

								grid.glideBy(-step)
								wheel.accepted = true
							}
						}

						delegate: Item {
							required property var modelData

							width: grid.cellWidth
							height: grid.cellHeight
							z: panel.hoveredWallpaper === modelData ? 2 : 1

							Rectangle {
								id: thumb

								anchors.centerIn: parent
								width: parent.width - 12
								height: parent.height - 12
								radius: 14
								color: "transparent"
								scale: panel.hoveredWallpaper === modelData ? 1.06 : 1

								Behavior on scale {
									NumberAnimation {
										duration: 340
										easing.type: Easing.OutBack
										easing.overshoot: 1.4
									}
								}

								SquircleImage {
									anchors.fill: parent
									source: "file://" + (panel.wallpaperIsVideo(modelData) ? panel.wallpaperThumb(modelData) : modelData)
									radius: 13
									power: 4
									sourceWidth: 168
									sourceHeight: 120
								}

								Rectangle {
									anchors.right: parent.right
									anchors.top: parent.top
									anchors.margins: 5
									width: panel.wallpaperIsVideo(modelData) ? 15 : 22
									height: 15
									radius: 7.5
									color: Qt.rgba(0, 0, 0, 0.55)
									visible: panel.wallpaperIsVideo(modelData) || panel.wallpaperIsAnimated(modelData)

									Shape {
										anchors.centerIn: parent
										anchors.verticalCenterOffset: -0.5
										anchors.horizontalCenterOffset: 0.6
										width: 7
										height: 8
										visible: panel.wallpaperIsVideo(modelData)
										preferredRendererType: Shape.CurveRenderer

										ShapePath {
											strokeColor: "transparent"
											fillColor: "white"
											startX: 0
											startY: 6.6
											PathLine { x: 0; y: 1.4 }
											PathQuad { controlX: 0; controlY: 0; x: 1.22; y: 0.69 }
											PathLine { x: 5.78; y: 3.31 }
											PathQuad { controlX: 7; controlY: 4; x: 5.78; y: 4.69 }
											PathLine { x: 1.22; y: 7.31 }
											PathQuad { controlX: 0; controlY: 8; x: 0; y: 6.6 }
										}
									}

									Text {
										anchors.centerIn: parent
										visible: !panel.wallpaperIsVideo(modelData)
										color: "white"
										font.family: panel.fontFamily
										font.pixelSize: 8
										font.weight: Font.Bold
										text: "GIF"
									}
								}

								Squircle {
									anchors.fill: parent
									power: 4
									radius: 14
									fillColor: "transparent"
								strokeColor: panel.accent
								strokeWidth: panel.hoveredWallpaper === modelData || panel.previewWallpaper === modelData ? 1.4 : 0
							}

							TapHandler {
								onTapped: {
									panel.previewWallpaper = modelData
									setter.target = modelData
									setter.running = true
								}
							}

							WheelHandler {
								onWheel: (wheel) => wheel.accepted = false
							}
						}
					}
					}

					Text {
						id: hint

						anchors.left: parent.left
						anchors.right: parent.right
						anchors.bottom: parent.bottom
						visible: !panel.wallpaperTool
						color: theme.danger
						font.family: panel.fontFamily
						font.pixelSize: 11
						text: "install awww to set wallpapers"
					}
				}
			}
		}

	}

	Item {
		id: inputArea

		anchors.horizontalCenter: cardHost.horizontalCenter
		anchors.top: parent.top
		width: panel.expanded ? cardHost.width : 0
		height: panel.expanded ? cardHost.y + cardHost.height : 0
	}
}
