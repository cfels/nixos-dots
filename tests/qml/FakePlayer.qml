import QtQuick
import Quickshell.Services.Mpris

QtObject {
	property string dbusName: "org.mpris.MediaPlayer2.test"
	property string identity: "Fixture player"
	property string trackTitle: "Song A"
	property string trackArtist: "Artist"
	property string trackAlbum: "Album"
	property var metadata: ({ "mpris:trackid": "A", "mpris:length": 180000000, "xesam:url": "file:///work/song" })
	property int playbackState: MprisPlaybackState.Paused
	property bool canTogglePlaying: true
	property bool canSeek: true
	property bool canGoNext: true
	property bool canGoPrevious: true
	property bool lengthSupported: true
	property real length: 180
	property bool positionSupported: true
	property real position: 0
	property real rate: 1
	property int toggles: 0
	property real lastSeek: 0
	function togglePlaying(): void { toggles += 1 }
	function seek(offset): void { lastSeek = offset }
	function previous(): void {}
	function next(): void {}
}
