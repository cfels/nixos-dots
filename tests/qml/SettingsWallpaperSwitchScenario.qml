import Quickshell
import Quickshell.Io
import QtQuick
import "panel"
import "settings"
import "components"

ShellRoot {
	id: scenario
	property int step: 0
	property int attempts: 0
	property int cycles: 0
	property double switchedAt: 0
	property var latencies: []
	property var originalPage: null
	property var originalManifest: null
	property bool sawHide: false
	property bool sawShow: false
	property bool initialSelectionRequested: false
	readonly property string premium: Quickshell.env("HOME") + "/walls/Velina.premiumwall.json"
	readonly property string normal: Quickshell.env("HOME") + "/walls/00-red.png"
	WallpaperController {
		id: library
		expanded: true
	}
	FileView {
		id: selected
		path: Quickshell.env("HOME") + "/.cache/current-wallpaper"
		atomicWrites: true
	}
	FileView {
		id: manifestFile
		path: scenario.premium
		blockLoading: true
		atomicWrites: true
	}
	Window {
		visible: true
		width: 920
		height: 600
		SettingsContent {
			id: subject
			anchors.fill: parent
			wallpaperLibrary: library
			category: "wallpaper"
		}
		WallpaperView {
			id: hiddenPicker
			width: 229
			height: 380
			visible: false
			active: false
			controller: library
			theme: SettingsStyle.theme
		}
	}
	function check(condition, message): void {
		if (!condition)
			throw new Error(message)
	}
	function choose(path): void {
		switchedAt = Date.now()
		selected.setText(path + "\n")
	}
	Timer {
		interval: 20
		running: true
		repeat: true
		onTriggered: {
			try {
				scenario.check(++scenario.attempts < 650, "Wallpaper switching timed out at step " + scenario.step)
				const page = subject.testWallpaper
				if (!Preferences.ready || Preferences.saving || !page)
					return
				const view = page.testView
				const options = page.testOptions
				if (options.reveal > 0 && options.reveal < 1) {
					if (page.premium)
						scenario.sawShow = true
					else
						scenario.sawHide = true
				}
				scenario.check(hiddenPicker.testPreview.source === "", "Hidden picker decoded the gallery's previews")
				if (scenario.step === 0) {
					if (!library.currentWallpaper && !scenario.initialSelectionRequested) {
						scenario.initialSelectionRequested = true
						scenario.choose(scenario.premium)
						return
					}
					if (!view.testPreview.ready || !view.testPreview.animated || options.reveal < 0.999 || !library.wallpaperThumb(scenario.normal))
						return
					scenario.check(library.currentWallpaper === scenario.premium && view.testGrid.currentIndex === 6, "Opening the gallery did not select the applied wallpaper")
					scenario.originalPage = page
					scenario.originalManifest = library.currentManifest
					scenario.choose(scenario.normal)
					scenario.step++
				} else if (scenario.step === 1) {
					if (library.currentWallpaper !== scenario.normal)
						return
					if (options.reveal > 0 && options.reveal < 1) {
						scenario.sawHide = true
						scenario.check(!options.enabled && page.optionsManifest.manifestPath, "Hiding options became interactive or lost their values")
					}
					if (!view.testPreview.ready || view.testPreview.animated || view.testPreview.source !== "file://" + library.wallpaperSource(scenario.normal))
						return
					scenario.latencies.push(Date.now() - scenario.switchedAt)
					scenario.check(view.testGrid.currentIndex === 0, "Selection did not follow an external wallpaper change")
					scenario.step++
				} else if (scenario.step === 2) {
					if (options.reveal !== 0)
						return
					scenario.check(scenario.sawHide && options.height < 1, "Premium options disappeared without a height transition: " + scenario.sawHide + ", " + options.height)
					scenario.choose(scenario.premium)
					scenario.step++
				} else if (scenario.step === 3) {
					if (options.reveal > 0 && options.reveal < 1)
						scenario.sawShow = true
					if (library.currentWallpaper !== scenario.premium || !view.testPreview.ready || !view.testPreview.animated)
						return
					scenario.latencies.push(Date.now() - scenario.switchedAt)
					scenario.check(library.currentManifest === scenario.originalManifest, "Switching back did not reuse cached manifest details")
					scenario.step++
				} else if (scenario.step === 4) {
					if (options.reveal < 0.999)
						return
					scenario.check(scenario.sawShow, "Premium options appeared without a transition")
					if (++scenario.cycles < 3) {
						scenario.choose(scenario.normal)
						scenario.step = 1
						return
					}
					subject.selectCategory("appearance")
					scenario.step++
				} else if (scenario.step === 5) {
					if (subject.transitioning)
						return
					scenario.check(page === scenario.originalPage && !view.active && !view.testPreview.testAnimation.playing, "Leaving Wallpapers discarded its cache or kept playback running")
					subject.selectCategory("wallpaper")
					scenario.step++
				} else if (scenario.step === 6) {
					if (subject.transitioning || !view.testPreview.ready)
						return
					scenario.check(page === scenario.originalPage && view.testGrid.currentIndex === 6, "Returning to Wallpapers lost the cached page or current selection")
					library.previewWallpaper = scenario.normal
					view.testFrame.showPreview()
					library.previewWallpaper = scenario.premium
					view.testFrame.showPreview()
					scenario.step = 9
				} else if (scenario.step === 9) {
					scenario.check(view.testPreview.animated && view.testPreview.source === "file://" + library.wallpaperSource(scenario.premium), "An old preview capture replaced the latest hover")
					const updated = JSON.parse(manifestFile.text())
					updated.openingEnabled = false
					manifestFile.setText(JSON.stringify(updated))
					scenario.step = 10
				} else if (scenario.step === 10) {
					if (!library.currentManifest.defaults || library.currentManifest.defaults.openingEnabled !== false)
						return
					scenario.check(page.optionsManifest.defaults.openingEnabled === false, "External edits did not refresh cached wallpaper options")
					Preferences.set("appearance.reducedMotion", true)
					scenario.step = 7
				} else if (scenario.step === 7) {
					if (!Preferences.reducedMotion)
						return
					scenario.choose(scenario.normal)
					scenario.step++
				} else {
					if (library.currentWallpaper !== scenario.normal)
						return
					scenario.check(options.reveal === 0 && !options.enabled, "Reduced motion retained an options animation")
					console.info("WALLPAPER_PREVIEW_LATENCY_MS", JSON.stringify(scenario.latencies))
					console.info("WALLPAPER_PICKER_OK")
					Qt.quit()
				}
			} catch (error) {
				console.error("PICKER_FAILED", error, error.stack)
				Qt.quit()
			}
		}
	}
}
