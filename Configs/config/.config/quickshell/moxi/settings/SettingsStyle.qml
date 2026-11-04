pragma Singleton
import Quickshell
import QtQuick
import "../components"
import "../panel"

Scope {
	property alias theme: palette
	readonly property string fontFamily: fonts.fontFamily
	readonly property int spacing: 20
	readonly property int radius: 24
	function popupSource(item, sceneRoot) {
		if (!item || !sceneRoot)
			return null
		let root = item
		while (root.parent && root.parent !== sceneRoot)
			root = root.parent
		// Popup visuals live in Overlay, outside this scene child. Sampling the
		// window contentItem itself would capture the popup recursively.
		return root.parent === sceneRoot ? root : null
	}
	Theme {
		id: palette
	}
	PanelFonts {
		id: fonts
	}
}
