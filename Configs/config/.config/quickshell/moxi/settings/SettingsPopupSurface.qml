import Quickshell
import QtQuick
import QtQuick.Effects
import "../components"

Item {
	id: surface
	property Item sourceItem: null
	property bool opened: false
	property real radius: 18
	property rect captureRect: Qt.rect(0, 0, 0, 0)
	readonly property bool blurEnabled: opened && Preferences.value("appearance.blur", true)
	function updateCaptureRect(): void {
		if (!opened || !sourceItem)
			return
		const top = surface.mapToItem(sourceItem, 0, 0)
		const bottom = surface.mapToItem(sourceItem, width, height)
		captureRect = Qt.rect(top.x, top.y, bottom.x - top.x, bottom.y - top.y)
	}
	onOpenedChanged: if (opened)
		Qt.callLater(updateCaptureRect)
	onSourceItemChanged: Qt.callLater(updateCaptureRect)

	TransformWatcher {
		a: surface.opened ? surface.sourceItem : null
		b: surface.opened ? surface : null
		onTransformChanged: surface.updateCaptureRect()
	}
	ShaderEffectSource {
		id: backdrop
		anchors.fill: parent
		visible: false
		live: surface.blurEnabled
		sourceItem: surface.blurEnabled ? surface.sourceItem : null
		sourceRect: surface.captureRect
	}
	Squircle {
		id: mask
		anchors.fill: parent
		visible: false
		layer.enabled: surface.blurEnabled
		radius: surface.radius
		power: 4
		fillColor: "white"
	}
	MultiEffect {
		anchors.fill: parent
		visible: surface.blurEnabled && surface.sourceItem !== null
		source: backdrop
		blurEnabled: true
		blurMax: 20
		blur: 0.65
		maskEnabled: true
		maskSource: mask
		autoPaddingEnabled: false
	}
	Squircle {
		anchors.fill: parent
		radius: surface.radius
		power: 4
		fillColor: Qt.rgba(SettingsStyle.theme.background.r, SettingsStyle.theme.background.g, SettingsStyle.theme.background.b, Preferences.opacity(0.78))
		strokeColor: Qt.rgba(SettingsStyle.theme.foreground.r, SettingsStyle.theme.foreground.g, SettingsStyle.theme.foreground.b, 0.12)
		strokeWidth: 1
	}
}
