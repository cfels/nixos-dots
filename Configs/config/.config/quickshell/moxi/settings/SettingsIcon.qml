import Quickshell.Io
import QtQuick

Image {
	id: icon
	required property string name
	property string markup: ""
	width: 18
	height: 18
	// Lucide's currentColor defaults to black in Qt SVG. Tint the SVG itself so
	// transparent strokes keep the palette color without a shader per icon.
	source: markup ? "data:image/svg+xml," + encodeURIComponent(markup.replace(/currentColor/g, SettingsStyle.theme.accent.toString())) : ""
	sourceSize: Qt.size(18, 18)
	fillMode: Image.PreserveAspectFit
	FileView {
		path: Qt.resolvedUrl("../assets/symbols/settings/" + icon.name + ".svg")
		blockLoading: true
		onLoaded: icon.markup = text()
	}
}
