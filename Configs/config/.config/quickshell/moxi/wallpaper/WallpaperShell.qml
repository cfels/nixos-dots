import Quickshell
import Quickshell.Io
import QtQuick
import "../components" as Shared

ShellRoot {
	id: root

	property string request: ""
	property string targetPath: ""
	property int corner: 0

	FileView {
		id: savedWallpaper
		path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
		blockLoading: true
		printErrors: false
	}

	Component.onCompleted: {
		const path = savedWallpaper.text().trim()
		if (path.length === 0)
			return
		root.targetPath = path
		for (let i = 0; i < outputs.instances.length; i++)
			outputs.instances[i].canvas.setWallpaper(path, root.corner)
	}

	Variants {
		id: outputs
		model: Quickshell.screens

		WallpaperOutput {
			required property var modelData
			screen: modelData
			outputName: modelData.name
			Component.onCompleted: {
				if (root.targetPath.length > 0)
					canvas.setWallpaper(root.targetPath, root.corner)
			}
		}
	}

	IpcHandler {
		target: "wallpaper"

		function ping(): string {
			return "ready"
		}

		function set(path: string, request: string): void {
			root.request = request
			root.targetPath = path
			const origin = Shared.Preferences.value("wallpaper.origin", "random")
			root.corner = origin === "random" ? Math.floor(Math.random() * 4) : ["top-left", "top-right", "bottom-left", "bottom-right"].indexOf(origin)
			for (let i = 0; i < outputs.instances.length; i++)
				outputs.instances[i].canvas.setWallpaper(path, root.corner)
		}

		function status(): string {
			let state = outputs.instances.length > 0 ? "ready" : "loading"
			let error = ""
			let details = []
			for (let i = 0; i < outputs.instances.length; i++) {
				const canvas = outputs.instances[i].canvas
				if (canvas.error.length > 0) {
					error = canvas.error
					state = "failed"
				} else if (state !== "failed" && (canvas.busy || canvas.currentPath !== root.targetPath)) {
					state = "loading"
				}
				details.push({
					path: canvas.currentPath,
					playbackState: canvas.current.playbackState,
					playbackError: canvas.current.playbackError,
					phase: canvas.phase,
					progress: canvas.progress,
					outgoingPosition: canvas.current.position,
					incomingPosition: canvas.incoming.position
				})
			}
			return JSON.stringify({
				request: root.request,
				state: state,
				error: error,
				corner: root.corner,
				outputs: details
			})
		}
	}
}
