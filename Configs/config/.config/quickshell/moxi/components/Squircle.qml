import QtQuick
import QtQuick.Shapes

Item {
	id: squircle

	property real radius: 24
	property real power: 4
	property int samples: 16
	property color fillColor: "transparent"
	property color strokeColor: "transparent"
	property real strokeWidth: 0

	readonly property string pathString: {
		var w = width
		var h = height
		var r = Math.min(radius, Math.min(w, h) / 2)
		var exponent = 2 / Math.max(2, power)
		var steps = Math.max(4, samples)
		var points = []

		function corner(cx, cy, from) {
			for (var i = 0; i <= steps; ++i) {
				var angle = (from + 90 * i / steps) * Math.PI / 180
				var ct = Math.cos(angle)
				var st = Math.sin(angle)

				points.push([
					cx + r * Math.sign(ct) * Math.pow(Math.abs(ct), exponent),
					cy + r * Math.sign(st) * Math.pow(Math.abs(st), exponent)
				])
			}
		}

		corner(r, r, 180)
		corner(w - r, r, 270)
		corner(w - r, h - r, 0)
		corner(r, h - r, 90)

		var path = "M " + points[0][0].toFixed(2) + " " + points[0][1].toFixed(2)

		for (var i = 1; i < points.length; ++i) {
			path += " L " + points[i][0].toFixed(2) + " " + points[i][1].toFixed(2)
		}

		return path + " Z"
	}

	Shape {
		anchors.fill: parent
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			fillColor: squircle.fillColor
			strokeColor: squircle.strokeColor
			strokeWidth: squircle.strokeWidth

			PathSvg { path: squircle.pathString }
		}
	}
}
