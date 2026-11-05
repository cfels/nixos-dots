pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
	Variants {
		model: Preferences.value("appearance.screenCorners", true) ? Quickshell.screens : []
		Scope {
			id: monitor
			required property var modelData
			Variants {
				model: [0, 90, 180, 270]
				PanelWindow {
					id: cornerWindow
					required property int modelData
					screen: monitor.modelData
					implicitWidth: Preferences.value("appearance.screenCornerRadius", 24)
					implicitHeight: implicitWidth
					anchors {
						top: modelData === 0 || modelData === 90
						right: modelData === 90 || modelData === 180
						bottom: modelData === 180 || modelData === 270
						left: modelData === 270 || modelData === 0
					}
					color: "transparent"
					exclusionMode: ExclusionMode.Ignore
					mask: Region {}
					WlrLayershell.namespace: "moxi:screen-corners"
					WlrLayershell.layer: WlrLayer.Overlay
					WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
					ScreenCorner {
						anchors.fill: parent
						rotation: cornerWindow.modelData
					}
				}
			}
		}
	}
}
