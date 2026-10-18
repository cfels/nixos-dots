import Quickshell
import Quickshell.Io
import QtQuick

Scope {
	id: artworkState

	required property PlayerController media
	property bool artWanted: false
	property int artVersion: 0
	property bool artUnchanged: false
	property string artSource: ""
	property string artSourceKey: ""
	property string artFetchKey: ""
	property string artShownFile: ""
	readonly property string artTrackKey: {
		var url = artworkState.media.trackUrl
		var video = url.match(/^https?:\/\/(?:(?:www|music)\.)?(?:youtube\.com\/watch\?(?:[^#]*&)?v=|youtu\.be\/)([A-Za-z0-9_-]{11})(?:[?&#/]|$)/)
		var recording = video ? "youtube:" + video[1] : url

		return JSON.stringify([artworkState.media.hasPlayer ? artworkState.media.player.dbusName : "", recording || [artworkState.media.trackArtist, artworkState.media.trackTitle]])
	}
	readonly property string artCachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/moxi/art"
	readonly property string artCacheKey: {
		var source = JSON.stringify([artworkState.media.trackArtist, artworkState.media.trackTitle, artworkState.media.trackAlbum, artworkState.media.trackUrl])
		var hash = 5381

		for (var i = 0; i < source.length; ++i)
			hash = ((hash * 33) ^ source.charCodeAt(i)) >>> 0

		return hash.toString(16)
	}
	readonly property string artCacheFile: artworkState.artCachePath + "/art-v3-" + artworkState.artCacheKey + ".img"

	function fetchArtwork(): void {
		if (artCache.running) {
			artworkState.artWanted = true
			if (artworkState.artFetchKey !== artworkState.artCacheKey)
				artCache.running = false
			return
		}

		artworkState.artFetchKey = artworkState.artCacheKey
		artworkState.artWanted = false
		artCache.running = true
	}

	function scheduleArt(delay): void {
		artDebounce.interval = delay
		artDebounce.restart()
	}

	Timer {
		id: artDebounce

		interval: 180
		onTriggered: artworkState.fetchArtwork()
	}

	Process {
		id: artCache

		command: [Quickshell.env("HOME") + "/.config/hypr/scripts/artwork-fetch.sh", artworkState.media.artUrl, artworkState.media.trackUrl, artworkState.media.trackArtist, artworkState.media.trackTitle, artworkState.artCacheFile, artworkState.artShownFile, artworkState.media.trackAlbum]

		onExited: (code, status) => {
			if (artworkState.artFetchKey !== artworkState.artCacheKey)
				return
			if (code !== 0 && code !== 2)
				return
			artworkState.artUnchanged = code === 2
			if (!artworkState.artUnchanged)
				artworkState.artVersion = artworkState.artVersion + 1
			artworkState.artShownFile = artworkState.artCacheFile
			artworkState.artSourceKey = artworkState.artCacheKey
			artworkState.artSource = "file://" + artworkState.artCacheFile + "?v=" + artworkState.artVersion
		}

		onRunningChanged: {
			if (running || !artworkState.artWanted)
				return
			artworkState.artWanted = false
			artworkState.artFetchKey = artworkState.artCacheKey
			artCache.running = true
		}
	}
}
