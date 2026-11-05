pragma Singleton

import Quickshell
import QtQuick

Scope {
	readonly property string family: merged.status === FontLoader.Ready ? merged.name : "Moxi Trust"
	function escaped(text): string {
		return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
	}
	function styled(text, colors): string {
		if (!colors)
			return escaped(text)
		return Array.from(String(text)).map((character, index) => colors[index] ? '<font color="' + escaped(colors[index]) + '">' + escaped(character) + '</font>' : escaped(character)).join("")
	}
	FontLoader {
		id: merged
		source: "../fonts/MoxiTrust-ExtraBold.ttf"
	}
}
