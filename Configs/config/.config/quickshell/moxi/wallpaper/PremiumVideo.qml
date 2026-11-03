import QtQuick
import QtMultimedia

Item {
	id: video

	property url source: ""
	property bool playing: false
	property bool audioEnabled: false
	property bool loop: false
	property bool cover: true
	property bool ready: false
	property bool started: false
	readonly property int position: playback.position
	readonly property int duration: playback.duration
	readonly property MediaPlayer player: playback

	signal presented
	signal ended
	signal failed(string message)

	onPlayingChanged: {
		if (ready) {
			if (playing) {
				if (!started) {
					playback.position = 0
					started = true
				}
				playback.play()
			} else
				playback.pause()
		}
	}
	onSourceChanged: {
		ready = false
		started = false
	}

	VideoOutput {
		id: surface
		anchors.fill: parent
		fillMode: video.cover ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
		endOfStreamPolicy: VideoOutput.KeepLastFrame
	}

	MediaPlayer {
		id: playback
		source: video.source
		videoOutput: surface
		loops: video.loop ? MediaPlayer.Infinite : 1
		audioOutput: AudioOutput {
			muted: !video.audioEnabled || !video.playing
		}
		onMediaStatusChanged: {
			if (mediaStatus === MediaPlayer.LoadedMedia && !video.ready) {
				// Decode one frame now, rather than at the handoff.
				play()
			} else if (mediaStatus === MediaPlayer.EndOfMedia)
				video.ended()
		}
		onErrorOccurred: (error, message) => video.failed(message)
	}

	Connections {
		target: surface.videoSink
		function onVideoFrameChanged(): void {
			if (!playback.hasVideo || playback.mediaStatus === MediaPlayer.EndOfMedia)
				return
			video.ready = true
			if (!video.playing)
				playback.pause()
			else
				video.presented()
		}
	}
}
