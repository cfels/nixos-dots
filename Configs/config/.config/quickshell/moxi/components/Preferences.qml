pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

Scope {
	id: preferences
	readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
	readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/moxi-settings.py"
	readonly property string path: configHome + "/moxi/settings.json"
	property var definitions: []
	property var values: ({})
	property var overrides: ({})
	property var wallpapers: ({})
	property string error: ""
	property string saveError: ""
	property string applyError: ""
	property string message: ""
	property bool ready: false
	property var pending: []
	readonly property bool saving: writer.running || restorer.running || pending.length > 0
	readonly property bool applying: apply.running || applyDelay.running
	readonly property bool restoring: restorer.running
	property bool hyprlandDirty: false
	readonly property bool reducedMotion: value("appearance.reducedMotion", false)
	readonly property real surfaceOpacity: value("appearance.shellOpacity", 1)
	signal refreshed

	function value(key, fallback) {
		return values[key] === undefined ? fallback : values[key]
	}
	function opacity(original) {
		return Math.min(1, Math.max(0, original * surfaceOpacity))
	}
	function motion(duration) {
		return reducedMotion ? 0 : duration
	}
	function definition(key) {
		return definitions.find(item => item.key === key)
	}
	function premium(path, key, fallback) {
		const stored = wallpapers[path] || {}
		return stored[key] === undefined ? fallback : stored[key]
	}
	function accept(raw) {
		try {
			const data = JSON.parse(raw)
			if (JSON.stringify(values) !== JSON.stringify(data.values))
				values = data.values
			if (JSON.stringify(overrides) !== JSON.stringify(data.overrides))
				overrides = data.overrides
			if (JSON.stringify(wallpapers) !== JSON.stringify(data.wallpapers))
				wallpapers = data.wallpapers
			ready = true
			error = ""
			watched.path = ""
			watched.path = preferences.path
			refreshed()
		} catch (problem) {
			error = "Could not read preferences: " + problem
		}
	}
	function refresh() {
		if (reader.running || writer.running || restorer.running) {
			refreshDelay.restart()
			return
		}
		reader.running = true
	}
	function set(key, next, wallpaper) {
		message = ""
		const item = {
			key: key,
			value: next,
			wallpaper: wallpaper || ""
		}
		pending = pending.filter(old => old.key !== key || old.wallpaper !== item.wallpaper).concat([item])
		writeDelay.restart()
	}
	function reset(key, wallpaper) {
		set(key, null, wallpaper)
	}
	function resetCategory(category, wallpaper) {
		restoreDefaults(category)
	}
	function restoreDefaults(category) {
		if (saving || applying || !ready)
			return
		saveError = ""
		message = ""
		restorer.command = ["python3", helper, "restore", JSON.stringify({
				category: category || null,
				expected: {
					values: overrides,
					wallpapers: wallpapers
				}
			})]
		restorer.running = true
	}
	function writeNext() {
		if (writer.running || restorer.running || reader.running || pending.length === 0) {
			if (pending.length)
				writeDelay.restart()
			return
		}
		const item = pending[0]
		pending = pending.slice(1)
		const expected = item.wallpaper ? (wallpapers[item.wallpaper] || {})[item.key] : value(item.key, definition(item.key).default)
		const request = {
			changes: {},
			expected: {},
			wallpaper: item.wallpaper
		}
		request.changes[item.key] = item.value
		request.expected[item.key] = expected === undefined ? null : expected
		writer.command = ["python3", helper, "patch", JSON.stringify(request)]
		writer.compositorChange = definition(item.key).apply === "hyprland"
		writer.running = true
	}
	function applyHyprland() {
		if (!apply.running && !saving) {
			hyprlandDirty = false
			apply.running = true
		} else
			applyDelay.restart()
	}

	FileView {
		id: schema
		path: Qt.resolvedUrl("../settings/schema.json")
		blockLoading: true
	}
	FileView {
		id: watched
		path: preferences.path
		watchChanges: true
		printErrors: false
		onFileChanged: {
			reload()
			refreshDelay.restart()
		}
	}
	FolderListModel {
		folder: "file://" + preferences.configHome + "/moxi"
		showDirs: false
		nameFilters: ["settings.json"]
		onCountChanged: refreshDelay.restart()
	}
	Component.onCompleted: {
		try {
			definitions = JSON.parse(schema.text()).settings
			const initial = {}
			for (const item of definitions)
				initial[item.key] = item.default
			values = initial
		} catch (problem) {
			error = "Preferences schema is unavailable: " + problem
		}
		refresh()
	}
	Timer {
		id: applyDelay
		interval: 300
		onTriggered: preferences.applyHyprland()
	}
	Timer {
		id: refreshDelay
		interval: 100
		onTriggered: preferences.refresh()
	}
	Timer {
		id: writeDelay
		interval: 120
		onTriggered: preferences.writeNext()
	}
	Process {
		id: reader
		command: ["python3", preferences.helper, "read"]
		stdout: StdioCollector {
			id: readOutput
		}
		stderr: StdioCollector {
			id: readError
		}
		onExited: (code, status) => {
			if (code === 0)
				preferences.accept(readOutput.text)
			else {
				preferences.error = readError.text.trim()
				preferences.ready = true
			}
			preferences.writeNext()
		}
	}
	Process {
		id: writer
		property bool compositorChange: false
		stdout: StdioCollector {
			id: writeOutput
		}
		stderr: StdioCollector {
			id: writeError
		}
		onExited: (code, status) => {
			if (code === 0) {
				preferences.saveError = ""
				preferences.accept(writeOutput.text)
				if (compositorChange)
					preferences.hyprlandDirty = true
			} else {
				preferences.saveError = writeError.text.trim()
				preferences.pending = []
				refreshDelay.restart()
			}
			preferences.writeNext()
			if (preferences.hyprlandDirty)
				applyDelay.restart()
		}
	}
	Process {
		id: restorer
		stdout: StdioCollector {
			id: restoreOutput
		}
		stderr: StdioCollector {
			id: restoreError
		}
		onExited: (code, status) => {
			if (code === 0) {
				preferences.accept(restoreOutput.text)
				preferences.message = "defaults restored!"
				if (JSON.parse(restoreOutput.text).applyHyprland)
					applyDelay.restart()
			} else {
				preferences.saveError = restoreError.text.trim()
				refreshDelay.restart()
			}
			preferences.writeNext()
		}
	}
	Process {
		id: apply
		command: ["python3", preferences.helper, "apply"]
		stdout: StdioCollector {
			id: applyOutput
		}
		stderr: StdioCollector {
			id: applyStderr
		}
		onExited: (code, status) => {
			if (code === 0) {
				preferences.applyError = ""
				preferences.message = applyOutput.text.trim()
			} else
				preferences.applyError = applyStderr.text.trim()
		}
	}
}
