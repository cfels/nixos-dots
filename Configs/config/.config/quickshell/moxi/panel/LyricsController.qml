import Quickshell
import Quickshell.Io
import QtQuick

Scope {
	id: lyricsState

	required property PlayerController media

	function resetTrack(): void {
		lyricsState.lookupDuration = lyricsState.lyricsDurations[lyricsState.lyricsKey] > 0 ? lyricsState.lyricsDurations[lyricsState.lyricsKey] : 0
		lyricsState.syncedLyrics = false
		lyricsState.lyrics = []
		lyricsState.lyricsPlain = []
		lyricsState.activeLyric = -1
		lyricsState.showLyrics = false
		lyricsState.lyricsLoadedKey = ""
		lyricsState.lyricsFetchKey = ""
	}

	function scheduleFetch(): void {
		lyricsDebounce.restart()
	}
	property var lyrics: []
	property bool syncedLyrics: true
	property bool lyricsWanted: false
	property var lyricsPlain: []
	property string lyricsKey: ""
	property string lyricsFetchKey: ""
	property string lyricsLoadedKey: ""
	property var lyricsMissing: ({})
	readonly property bool lyricsUnavailable: lyricsState.lyricsMissing[lyricsState.lyricsKey] === true
	property var lyricsDurations: ({})
	readonly property bool lyricsSearching: lyricsState.media.hasPlayer && lyricsState.lyrics.length === 0 && !lyricsState.lyricsUnavailable && (lyricsFetch.running || lyricsState.lyricsWanted || lyricsDebounce.running)
	property real lookupDuration: 0
	property int activeLyric: -1
	property bool showLyrics: false
	property real lyricsOffset: 0
	property real lyricsSyncOffset: 0
	property real lyricsMix: lyricsState.showLyrics ? 1 : 0
	readonly property real lyricsFade: Math.max(0, Math.min(1, lyricsState.lyricsMix))
	readonly property real lyricsBlur: Math.sin(Math.PI * lyricsState.lyricsFade)

	function parseLyrics(raw): var {
		var lines = raw.split("\n")
		var result = []
		var pattern = /^\[(\d+):(\d+(?:[.:]\d+)?)\](.*)$/

		for (var i = 0; i < lines.length; ++i) {
			var match = pattern.exec(lines[i])
			if (!match)
				continue
			var seconds = parseInt(match[1], 10) * 60 + parseFloat(match[2].replace(":", "."))
			var text = match[3].trim()
			if (text.length === 0)
				continue
			result.push({
				time: seconds,
				text: text
			})
		}

		return result
	}

	function noteMissingLyrics(): void {
		var key = lyricsState.lyricsKey

		if (key.length === 0)
			return
		var map = {}
		var known = Object.keys(lyricsState.lyricsMissing)

		for (var i = 0; i < known.length && i < 128; ++i)
			map[known[i]] = true

		map[key] = true
		lyricsState.lyricsMissing = map
	}

	function forgetMissingLyrics(): void {
		var key = lyricsState.lyricsKey

		if (key.length === 0 || lyricsState.lyricsMissing[key] !== true)
			return
		var map = {}
		var known = Object.keys(lyricsState.lyricsMissing)

		for (var i = 0; i < known.length; ++i) {
			if (known[i] !== key)
				map[known[i]] = true
		}

		lyricsState.lyricsMissing = map
	}

	function rememberDuration(seconds): void {
		var key = lyricsState.lyricsKey

		if (!(seconds > 0) || key.length === 0)
			return
		if (lyricsState.lyricsDurations[key] === seconds)
			return
		var map = {}
		var known = Object.keys(lyricsState.lyricsDurations)

		for (var i = 0; i < known.length && i < 256; ++i)
			map[known[i]] = lyricsState.lyricsDurations[known[i]]

		map[key] = seconds
		lyricsState.lyricsDurations = map
	}

	function applyPlainLyrics(): void {
		var raw = lyricsState.lyricsPlain
		var result = []

		for (var i = 0; i < raw.length; ++i) {
			var text = ("" + raw[i]).trim()
			result.push({
				time: -1,
				text: text
			})
		}

		lyricsState.lyrics = result
		lyricsState.syncedLyrics = false
		lyricsState.activeLyric = -1
		lyricsState.lyricsLoadedKey = lyricsState.lyricsKey
		lyricsState.showLyrics = true

		lyricsState.updateActiveLyric()
	}

	function applyLyrics(payload): void {
		if (!payload || payload.length === 0)
			return
		var data = null
		try {
			data = JSON.parse(payload)
		} catch (error) {
			return
		}

		if (!data)
			return
		if (lyricsState.lyricsFetchKey !== lyricsState.lyricsKey)
			return
		if (data.duration && data.duration > 0) {
			lyricsState.lookupDuration = data.duration
			lyricsState.rememberDuration(data.duration)
		}

		var hasSynced = data.syncedLyrics && data.syncedLyrics.length > 0
		var hasPlain = data.plainLyrics && data.plainLyrics.length > 0

		if (!hasSynced && !hasPlain) {
			if (lyricsState.lyrics.length > 0 && lyricsState.lyricsLoadedKey === lyricsState.lyricsKey)
				return
			lyricsState.lyrics = []
			lyricsState.lyricsPlain = []
			lyricsState.lyricsLoadedKey = ""
			lyricsState.noteMissingLyrics()

			return
		}

		if (hasSynced) {
			var parsed = lyricsState.parseLyrics(data.syncedLyrics)

			if (parsed.length > 0) {
				lyricsState.lyrics = parsed
				lyricsState.lyricsPlain = []
				lyricsState.syncedLyrics = true
				lyricsState.lyricsLoadedKey = lyricsState.lyricsKey
				lyricsState.showLyrics = true
				lyricsState.updateActiveLyric()
				return
			}
		}

		if (hasPlain) {
			lyricsState.lyricsPlain = data.plainLyrics.split("\n")
			lyricsState.applyPlainLyrics()
		}
	}

	function updateActiveLyric(): void {
		if (!lyricsState.media.expanded)
			return
		if (!lyricsState.syncedLyrics || lyricsState.lyrics.length === 0 || (!lyricsState.media.positionTrusted && lyricsState.media.seekTarget < 0)) {
			lyricsState.activeLyric = -1
			return
		}

		var position = lyricsState.media.trackPosition + lyricsState.lyricsSyncOffset
		var index = -1

		for (var i = 0; i < lyricsState.lyrics.length; ++i) {
			if (lyricsState.lyrics[i].time < 0)
				continue
			if (lyricsState.lyrics[i].time <= position)
				index = i
			else
				break
		}

		if (index !== lyricsState.activeLyric)
			lyricsState.activeLyric = index
	}

	function fetchLyrics(): void {
		if (lyricsState.media.trackTitle.length === 0)
			return
		if (lyricsState.lyrics.length > 0 && lyricsState.lyricsLoadedKey === lyricsState.lyricsKey)
			return
		if (lyricsState.lyricsUnavailable)
			return
		if (lyricsState.media.trackDuration > 0 && lyricsState.media.trackDuration < 30)
			return
		if (lyricsFetch.running) {
			if (lyricsState.lyricsFetchKey === lyricsState.lyricsKey)
				return
			lyricsState.lyricsWanted = true
			lyricsFetch.running = false
			return
		}

		lyricsState.lyricsFetchKey = lyricsState.lyricsKey
		lyricsState.lyricsWanted = false
		lyricsFetch.running = true
	}

	Behavior on lyricsMix {
		NumberAnimation {
			duration: 180
			easing.type: Easing.OutCubic
		}
	}

	Timer {
		id: lyricsDebounce

		interval: 1800
		onTriggered: lyricsState.fetchLyrics()
	}

	Timer {
		id: lyricsWatchdog

		interval: 11000
		running: lyricsFetch.running
		onTriggered: {
			if (!lyricsFetch.running)
				return
			lyricsState.lyricsWanted = false
			lyricsFetch.running = false
			lyricsState.noteMissingLyrics()
		}
	}

	Process {
		id: lyricsFetch

		command: [Quickshell.env("HOME") + "/.config/hypr/scripts/lyrics-fetch.sh", lyricsState.media.trackArtist, lyricsState.media.trackTitle, lyricsState.media.trackAlbum, String(lyricsState.media.hasPlayer && lyricsState.media.player.lengthSupported && lyricsState.media.player.length > 0 ? lyricsState.media.player.length : lyricsState.media.metadataLength), lyricsState.media.trackUrl]

		running: false

		stdout: SplitParser {
			onRead: line => lyricsState.applyLyrics(line)
		}

		onExited: (code, status) => {
			if (lyricsState.lyricsFetchKey !== lyricsState.lyricsKey)
				return
			if (lyricsState.lyricsLoadedKey === lyricsState.lyricsKey)
				return
			lyricsState.noteMissingLyrics()
		}

		onRunningChanged: {
			if (running || !lyricsState.lyricsWanted)
				return
			lyricsState.lyricsWanted = false
			lyricsState.lyricsFetchKey = lyricsState.lyricsKey
			lyricsFetch.running = true
		}
	}

	onLyricsSyncOffsetChanged: lyricsState.updateActiveLyric()
}
