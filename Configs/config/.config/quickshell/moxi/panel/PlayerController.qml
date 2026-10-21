import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Scope {
	id: media
	property bool expanded: false
	property bool dragging: false
	property real lookupDuration: 0
	signal seeked
	readonly property var player: media.pickPlayer()
	readonly property bool hasPlayer: media.player !== null
	property bool locallyPlaying: false
	property bool hasLocalOverride: false
	readonly property bool playing: media.hasLocalOverride ? media.locallyPlaying : (media.hasPlayer && media.player.playbackState === MprisPlaybackState.Playing)
	readonly property string trackTitle: media.hasPlayer && media.player.trackTitle ? media.player.trackTitle : ""
	readonly property string trackArtist: media.hasPlayer && media.player.trackArtist ? media.player.trackArtist : ""
	readonly property string trackAlbum: media.hasPlayer && media.player.trackAlbum ? media.player.trackAlbum : ""
	readonly property string trackKey: JSON.stringify([media.hasPlayer ? media.player.dbusName : "", media.hasPlayer ? media.player.metadata["mpris:trackid"] : "", media.trackUrl, media.trackArtist, media.trackTitle, media.trackAlbum])
	property var emptyPhrases: ["play sum shii-", "where the beats at?", "you hate music? don't ya?", "umapyoi", "nga where da ound's at", "play smth or i'll crash qs"]
	property int emptyPhraseIndex: 0
	readonly property string emptyPhrase: media.emptyPhrases.length > 0 ? media.emptyPhrases[Math.max(0, Math.min(media.emptyPhrases.length - 1, media.emptyPhraseIndex))] : "play sum shii-, where the beats at?"
	readonly property real metadataLength: {
		if (!media.hasPlayer)
			return 0

		var raw = media.player.metadata["mpris:length"]
		return raw ? raw / 1000000 : 0
	}
	readonly property real trackDuration: {
		if (media.hasPlayer && media.player.lengthSupported && media.player.length > 0)
			return media.player.length
		if (media.metadataLength > 0)
			return media.metadataLength

		return media.lookupDuration
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
	readonly property real progress: media.trackDuration > 0 ? Math.max(0, Math.min(1, media.trackPosition / media.trackDuration)) : 0
	readonly property string artUrl: {
		if (!media.hasPlayer)
			return ""

		var art = media.player.metadata["mpris:artUrl"]
		return art ? art : ""
	}
	readonly property string trackUrl: {
		if (!media.hasPlayer)
			return ""

		var url = media.player.metadata["xesam:url"]
		return url ? url : ""
	}

	function resetPosition(): void {
		media.trackPosition = 0
		media.dragPosition = 0
		media.positionFallback = false
		media.positionTrusted = false
		media.trustBase = -1
		media.lastReported = -1
		media.stallTicks = 0
		media.progressFast = true
		progressFastTimer.restart()
		media.seekSettling = false
		media.seekTarget = -1
		seekSettleTimer.stop()
	}

	function pickPlayer(): var {
		var list = Mpris.players.values

		for (var i = 0; i < list.length; ++i) {
			var candidate = list[i]

			if (!candidate)
				continue
			if (("" + candidate.dbusName + " " + candidate.identity).toLowerCase().indexOf("playerctld") !== -1)
				continue
			if (("" + candidate.trackTitle).trim().length === 0 && candidate.playbackState !== MprisPlaybackState.Playing)
				continue
			return candidate
		}

		return null
	}

	function togglePlayback(): void {
		if (!media.hasPlayer || !media.player.canTogglePlaying)
			return
		media.locallyPlaying = !media.playing
		media.hasLocalOverride = true
		media.player.togglePlaying()
	}

	function rollEmptyPhrase(): void {
		if (media.emptyPhrases.length <= 1)
			return
		var next = media.emptyPhraseIndex

		while (next === media.emptyPhraseIndex)
			next = Math.floor(Math.random() * media.emptyPhrases.length)

		media.emptyPhraseIndex = next
	}

	function timeText(seconds): string {
		if (!isFinite(seconds) || seconds <= 0)
			return "--:--"

		var total = Math.round(seconds)
		var minutes = Math.floor(total / 60)
		var rest = total % 60

		return minutes + ":" + (rest < 10 ? "0" : "") + rest
	}

	function positionText(seconds): string {
		if (!isFinite(seconds) || seconds < 0)
			return "--:--"

		var total = Math.floor(seconds)
		var minutes = Math.floor(total / 60)
		var rest = total % 60

		return minutes + ":" + (rest < 10 ? "0" : "") + rest
	}

	function seekTo(seconds, offset): void {
		if (!media.hasPlayer || !media.player.canSeek || !isFinite(seconds) || seconds < 0)
			return
		if (offset !== undefined && !isFinite(offset))
			return
		if (offset !== undefined)
			media.player.seek(offset)
		else
			media.player.position = seconds
		media.trackPosition = seconds
		media.dragPosition = seconds
		media.lastReported = -1
		media.stallTicks = 0
		media.progressFast = true
		progressFastTimer.restart()
		media.seekSettling = true
		media.seekTarget = seconds
		media.seekAt = Date.now()
		seekSettleTimer.restart()
		media.seeked()
	}

	Timer {
		id: progressFastTimer

		interval: 360
		onTriggered: media.progressFast = false
	}

	Timer {
		id: seekSettleTimer

		interval: 2500
		onTriggered: {
			media.seekSettling = false
			media.seekTarget = -1
			media.trustBase = -1
			media.positionTrusted = false
		}
	}

	Timer {
		interval: 250
		running: media.hasPlayer
		repeat: true
		onTriggered: {
			if (!media.player.positionSupported) {
				if (!media.playing)
					return
				media.stallTicks += 1

				if (media.stallTicks > 8)
					media.positionFallback = true

				return
			}

			var reported = media.player.position

			if (!isFinite(reported) || reported < 0)
				return
			if (media.trackDuration > 0 && reported > media.trackDuration + 1)
				return
			var advanced = reported > media.lastReported + 0.05
			var moved = media.lastReported >= 0 && Math.abs(reported - media.lastReported) > 0.05

			if (advanced || moved) {
				media.stallTicks = 0
				media.positionFallback = false
			} else if (media.playing) {
				media.stallTicks += 1

				if (media.stallTicks > 8)
					media.positionFallback = true
			}

			if (media.trustBase < 0) {
				media.trustBase = reported
				if (reported > 0 || !media.playing)
					media.positionTrusted = true
			} else if (reported - media.trustBase > 0.3)
				media.positionTrusted = true
			if (moved)
				media.positionTrusted = true

			media.lastReported = reported

			if (media.seekTarget >= 0) {
				if (Math.abs(reported - media.seekTarget) < 1.5) {
					media.seekTarget = -1
					media.seekSettling = false
					seekSettleTimer.stop()

					return
				}

				if (Date.now() - media.seekAt < 2200)
					return
				media.seekTarget = -1
				media.seekSettling = false
				seekSettleTimer.stop()
				media.trustBase = -1
				media.positionTrusted = false

				return
			}

			if (!media.positionTrusted)
				return
			if (media.positionFallback)
				return
			if (media.dragging)
				return
			var drift = reported - media.trackPosition

			if (Math.abs(drift) > 1.5)
				media.trackPosition = reported
			else if (Math.abs(drift) > 0.35)
				media.trackPosition += drift * 0.5
		}
	}

	Timer {
		interval: media.expanded ? 33 : 250
		running: media.hasPlayer && media.playing && !media.dragging
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

			var rate = media.player.rate > 0 ? media.player.rate : 1
			var next = media.trackPosition + delta * rate

			media.trackPosition = media.trackDuration > 0 ? Math.min(media.trackDuration, next) : next
		}
	}

	Connections {
		target: media.player

		function onPlaybackStateChanged() {
			if (!media.hasLocalOverride)
				return
			var reported = media.player.playbackState === MprisPlaybackState.Playing

			if (reported === media.locallyPlaying)
				media.hasLocalOverride = false
		}
	}
}
