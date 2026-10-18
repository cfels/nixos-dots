import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "moxi/panel"

ShellRoot {
	id: scenario

	property int step: 0
	property string artworkKey: ""
	property string artworkSource: ""

	function check(condition, message): void {
		if (!condition) throw new Error(message)
	}

	FileView {
		id: reloadMarker
		path: "/work/reload-marker"
		blockLoading: true
		printErrors: false
	}

	Process {
		id: markReload
		command: ["bash", "-c", "printf reloaded > /work/reload-marker"]
		onExited: Quickshell.reload(true)
	}

	FakePlayer { id: fakePlayer }

	Window {
		visible: true
		width: 1000
		height: 600

		Panel {
			id: subject
			width: 1000
			height: 490
		}
	}

	Timer {
		id: scenarioTimer
		interval: 350
		running: true
		repeat: true
		onTriggered: {
			try {
				var wallpaper = subject.testWallpaper
				var media = subject.testMedia
				var lyrics = subject.testLyrics
				if (reloadMarker.text() === "reloaded") {
					scenario.check(media.hasPlayer === (Quickshell.env("PANEL_INITIAL_PLAYER") === "1") && !subject.expanded && wallpaper.wallpapers.length === 2, "reload recreates feature lifetimes")
					console.log("PANEL_SCENARIO_OK")
					Qt.quit()
					return
				}
				if (scenario.step === 0) {
					scenario.check(wallpaper.wallpapers.length === 2, "wallpaper scan must deduplicate paths")
					scenario.check(wallpaper.wallpaperThumb("/work/video.mp4") === "/work/image.svg", "video thumbnail")
					scenario.check(wallpaper.wallpaperSource("/work/video.mp4") === "/work/preview.gif", "video preview")
					scenario.check(wallpaper.wallpaperSourceAnimated("/work/video.mp4"), "video preview animation")
					scenario.check(wallpaper.previewWallpaper === "/work/image.svg", "first wallpaper selected")
					scenario.check(!subject.expanded, "starts collapsed")
					scenario.check(lyrics.lyricsKey === media.trackKey, "initial track initialization")
					scenario.check(media.hasPlayer === (Quickshell.env("PANEL_INITIAL_PLAYER") === "1"), "initial player selection")
					subject.setAnchor(224, 40, 7)
					scenario.check(subject.anchorWidth === 224 && subject.anchorHeight === 40 && subject.anchorY === 7, "anchor interface")
					subject.expanded = true
				} else if (scenario.step === 1) {
					scenario.check(subject.contentVisible && subject.surfaceVisible, "expansion timers")
					subject.testCalendar.selectedDay = 12
					wallpaper.hoveredWallpaper = "/work/video.mp4"
					subject.expanded = false
					scenario.check(subject.testCalendar.selectedDay === 0, "collapse resets calendar")
					scenario.check(wallpaper.hoveredWallpaper === "", "collapse resets wallpaper hover")
				} else if (scenario.step === 2) {
					scenario.check(!subject.contentVisible && !subject.surfaceVisible, "collapse timers")
					media.player = fakePlayer
					scenario.check(media.hasPlayer && media.trackTitle === "Song A", "reactive MPRIS metadata")
					scenario.check(media.trackDuration === 180, "player duration")
					media.seekTo(45)
					scenario.check(fakePlayer.position === 45 && media.seekTarget === 45, "absolute seek")
					scenario.check(media.trackPosition === 45 && media.dragPosition === 45 && media.seekSettling, "optimistic seek state")
					media.seekTo(50, -12)
					scenario.check(fakePlayer.lastSeek === -12 && media.trackPosition === 50, "relative seek")
					media.seekTo(-1)
					scenario.check(media.trackPosition === 50, "invalid seek ignored")
					var timeline = subject.testTimeline
					timeline.dragging = true
					timeline.relativeSeek = false
					timeline.dragBase = 50
					timeline.preview(timeline.width / 2)
					scenario.check(media.dragPosition === 90 && media.trackPosition === 90, "drag preview")
					timeline.dragging = false
					timeline.commit()
					scenario.check(fakePlayer.position === 90, "drag commit")
					timeline.dragging = true
					timeline.cancel()
					scenario.check(media.trackPosition === 50 && !timeline.dragging, "drag cancellation")
					media.togglePlayback()
					scenario.check(media.playing && media.hasLocalOverride && fakePlayer.toggles === 1, "optimistic playback")
				} else if (scenario.step === 3) {
					fakePlayer.playbackState = MprisPlaybackState.Playing
					scenario.check(!media.hasLocalOverride, "playback acknowledgement")
					fakePlayer.playbackState = MprisPlaybackState.Paused
					subject.expanded = true
					lyrics.lyricsFetchKey = lyrics.lyricsKey
					lyrics.applyLyrics(JSON.stringify({duration: 180, syncedLyrics: "[00:01.000]one\n[00:02.000]two", plainLyrics: ""}))
					media.positionTrusted = true
					media.seekTarget = -1
					media.trackPosition = 1.2
					scenario.check(lyrics.activeLyric === 0 && lyrics.lyrics.length === 2 && lyrics.showLyrics, "active lyric follows position")
					lyrics.applyLyrics(JSON.stringify({duration: 181, syncedLyrics: "", plainLyrics: ""}))
					scenario.check(lyrics.lyrics.length === 2 && lyrics.lookupDuration === 181, "duration-only payload keeps loaded lyrics")
					subject.testTimeline.dragging = true
					subject.testLyricsView.manual = true
					fakePlayer.trackTitle = "Slow"
					scenario.check(!subject.testTimeline.dragging && !subject.testLyricsView.manual, "track switch resets interaction")
					scenario.check(lyrics.lyrics.length === 0 && !lyrics.showLyrics && media.trackPosition === 0, "track switch resets media state")
					lyrics.applyLyrics(JSON.stringify({duration: 999, syncedLyrics: "[00:01]stale"}))
					scenario.check(lyrics.lyrics.length === 0 && lyrics.lookupDuration !== 999, "stale payload ignored")
					lyrics.fetchLyrics()
				} else if (scenario.step === 4) {
					fakePlayer.trackTitle = "Latest"
					lyrics.fetchLyrics()
				} else if (scenario.step === 9) {
					scenario.check(lyrics.lyrics.length === 2 && lyrics.syncedLyrics && lyrics.lyricsLoadedKey === lyrics.lyricsKey, "process cancellation restarts latest track")
					scenario.check(lyrics.lyrics[0].text === "Latest one", "cancelled process cannot publish stale text")
					scenario.check(subject.testArtwork.artSource.length > 0, "artwork process publication")
					scenario.check(subject.testLyricsView.count === 2 && subject.testLyricsView.followIndex === lyrics.activeLyric, "lyrics list follows controller selection")
					subject.testLyricsView.glideBy(40)
					scenario.check(subject.testLyricsView.manual, "manual lyric scrolling")
					scenario.artworkKey = subject.testArtwork.artCacheKey
					scenario.artworkSource = subject.testArtwork.artSource
					fakePlayer.metadata = Object.assign({}, fakePlayer.metadata, {"mpris:artUrl": "file:///work/tiny.svg"})
				} else if (scenario.step === 10) {
					scenario.check(subject.testArtwork.artCacheKey === scenario.artworkKey, "artwork URL refresh keeps the recording cache key")
					if (Quickshell.env("PANEL_REAL_ARTWORK") === "1")
						scenario.check(subject.testArtwork.artSource === scenario.artworkSource, "late low-resolution artwork cannot replace the high-resolution cover")
					media.player = null
				} else if (scenario.step === 11) {
					scenario.check(!media.hasPlayer && subject.testArtwork.artSource === "", "player disappearance clears artwork")
					fakePlayer.trackTitle = "Missing"
					fakePlayer.lengthSupported = false
					fakePlayer.metadata = ({"mpris:trackid": "missing", "xesam:url": "https://music.youtube.com/playlist?list=LM"})
					fakePlayer.playbackState = MprisPlaybackState.Playing
					media.player = fakePlayer
					scenario.check(lyrics.lyricsSearching && subject.testTimeline.waiting, "unknown duration starts lyrics search")
				} else if (scenario.step === 18) {
					scenario.check(media.trackDuration === 0 && media.playing && lyrics.lyricsUnavailable, "missing lyrics and duration finish lookup")
					scenario.check(!lyrics.lyricsSearching && !subject.testTimeline.waiting, "completed lookup stops searching with unknown duration")
					fakePlayer.trackTitle = "Retry"
				} else if (scenario.step === 25) {
					scenario.check(lyrics.lyricsRetryable && !lyrics.lyricsUnavailable, "network failure remains retryable")
					scenario.check(!lyrics.lyricsSearching && !subject.testTimeline.waiting, "backoff does not show an endless search")
					subject.expanded = false
					subject.expanded = true
				} else if (scenario.step === 28) {
					scenario.check(lyrics.syncedLyrics && lyrics.lyrics.length === 2 && lyrics.lyrics[0].text === "Retry one", "reopening retries a transient failure successfully")
					scenarioTimer.stop()
					markReload.running = true
				}
				scenario.step += 1
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
