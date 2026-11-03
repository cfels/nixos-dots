import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
	id: output

	property alias canvas: canvas
	property string outputName: "default"

	function fullscreenOnOutput(): bool {
		const window = ToplevelManager.activeToplevel
		if (!window || !window.fullscreen)
			return false
		for (const screen of window.screens) {
			if (screen === output.screen)
				return true
		}
		return false
	}
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
		outputName: output.outputName
		suspended: output.fullscreenOnOutput()
	}
}
