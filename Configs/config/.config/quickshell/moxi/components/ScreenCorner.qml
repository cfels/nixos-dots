import QtQuick
import QtQuick.Shapes

Shape {
	id: corner
	preferredRendererType: Shape.CurveRenderer
	ShapePath {
		fillColor: "black"
		strokeColor: "transparent"
		strokeWidth: 0
		startX: 0
		startY: 0
		PathLine {
			x: corner.width
			y: 0
		}
		PathCubic {
			x: 0
			y: corner.height
			control1X: corner.width * 0.447715
			control1Y: 0
			control2X: 0
			control2Y: corner.height * 0.447715
		}
		PathLine {
			x: 0
			y: 0
		}
	}
}
