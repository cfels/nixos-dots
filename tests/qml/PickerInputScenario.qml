import Quickshell
import Quickshell.Io
import QtQuick
import "moxi/launcher"
import "moxi/emoji"

ShellRoot {
	id: scenario
	property string page: "apps"
	Window {
		visible: true
		width: 1000
		height: 740
		Item {
			id: appsHost
			x: 170
			y: 40
			width: 660
			height: 500
			visible: scenario.page === "apps"
		}
		Item {
			id: emojisHost
			x: 170
			y: 40
			width: 560
			height: 500
			visible: scenario.page === "emojis"
		}
		Launcher {
			id: launcher
			surfaceHost: appsHost
			open: true
		}
		Emoji {
			id: emoji
			surfaceHost: emojisHost
			open: true
		}
	}
	IpcHandler {
		target: "inspect"
		function page(name: string): void {
			scenario.page = name
		}
		function state(): string {
			const view = scenario.page === "apps" ? launcher.testView : emoji.testView
			return JSON.stringify({
				y: view.contentY,
				selected: view.currentIndex,
				highlightX: view.highlightItem.x,
				highlightY: view.highlightItem.y,
				itemX: view.currentItem.x,
				itemY: view.currentItem.y,
				height: view.height,
				contentHeight: view.contentHeight
			})
		}
	}
	Timer {
		interval: 600
		running: true
		onTriggered: {
			launcher.results = Array.from({
				length: 80
			}, (_, index) => ({
						name: "Приложение " + index,
						icon: "",
						id: "test-" + index
					}))
			emoji.results = Array.from({
				length: 200
			}, () => ["😀", "face"])
			console.info("INPUT_READY")
		}
	}
}
