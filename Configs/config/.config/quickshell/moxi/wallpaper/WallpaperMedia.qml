pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtMultimedia

Item {
	id: media

	property string path: ""
	property bool presentationActive: false
	property bool suspended: false
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
		fillMode: Image.PreserveAspectCrop
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
		fillMode: Image.PreserveAspectCrop
		playing: media.animated && media.path.length > 0
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
		fillMode: VideoOutput.PreserveAspectCrop
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
				media.videoReady = true
		}
	}
}
