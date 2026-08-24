import UIKit

public enum BiogramPatternImage {
    /// Creates a dense Telegram-style pattern distributed across the
    /// entire canvas, with a transparent area around the avatar center.
    public static func make(
        pattern: String,
        color: UIColor,
        opacity: CGFloat,
        canvasSize: CGSize = CGSize(width: 420.0, height: 420.0)
    ) -> UIImage? {
        guard pattern != "none",
              canvasSize.width > 0.0,
              canvasSize.height > 0.0 else {
            return nil
        }

        let symbol: String

        switch pattern {
        case "skulls":
            symbol = "𐕣"
        case "pentagrams":
            symbol = "⛧"
        case "stars":
            symbol = "✦"
        default:
            return nil
        }

        let clampedOpacity = max(
            0.0,
            min(1.0, opacity)
        )

        guard clampedOpacity > 0.0 else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        return UIGraphicsImageRenderer(
            size: canvasSize,
            format: format
        ).image { rendererContext in
            let context = rendererContext.cgContext

            let minDimension = min(
                canvasSize.width,
                canvasSize.height
            )

            // Pattern scales with the actual cover size.
            let symbolSize = max(
                16.0,
                min(34.0, minDimension * 0.075)
            )

            let horizontalSpacing = symbolSize * 2.25
            let verticalSpacing = symbolSize * 1.95

            let font = UIFont.systemFont(
                ofSize: symbolSize,
                weight: .regular
            )

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color.withAlphaComponent(
                    clampedOpacity
                )
            ]

            let text = symbol as NSString
            let textSize = text.size(
                withAttributes: attributes
            )

            // Keep a clear area around the avatar.
            // It is intentionally a circle instead of a square, so the
            // pattern does not create the "square around avatar" effect.
            let avatarCenter = CGPoint(
                x: canvasSize.width * 0.5,
                y: canvasSize.height * 0.5
            )

            let avatarClearRadius = max(
                58.0,
                minDimension * 0.17
            )

            // Deterministic pseudo-random helper.
            // This keeps the pattern stable between renders.
            func variation(
                x: Int,
                y: Int
            ) -> CGFloat {
                let value =
                    sin(
                        Double(x * 127 + y * 311)
                    ) * 43758.5453

                return CGFloat(
                    value - floor(value)
                )
            }

            let startY = -verticalSpacing
            let endY = canvasSize.height + verticalSpacing
            let startX = -horizontalSpacing
            let endX = canvasSize.width + horizontalSpacing

            var row = 0

            var y = startY

            while y <= endY {
                let rowOffset =
                    row % 2 == 0
                    ? 0.0
                    : horizontalSpacing * 0.5

                var column = 0
                var x = startX + rowOffset

                while x <= endX {
                    let point = CGPoint(
                        x: x,
                        y: y
                    )

                    let dx = point.x - avatarCenter.x
                    let dy = point.y - avatarCenter.y

                    let distance = sqrt(
                        dx * dx +
                        dy * dy
                    )

                    // Don't draw inside the avatar protection circle.
                    if distance > avatarClearRadius {
                        let jitterX =
                            (variation(x: column, y: row) - 0.5)
                            * symbolSize
                            * 0.28

                        let jitterY =
                            (variation(x: column + 71, y: row + 17) - 0.5)
                            * symbolSize
                            * 0.22

                        let finalPoint = CGPoint(
                            x: point.x + jitterX,
                            y: point.y + jitterY
                        )

                        let rotation =
                            (variation(
                                x: column + 19,
                                y: row + 53
                            ) - 0.5) * 0.18

                        context.saveGState()

                        context.translateBy(
                            x: finalPoint.x,
                            y: finalPoint.y
                        )

                        context.rotate(
                            by: rotation
                        )

                        // Small deterministic size variation gives it
                        // the organic Telegram-like feel.
                        let scale =
                            0.82 +
                            variation(
                                x: column + 37,
                                y: row + 101
                            ) * 0.34

                        context.scaleBy(
                            x: scale,
                            y: scale
                        )

                        text.draw(
                            at: CGPoint(
                                x: -textSize.width * 0.5,
                                y: -textSize.height * 0.5
                            ),
                            withAttributes: attributes
                        )

                        context.restoreGState()
                    }

                    column += 1
                    x += horizontalSpacing
                }

                row += 1
                y += verticalSpacing
            }
        }
    }

    public static func uiColor(
        from profileColor: BiogramProfileColor
    ) -> UIColor {
        let brightness = max(
            0.1,
            min(1.5, profileColor.brightness)
        )

        return UIColor(
            red: CGFloat(
                max(
                    0.0,
                    min(
                        1.0,
                        profileColor.r * brightness
                    )
                )
            ),
            green: CGFloat(
                max(
                    0.0,
                    min(
                        1.0,
                        profileColor.g * brightness
                    )
                )
            ),
            blue: CGFloat(
                max(
                    0.0,
                    min(
                        1.0,
                        profileColor.b * brightness
                    )
                )
            ),
            alpha: 1.0
        )
    }
}
