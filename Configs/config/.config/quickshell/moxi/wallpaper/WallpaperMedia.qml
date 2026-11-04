pragma ComponentBehavior: Bound
import QtQuick
import "../components" as Shared
import QtQuick.Window
import QtMultimedia

Item {
	id: media

	property string path: ""
	property bool presentationActive: false
	property bool suspended: false
	readonly property bool paused: suspended && Shared.Preferences.value("wallpaper.pauseFullscreen", false)
	readonly property bool contain: Shared.Preferences.value("wallpaper.fit", "cover") === "contain"
	onPausedChanged: if (player && videoReady) { if (paused) player.pause(); else player.play() }
	property string outputName: "default"
	readonly property VelinaWallpaper premiumPlayer: premiumPlayback.item as VelinaWallpaper
	readonly property bool premium: /\.premiumwall\.json$/i.test(path)
	readonly property string playbackState: premium && premiumPlayer ? premiumPlayer.playbackState : ""
	readonly property string playbackError: premium && premiumPlayer ? premiumPlayer.error : ""
	readonly property bool video: /\.(mp4|m4v|webm|mkv|mov|avi)$/i.test(path)
	readonly property bool animated: /\.gif$/i.test(path)
	readonly property url sourceUrl: path.length > 0 ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
	property bool videoReady: false
	readonly property bool ready: path.length > 0 && (premium ? premiumPlayer !== null && premiumPlayer.ready : video ? videoReady : animated ? animation.status === Image.Ready : image.status === Image.Ready)
	readonly property MediaPlayer player: playback.item as MediaPlayer
	readonly property int position: premium && premiumPlayer ? premiumPlayer.position : player ? player.position : 0

	signal failed(string message)

	onPathChanged: videoReady = false

	Image {
		id: image
		anchors.fill: parent
		visible: !media.video && !media.animated && !media.premium
		source: !media.video && !media.animated && !media.premium ? media.sourceUrl : ""
		fillMode: media.contain ? Image.PreserveAspectFit : Image.PreserveAspectCrop
		sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
		asynchronous: true
		onStatusChanged: {
			if (status === Image.Error)
				media.failed("could not load image: " + media.path)
		}
	}

	AnimatedImage {
		id: animation
		anchors.fill: parent
		visible: media.animated
		source: media.animated ? media.sourceUrl : ""
		fillMode: media.contain ? Image.PreserveAspectFit : Image.PreserveAspectCrop
		playing: media.animated && media.path.length > 0 && !media.paused
		cache: false
		onStatusChanged: {
			if (status === Image.Error)
				media.failed("could not load animation: " + media.path)
		}
	}

	Loader {
		id: premiumPlayback
		anchors.fill: parent
		active: media.premium
		sourceComponent: VelinaWallpaper {
			path: media.path
			outputName: media.outputName
			presentationActive: media.presentationActive
			suspended: media.suspended
			onFailed: message => media.failed(message)
		}
	}

	VideoOutput {
		id: videoSurface
		anchors.fill: parent
		visible: media.video
		fillMode: media.contain ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
	}

	Loader {
		id: playback
		active: media.video && media.path.length > 0
		sourceComponent: MediaPlayer {
			source: media.sourceUrl
			autoPlay: true
			loops: MediaPlayer.Infinite
			activeAudioTrack: -1
			videoOutput: videoSurface
			onErrorOccurred: (error, errorString) => media.failed(errorString)
		}
	}

	Connections {
		target: videoSurface.videoSink
		function onVideoFrameChanged(): void {
			if (media.player && media.player.hasVideo)
				{ media.videoReady = true; if (media.paused) media.player.pause() }
		}
	}
}
