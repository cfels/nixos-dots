pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "moxi/components"

ShellRoot {
	id: scenario
	property int step: 0
	property int ticks: 0
	QtObject {
		id: bar
		property string fontFamily: Fonts.family
		property bool textTransforming: false
		property real songSwipe: 0
		property real swipeBlur: 0
		property real titleWidth: 600
		property color foreground: "white"
		property color muted: "#aaaaaa"
	}
	QtObject {
		id: songInfo
		property real progress: 1
	}
	// SONG_LABEL_COMPONENT
	Window {
		visible: true
		width: 600
		height: 164
		color: "#181820"
		Item {
			id: frame
			anchors.fill: parent
			SongLabel {
				id: english
				x: 16
				y: 16
				title: "FIGHT! Aests"
			}
			SongLabel {
				id: russian
				x: 16
				y: 50
				title: "onokami — ангелочек"
			}
			SongLabel {
				id: japanese
				x: 16
				y: 84
				title: "シカ色デイズ Kqno"
			}
			SongLabel {
				id: korean
				x: 16
				y: 118
				title: "한글 한국어 사랑해요 Momo"
			}
		}
	}
	Timer {
		interval: 100
		running: true
		repeat: true
		onTriggered: {
			try {
				if (++scenario.ticks > 30)
					throw new Error("Text rendering timed out")
				const title = english.children.find(item => item.font !== undefined)
				if (scenario.step === 0) {
					if (!title || english.implicitWidth <= 0)
						return
					if (title.font.family !== Fonts.family || title.font.weight !== Font.Normal || title.renderType !== Text.NativeRendering)
						throw new Error("Settled title does not use native merged text")
					const russianTitle = russian.children.find(item => item.font !== undefined)
					const japaneseTitle = japanese.children.find(item => item.font !== undefined)
					const koreanTitle = korean.children.find(item => item.font !== undefined)
					if (Fonts.family !== "Moxi Trust" || title.fontInfo.family !== Fonts.family || russianTitle.text !== "onokami — ангелочек" || japaneseTitle.text !== "シカ色デイズ Kqno" || koreanTitle.text !== "한글 한국어 사랑해요 Momo")
						throw new Error("Merged font was not used for the complete text")
					if ([russianTitle, japaneseTitle, koreanTitle].some(item => item.fontInfo.family !== Fonts.family))
						throw new Error("Multilingual text selected an unrelated font")
					if (russianTitle.truncated || japaneseTitle.truncated || koreanTitle.truncated)
						throw new Error("Mixed text truncated despite ample space: " + JSON.stringify({
							ru: russianTitle.width,
							ruImplicit: russianTitle.implicitWidth,
							jp: japaneseTitle.width,
							jpImplicit: japaneseTitle.implicitWidth
						}))
					if (Fonts.styled("<b>я\u0301</b>") !== "&lt;b&gt;я\u0301&lt;/b&gt;")
						throw new Error("Font merging lost escaping or combining marks")
					english.moving = true
					scenario.step++
				} else if (scenario.step === 1) {
					if (title.renderType !== Text.QtRendering)
						throw new Error("Moving title uses a scaled bitmap")
					english.moving = false
					scenario.step++
				} else if (scenario.step === 2) {
					if (title.renderType !== Text.NativeRendering)
						throw new Error("Title did not restore native rendering")
					scenario.step++
					frame.grabToImage(result => {
						result.saveToFile("/work/panel-bar-text.png")
						console.info("PANEL_SCENARIO_OK")
						Qt.quit()
					})
				}
			} catch (error) {
				console.error("PANEL_SCENARIO_FAILED", error)
				Qt.quit()
			}
		}
	}
}
