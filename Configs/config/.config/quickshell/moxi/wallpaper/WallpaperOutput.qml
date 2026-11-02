import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: output

	property alias canvas: canvas
	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}
	exclusionMode: ExclusionMode.Ignore
	color: "transparent"
	mask: Region {}
	WlrLayershell.namespace: "moxi-wallpaper"
	WlrLayershell.layer: WlrLayer.Bottom
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	WallpaperCanvas {
		id: canvas
		anchors.fill: parent
	}
}
