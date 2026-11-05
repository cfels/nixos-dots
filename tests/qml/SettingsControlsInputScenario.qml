import Quickshell
import Quickshell.Io
import QtQuick
import "moxi/panel"
import "moxi/settings"
import "moxi/components"

ShellRoot {
	WallpaperController {
		id: library
	}
	Window {
		id: testWindow
		visible: true
		width: 920
		height: 600
		SettingsContent {
			id: settings
			wallpaperLibrary: library
			anchors.fill: parent
		}
	}
	function find(item, name) {
		if (item.objectName === name || item.text === name)
			return item
		for (const child of item.children || []) {
			const found = find(child, name)
			if (found)
				return found
		}
		return null
	}
	IpcHandler {
		target: "inspect"
		function page(name: string): void {
			settings.selectCategory(name)
		}
		function state(): string {
			return JSON.stringify({
				y: settings.testScroll.contentY,
				maximumY: Math.max(0, settings.testScroll.contentHeight - settings.testScroll.height),
				values: Preferences.values,
				saving: Preferences.saving,
				applying: Preferences.applying,
				dirty: Preferences.hyprlandDirty,
				error: Preferences.saveError || Preferences.applyError || Preferences.error
			})
		}
		function point(name: string): string {
			const item = find(testWindow.contentItem, name)
			if (!item)
				return JSON.stringify({
					error: "Missing control " + name
				})
			const point = item.mapToItem(null, item.width / 2, item.height / 2)
			return JSON.stringify({
				x: point.x,
				y: point.y,
				checked: item.checked
			})
		}
	}
	Timer {
		interval: 700
		running: true
		onTriggered: console.info("INPUT_READY")
	}
}
