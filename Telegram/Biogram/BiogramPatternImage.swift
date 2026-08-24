import UIKit

public enum BiogramPatternImage {
    /// Creates a single transparent pattern artwork centered around an avatar.
    /// It intentionally does NOT use UIColor(patternImage:), so the symbols don't repeat in vertical stripes.
    public static func make(
        pattern: String,
        color: UIColor,
        opacity: CGFloat,
        canvasSize: CGSize = CGSize(width: 420, height: 420)
    ) -> UIImage? {
        guard pattern != "none", canvasSize.width > 0, canvasSize.height > 0 else {
            return nil
        }

        let symbol: String
        switch pattern {
        case "skulls":
            symbol = "𐕣"
        case "pentagrams":
            symbol = "⛧"
        case "stars":
            symbol = "♱"
        default:
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
            let minDimension = min(canvasSize.width, canvasSize.height)
            let baseRadius = minDimension * 0.33
            let fontSize = minDimension * 0.075
            let font = UIFont.systemFont(ofSize: fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color.withAlphaComponent(max(0.0, min(1.0, opacity)))
            ]

            let text = symbol as NSString
            let textSize = text.size(withAttributes: attributes)
            let rowCount = 3

            for row in 0 ..< rowCount {
                let radius = baseRadius + CGFloat(row) * minDimension * 0.075
                let count = 8 + row * 2
                let phase = CGFloat(row % 2) * .pi / CGFloat(count)

                for index in 0 ..< count {
                    let angle = (CGFloat(index) / CGFloat(count)) * 2.0 * .pi + phase
                    let point = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )
                    let drawPoint = CGPoint(
                        x: point.x - textSize.width * 0.5,
                        y: point.y - textSize.height * 0.5
                    )
                    text.draw(at: drawPoint, withAttributes: attributes)
                }
            }
        }
    }

    public static func uiColor(from profileColor: BiogramProfileColor) -> UIColor {
        let brightness = max(0.1, min(1.5, profileColor.brightness))
        return UIColor(
            red: CGFloat(max(0.0, min(1.0, profileColor.r * brightness))),
            green: CGFloat(max(0.0, min(1.0, profileColor.g * brightness))),
            blue: CGFloat(max(0.0, min(1.0, profileColor.b * brightness))),
            alpha: 1.0
        )
    }
}
