import Quickshell
import Quickshell.Io
import QtQuick

Item {
	id: theme

	property var palette: ({})

	readonly property color accent: theme.pick("accent", "#cba6f7")
	readonly property color foreground: theme.pick("foreground", "#cdd6f4")
	readonly property color muted: theme.pick("muted", "#7f849c")
	readonly property color idle: theme.pick("idle", "#45475a")
	readonly property color background: theme.pick("background", "#11111b")
	readonly property color surface: theme.pick("surface", "#45475a")
	readonly property color danger: theme.pick("danger", "#f38ba8")

	FileView {
		id: colors

		path: Quickshell.shellDir + "/colors.json"
		blockLoading: true
		printErrors: false
	}

	Component.onCompleted: theme.reload()

	function pick(key: string, fallback: color): color {
		var value = theme.palette[key]

		return value ? value : fallback
	}

	function reload(): void {
		var raw = colors.text()

		if (!raw || raw.length === 0) return

		try {
			theme.palette = JSON.parse(raw)
		} catch (error) {
			theme.palette = ({})
		}
	}
}
