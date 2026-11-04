pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

Item {
	id: wallpaper

	property string path: ""
	property string outputName: "default"
	property bool presentationActive: false
	property bool suspended: false
	property var config: null
	property string playbackState: "INITIALIZING"
	property string previousState: "INITIALIZING"
	property string error: ""
	property bool claimDone: false
	property bool useOpening: false
	property bool startupSound: false
	property bool showcaseDisplayed: false
	property bool openingRetired: false
	property bool completed: false
	property int loopCount: 0
	property int lastLoopPosition: 0
	readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/premium-wallpaper.py"
	readonly property PremiumVideo showcaseVideo: showcase
	readonly property PremiumVideo openingVideo: opening.item as PremiumVideo
	readonly property bool ready: claimDone && config !== null && poster.status === Image.Ready && showcase.ready && (!useOpening || openingRetired || (openingVideo !== null && openingVideo.ready))
	readonly property int position: playbackState === "OPENING" && openingVideo ? openingVideo.position : showcase.position
	readonly property bool paused: suspended && config !== null && config.pauseWhenFullscreen
	readonly property bool waitingForAudio: useOpening && openingVideo !== null && !openingVideo.audioReady

	signal failed(string message)

	function setPlaybackState(next): void {
		if (playbackState === next)
			return
		playbackState = next
		console.info("PremiumWalls:", outputName, next)
	}

	function fail(message): void {
		error = message
		setPlaybackState("ERROR")
		console.error("PremiumWalls:", message)
		failed(message)
	}

	function advance(): void {
		if (!ready || !presentationActive || playbackState !== "INITIALIZING" || paused || waitingForAudio)
			return
		setPlaybackState(useOpening ? "OPENING" : "TRANSITIONING")
	}

	onConfigChanged: {
		if (config && config.loop && completed) {
			completed = false
			loopCount++
			lastLoopPosition = 0
			previousState = "SHOWCASE_LOOP"
			setPlaybackState(paused ? "PAUSED" : "SHOWCASE_LOOP")
		}
		if (config && !config.openingEnabled && claimDone && useOpening && !showcaseDisplayed) {
			if (playbackState === "OPENING")
				setPlaybackState("TRANSITIONING")
			else if (playbackState === "PAUSED")
				previousState = "TRANSITIONING"
			else if (playbackState === "INITIALIZING")
				useOpening = false
		}
	}

	onReadyChanged: advance()
	onPresentationActiveChanged: advance()
	onWaitingForAudioChanged: {
		if (waitingForAudio)
			console.info("PremiumWalls:", outputName, "waiting for an audio output")
		advance()
	}
	onPausedChanged: {
		if (paused && playbackState !== "PAUSED" && playbackState !== "ERROR") {
			previousState = playbackState
			setPlaybackState("PAUSED")
		} else if (!paused && playbackState === "PAUSED" && !completed) {
			setPlaybackState(previousState)
			advance()
		}
	}

	FileView {
		path: wallpaper.path
		watchChanges: true
		printErrors: false
		onFileChanged: {
			reload()
			description.running = true
		}
	}

	Process {
		id: description
		command: ["python3", wallpaper.helper, "describe", wallpaper.path]
		running: wallpaper.path.length > 0
		stdout: StdioCollector {
			id: metadata
		}
		stderr: StdioCollector {
			id: metadataError
		}
		onExited: (code, status) => {
			if (code !== 0) {
				wallpaper.fail(metadataError.text.trim() || "could not read Velina manifest")
				return
			}
			try {
				wallpaper.config = JSON.parse(metadata.text)
				if (!wallpaper.claimDone) {
					if (wallpaper.config.openingEnabled)
						reservation.running = true
					else
						wallpaper.claimDone = true
				}
			} catch (error) {
				wallpaper.fail("invalid Velina metadata: " + error)
			}
		}
	}

	Process {
		id: reservation
		command: ["python3", wallpaper.helper, "claim", wallpaper.outputName].concat(wallpaper.config && wallpaper.config.startupAudio ? ["--audio"] : [])
		stdout: StdioCollector {
			id: reserved
		}
		stderr: StdioCollector {
			id: reserveError
		}
		onExited: (code, status) => {
			if (code !== 0) {
				wallpaper.fail(reserveError.text.trim() || "could not reserve opening playback")
				return
			}
			try {
				const result = JSON.parse(reserved.text)
				wallpaper.useOpening = result.opening
				wallpaper.startupSound = result.audio
				wallpaper.claimDone = true
			} catch (error) {
				wallpaper.fail("invalid session reservation: " + error)
			}
		}
	}

	Rectangle {
		anchors.fill: parent
		color: "#f8faff"
	}

	Image {
		id: poster
		anchors.fill: parent
		source: wallpaper.claimDone && wallpaper.config ? wallpaper.useOpening ? wallpaper.config.openingPoster : wallpaper.config.poster : ""
		fillMode: wallpaper.config && wallpaper.config.fit === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
		asynchronous: true
		onStatusChanged: if (status === Image.Error)
			wallpaper.fail("could not load Velina poster")
	}

	PremiumVideo {
		id: showcase
		anchors.fill: parent
		source: wallpaper.config ? wallpaper.config.showcase : ""
		cover: !wallpaper.config || wallpaper.config.fit === "cover"
		loop: wallpaper.config !== null && wallpaper.config.loop
		playing: wallpaper.playbackState === "TRANSITIONING" || wallpaper.playbackState === "SHOWCASE_LOOP"
		visible: wallpaper.claimDone && (!wallpaper.useOpening || wallpaper.showcaseDisplayed)
		onReadyChanged: wallpaper.advance()
		onPositionChanged: {
			if (wallpaper.playbackState === "SHOWCASE_LOOP") {
				if (position + 200 < wallpaper.lastLoopPosition)
					wallpaper.loopCount++
				wallpaper.lastLoopPosition = position
			}
		}
		onPresented: {
			if (wallpaper.playbackState === "TRANSITIONING") {
				wallpaper.showcaseDisplayed = true
				wallpaper.setPlaybackState("SHOWCASE_LOOP")
				wallpaper.openingRetired = true
			}
		}
		onEnded: {
			if (wallpaper.playbackState === "SHOWCASE_LOOP") {
				wallpaper.completed = true
				wallpaper.previousState = "SHOWCASE_LOOP"
				wallpaper.setPlaybackState("PAUSED")
			}
		}
		onFailed: message => wallpaper.fail("showcase: " + message)
	}

	Loader {
		id: opening
		anchors.fill: parent
		active: wallpaper.config !== null && !wallpaper.openingRetired && wallpaper.claimDone && wallpaper.useOpening
		visible: wallpaper.useOpening && !wallpaper.showcaseDisplayed
		sourceComponent: PremiumVideo {
			source: wallpaper.config.opening
			cover: wallpaper.config.fit === "cover"
			playing: wallpaper.playbackState === "OPENING"
			audioEnabled: wallpaper.startupSound && wallpaper.config.startupAudio
			onReadyChanged: wallpaper.advance()
			onEnded: {
				wallpaper.previousState = "TRANSITIONING"
				wallpaper.setPlaybackState(wallpaper.paused ? "PAUSED" : "TRANSITIONING")
			}
			onFailed: message => wallpaper.fail("opening: " + message)
		}
	}

	Item {
		anchors.centerIn: parent
		width: wallpaper.config && wallpaper.config.fit === "contain" ? Math.min(wallpaper.width, wallpaper.height * 16 / 9) : Math.max(wallpaper.width, wallpaper.height * 16 / 9)
		height: width * 9 / 16
		VelinaEffects {
			anchors.fill: parent
			leafTexture: wallpaper.config ? wallpaper.config.leafTexture : ""
			quality: wallpaper.config ? wallpaper.config.effectsQuality : "off"
			running: wallpaper.presentationActive && wallpaper.playbackState !== "PAUSED" && wallpaper.playbackState !== "ERROR" && wallpaper.playbackState !== "INITIALIZING"
			opening: wallpaper.useOpening && !wallpaper.showcaseDisplayed
			openingPosition: wallpaper.openingVideo ? wallpaper.openingVideo.position : 8350
			timelinePosition: wallpaper.useOpening && !wallpaper.showcaseDisplayed ? openingPosition : (wallpaper.useOpening ? 8350 : 0) + wallpaper.loopCount * showcase.duration + showcase.position
		}
	}
}
