import QtQuick

Item {
	id: marquee

	property string text: ""
	property color color: "#cdd6f4"
	property string fontFamily: ""
	property int pixelSize: 13
	property int fontWeight: Font.Normal
	property int gap: 44
	property bool scroll: label.implicitWidth > marquee.width + 2

	clip: true
	implicitHeight: label.implicitHeight

	Row {
		id: contentRow

		y: (marquee.height - height) / 2
		spacing: marquee.gap

		Text {
			id: label

			text: marquee.text
			color: marquee.color
			font.family: marquee.fontFamily
			font.pixelSize: marquee.pixelSize
			font.weight: marquee.fontWeight
			wrapMode: Text.NoWrap
		}

		Text {
			visible: marquee.scroll
			text: marquee.text
			color: marquee.color
			font.family: marquee.fontFamily
			font.pixelSize: marquee.pixelSize
			font.weight: marquee.fontWeight
			wrapMode: Text.NoWrap
		}
	}

	Binding {
		target: contentRow
		property: "x"
		value: Math.max(0, (marquee.width - contentRow.width) / 2)
		when: !marquee.scroll
		restoreMode: Binding.RestoreNone
	}

	onScrollChanged: {
		if (!marquee.scroll) contentRow.x = Math.max(0, (marquee.width - contentRow.width) / 2)
	}

	SequentialAnimation {
		running: marquee.scroll && marquee.visible
		loops: Animation.Infinite

		PauseAnimation { duration: 1500 }

		NumberAnimation {
			target: contentRow
			property: "x"
			from: 0
			to: -(label.implicitWidth + marquee.gap)
			duration: Math.max(1800, label.implicitWidth * 24)
			easing.type: Easing.Linear
		}
	}

	onWidthChanged: if (!marquee.scroll) contentRow.x = Math.max(0, (marquee.width - contentRow.width) / 2)
}
