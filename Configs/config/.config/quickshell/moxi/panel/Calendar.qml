import QtQuick
import QtQuick.Effects
import "../components"

Item {
	id: calendar

	Theme {
		id: theme
	}

	property color accent: "#cba6f7"
	property color foreground: "#cdd6f4"
	property color muted: "#7f849c"
	property color idle: "#45475a"
	property string fontFamily: ""

	property int viewYear: new Date().getFullYear()
	property int viewMonth: new Date().getMonth()
	property int pendingShift: 0
	property int slideDirection: 1
	property real gridBlur: 0

	property int selectedYear: 0
	property int selectedMonth: 0
	property int selectedDay: 0

	signal selected()

	readonly property date today: new Date()
	readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
	readonly property int offset: (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
	readonly property bool hasSelection: selectedDay > 0
	readonly property date selectedDate: new Date(selectedYear, selectedMonth, selectedDay)
	readonly property string selectionLabel: hasSelection
		? Qt.formatDate(selectedDate, "ddd, d MMM yyyy")
		: "no date selected"

	readonly property real headerHeight: 28
	readonly property real weekdaysHeight: 20
	readonly property real footerHeight: 22
	readonly property real rows: 6
	readonly property real gap: 2
	readonly property real cellWidth: Math.floor((width - gap * 6) / 7)
	readonly property real cellHeight: Math.min(
		cellWidth + gap,
		Math.floor((height - headerHeight - weekdaysHeight - footerHeight - 22 - gap * 5) / rows)
	)
	readonly property real gridWidth: cellWidth * 7 + gap * 6

	readonly property var monthNames: [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

	function shift(months): void {
		if (sliding.running) return

		calendar.pendingShift = months
		calendar.slideDirection = months > 0 ? 1 : -1
		sliding.restart()
	}

	function applyShift(): void {
		var target = new Date(calendar.viewYear, calendar.viewMonth + calendar.pendingShift, 1)

		calendar.viewYear = target.getFullYear()
		calendar.viewMonth = target.getMonth()
		calendar.pendingShift = 0
	}

	function isToday(day): bool {
		return calendar.today.getDate() === day
			&& calendar.today.getMonth() === calendar.viewMonth
			&& calendar.today.getFullYear() === calendar.viewYear
	}

	function isSelected(day): bool {
		return calendar.hasSelection
			&& calendar.selectedDay === day
			&& calendar.selectedMonth === calendar.viewMonth
			&& calendar.selectedYear === calendar.viewYear
	}

	function select(day): void {
		calendar.selectedYear = calendar.viewYear
		calendar.selectedMonth = calendar.viewMonth
		calendar.selectedDay = day
		calendar.selected()
	}

	function pick(day, inMonth): void {
		if (inMonth) {
			calendar.select(day)
			return
		}

		var target = new Date(calendar.viewYear, calendar.viewMonth, day)

		calendar.selectedYear = target.getFullYear()
		calendar.selectedMonth = target.getMonth()
		calendar.selectedDay = target.getDate()
		calendar.selected()
		calendar.shift(day < 1 ? -1 : 1)
	}

	Item {
		id: title

		anchors.top: parent.top
		anchors.left: parent.left
		anchors.right: parent.right
		height: calendar.headerHeight

		Text {
			anchors.verticalCenter: parent.verticalCenter
			anchors.left: parent.left
			color: calendar.foreground
			font.family: calendar.fontFamily
			font.pixelSize: 16
			font.weight: Font.DemiBold
			text: calendar.monthNames[calendar.viewMonth] + " " + calendar.viewYear
		}

		Row {
			anchors.verticalCenter: parent.verticalCenter
			anchors.right: parent.right
			spacing: 6

			Rectangle {
				width: 26
				height: 26
				radius: 13
				color: previous.containsMouse ? theme.idle : "transparent"

				Text {
					anchors.centerIn: parent
					color: calendar.foreground
					font.family: calendar.fontFamily
					font.pixelSize: 15
					text: "<"
				}

				MouseArea {
					id: previous

					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: calendar.shift(-1)
				}
			}

			Rectangle {
				width: 26
				height: 26
				radius: 13
				color: next.containsMouse ? theme.idle : "transparent"

				Text {
					anchors.centerIn: parent
					color: calendar.foreground
					font.family: calendar.fontFamily
					font.pixelSize: 15
					text: ">"
				}

				MouseArea {
					id: next

					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: calendar.shift(1)
				}
			}
		}
	}

	Row {
		id: weekdays

		anchors.top: title.bottom
		anchors.horizontalCenter: parent.horizontalCenter
		width: calendar.gridWidth
		height: calendar.weekdaysHeight
		spacing: calendar.gap

		Repeater {
			model: calendar.dayNames

			delegate: Item {
				required property var modelData

				width: calendar.cellWidth
				height: calendar.weekdaysHeight

				Text {
					anchors.centerIn: parent
					color: calendar.muted
					font.family: calendar.fontFamily
					font.pixelSize: 11
					text: parent.modelData.substring(0, 2)
				}
			}
		}
	}

	Item {
		id: gridClip

		anchors.top: weekdays.bottom
		anchors.topMargin: 8
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: selectionLabel.top
		anchors.bottomMargin: 6
		clip: true

		Binding {
			target: gridLayer
			property: "x"
			value: (gridClip.width - gridLayer.width) / 2
			when: !sliding.running
			restoreMode: Binding.RestoreNone
		}

		Item {
			id: gridLayer

			width: calendar.gridWidth
			height: calendar.cellHeight * calendar.rows
			x: (gridClip.width - width) / 2
			anchors.verticalCenter: parent.verticalCenter
			visible: true
			transformOrigin: Item.Top
			layer.enabled: true

			transform: Rotation {
				id: flip

				origin.x: gridLayer.width / 2
				origin.y: 0
				axis { x: 1; y: 0; z: 0 }
				angle: 0
			}

			Grid {
				anchors.fill: parent
				columns: 7
				columnSpacing: calendar.gap
				rowSpacing: calendar.gap

				Repeater {
					model: 42

					delegate: Item {
						id: cell

						required property int index

						readonly property int day: index - calendar.offset + 1
						readonly property bool inMonth: day >= 1 && day <= calendar.daysInMonth
						readonly property bool today: cell.inMonth && calendar.isToday(cell.day)
						readonly property bool selected: cell.inMonth && calendar.isSelected(cell.day)

						width: calendar.cellWidth
						height: calendar.cellHeight

						Rectangle {
							id: dayCircle

							anchors.centerIn: parent
							width: Math.min(parent.width, parent.height) - 2
							height: width
							radius: width / 2
							color: cell.selected
								? calendar.accent
								: (hover.containsMouse && cell.inMonth
									? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
									: "transparent")
							border.width: cell.today && !cell.selected ? 1.2 : (cell.selected ? 1.6 : 0)
							border.color: calendar.accent

							Behavior on color {
								ColorAnimation { duration: 140 }
							}

							Text {
								anchors.centerIn: parent
								color: cell.selected
									? theme.background
									: cell.today
										? calendar.accent
										: cell.inMonth
											? calendar.foreground
											: calendar.idle
								font.family: calendar.fontFamily
								font.pixelSize: 12
								font.weight: cell.selected || cell.today ? Font.DemiBold : Font.Normal
								text: cell.inMonth ? cell.day : ""
							}

							MouseArea {
								id: hover

								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: calendar.pick(cell.day, cell.inMonth)
							}
						}
					}
				}
			}
		}
	}

	Text {
		id: selectionLabel

		anchors.bottom: parent.bottom
		anchors.left: parent.left
		color: calendar.hasSelection ? calendar.accent : calendar.idle
		font.family: calendar.fontFamily
		font.pixelSize: 12
		text: calendar.selectionLabel
	}

	SequentialAnimation {
		id: sliding

		ParallelAnimation {
			NumberAnimation {
				target: flip
				property: "angle"
				to: -90 * calendar.slideDirection
				duration: 230
				easing.type: Easing.InCubic
			}
			NumberAnimation {
				target: gridLayer
				property: "opacity"
				to: 0
				duration: 230
				easing.type: Easing.InCubic
			}
		}
		ScriptAction { script: calendar.applyShift() }
		PropertyAction {
			target: flip
			property: "angle"
			value: 90 * calendar.slideDirection
		}
		PropertyAction {
			target: gridLayer
			property: "opacity"
			value: 0
		}
		ParallelAnimation {
			NumberAnimation {
				target: flip
				property: "angle"
				to: 0
				duration: 320
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: gridLayer
				property: "opacity"
				to: 1
				duration: 260
				easing.type: Easing.OutCubic
			}
		}
	}
}
