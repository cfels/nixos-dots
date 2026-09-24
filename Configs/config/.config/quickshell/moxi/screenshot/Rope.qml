import QtQuick
import QtQuick.Shapes

Item {
	id: ropeRect

	property color color: "#cba6f7"

	property int anchorX: 0
	property int anchorY: 0

	property int pullX: 100
	property int pullY: 100

	property int segments: 16
	readonly property real span: Math.sqrt(Math.pow(ropeRect.pullX - ropeRect.anchorX, 2) + Math.pow(ropeRect.pullY - ropeRect.anchorY, 2))
	readonly property real slack: 1.45
	readonly property int segment_length: Math.max(6, Math.round(ropeRect.span * ropeRect.slack / ropeRect.segments))

	anchors.fill: parent

	Shape {
		id: dots

		width: parent.width
		height: parent.height
		anchors.centerIn: parent
	}

	Shape {
		id: rope

		width: parent.width
		height: parent.height
		anchors.centerIn: parent
		preferredRendererType: Shape.CurveRenderer

		Instantiator {
			model: ropeRect.segments

			onObjectAdded: (index, pathCurve) => {
				pathCurves.pathElements.push(pathCurve)
			}

			delegate: PathCurve {
				property int index: model.index

				x: 500
				y: 500
			}
		}

		ShapePath {
			id: pathCurves

			strokeColor: ropeRect.color
			fillColor: "transparent"
			strokeWidth: 6
			startX: ropeRect.anchorX
			startY: ropeRect.anchorY
		}

		ShapePath {
			id: dotPath

			strokeColor: "transparent"
			fillColor: "transparent"

			PathAngleArc {
				id: startPoint

				property int index: -1
				property double dx: 0
				property double dy: 0
				property double vx: 0
				property double vy: 0

				onCenterXChanged: {
					pathCurves.startX = centerX
				}

				onCenterYChanged: {
					pathCurves.startY = centerY
				}

				centerX: ropeRect.anchorX
				centerY: ropeRect.anchorY
				radiusX: 3
				radiusY: 3
				startAngle: 0
				sweepAngle: 360
			}
		}

		Timer {
			interval: 1000 / 60
			running: true
			repeat: true

			onTriggered: {
				for (var i = ropeRect.segments; i > 0; i--) {
					var point = dotPath.pathElements[i]
					var prev = dotPath.pathElements[i - 1]

					if (!point || !prev) continue

					var prevDx = prev.centerX - point.centerX
					var prevDy = prev.centerY - point.centerY

					var prevDist = Math.sqrt(Math.pow(prevDx, 2) + Math.pow(prevDy, 2))
					var prevExtend = prevDist - ropeRect.segment_length

					var vx = (prevDx / prevDist) * prevExtend
					var vy = (prevDy / prevDist) * prevExtend + 9.8

					if (isNaN(vx)) {
						vx = 0
					}

					if (isNaN(vy)) {
						vy = 0
					}

					if (i < ropeRect.segments - 3) {
						var next = dotPath.pathElements[i + 1]

						if (!next) continue

						var nextDx = next.centerX - point.centerX
						var nextDy = next.centerY - point.centerY

						var nextDist = Math.sqrt(Math.pow(nextDx, 2) + Math.pow(nextDy, 2))
						var nextExtend = nextDist - ropeRect.segment_length

						vx += (nextDx / nextDist) * nextExtend
						vy += (nextDy / nextDist) * nextExtend
					} else {
						point.centerX = ropeRect.pullX
						point.centerY = ropeRect.pullY
					}

					point.vx = point.vx * 0.5 + vx * 0.45
					point.vy = point.vy * 0.5 + vy * 0.45

					point.centerX += point.vx
					point.centerY += point.vy
				}
			}
		}

		Instantiator {
			model: ropeRect.segments

			onObjectAdded: (index, pathCurve) => {
				dotPath.pathElements.push(pathCurve)
			}

			delegate: PathAngleArc {
				id: points

				property int index: model.index
				property double dx: 0
				property double dy: 0
				property double vx: 0
				property double vy: 0

				onCenterXChanged: {
					if (pathCurves.pathElements[index]) pathCurves.pathElements[index].x = centerX
				}

				onCenterYChanged: {
					if (pathCurves.pathElements[index]) pathCurves.pathElements[index].y = centerY
				}

				Component.onCompleted: {
					if (pathCurves.pathElements[index]) {
						pathCurves.pathElements[index].x = centerX
						pathCurves.pathElements[index].y = centerY
					}
				}

				centerX: anchorX + index
				centerY: anchorY + index
				radiusX: 1
				radiusY: 1
				startAngle: 0
				sweepAngle: 360
			}
		}
	}
}
