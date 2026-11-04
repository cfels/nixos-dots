import Quickshell
import QtQuick
import "moxi/panel"
import "moxi/settings"

ShellRoot {
	Window {
		visible: true
		width: 920
		height: 640
		PanelPager {
			id: pager
			anchors.fill: parent
			panelExpanded: true
			onSettingsOpenChanged: console.info("INPUT_PAGE", settingsOpen ? "settings" : "panel")
			settingsComponent: Item {
				function swipeCategory(direction) { return false }
				SettingsSlider {
					x: 100
					y: 100
					width: 500
					from: 0
					to: 100
					value: 20
					onMoved: if (value > 70)
						console.info("INPUT_SLIDER_OK")
				}
				Flickable {
					x: 600
					y: 100
					width: 200
					height: 300
					contentHeight: 1200
					onContentYChanged: if (contentY > 50)
						console.info("INPUT_SCROLL_OK")
				}
			}
		}
	}
	Timer {
		interval: 700
		running: true
		onTriggered: console.info("INPUT_READY")
	}
}
