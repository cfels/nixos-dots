pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtMultimedia

Item {
	id: media

	property string path: ""
	readonly property bool video: /\.(mp4|m4v|webm|mkv|mov|avi)$/i.test(path)
	readonly property bool animated: /\.gif$/i.test(path)
	readonly property url sourceUrl: path.length > 0 ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
	property bool videoReady: false
	readonly property bool ready: path.length > 0 && (video ? videoReady : animated ? animation.status === Image.Ready : image.status === Image.Ready)
	readonly property MediaPlayer player: playback.item as MediaPlayer
	readonly property int position: player ? player.position : 0

	signal failed(string message)

	onPathChanged: videoReady = false

	Image {
		id: image
		anchors.fill: parent
		visible: !media.video && !media.animated
		source: !media.video && !media.animated ? media.sourceUrl : ""
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
