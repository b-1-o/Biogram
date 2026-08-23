import UIKit

public enum BiogramPatternImage {
    
    /// Создаёт тайловую картинку паттерна (как на скринах)
    public static func make(
        pattern: String,
        color: UIColor,
        opacity: CGFloat,
        tileSize: CGFloat = 48
    ) -> UIImage? {
        guard pattern != "none" else {
            return nil
        }
        
        let size = CGSize(width: tileSize, height: tileSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let tile = renderer.image { _ in
            // Символ паттерна
            let symbol: String
            
            switch pattern {
            case "skulls":
                symbol = "𐕣"
            case "pentagrams":
                symbol = "⛧"
            case "stars":
                symbol = "♱"
            default:
                symbol = ""
            }
            
            guard !symbol.isEmpty else {
                return
            }
            
            let font = UIFont.systemFont(ofSize: tileSize * 0.45)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color.withAlphaComponent(opacity)
            ]
            
            let text = symbol as NSString
            let textSize = text.size(withAttributes: attrs)
            
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            
            text.draw(at: point, withAttributes: attrs)
        }
        
        // Делаем повторяющийся паттерн
        return tile.resizableImage(
            withCapInsets: .zero,
            resizingMode: .tile
        )
    }
    
    /// UIColor из BiogramProfileColor
    public static func uiColor(
        from profileColor: BiogramProfileColor
    ) -> UIColor {
        let b = max(
            0.1,
            min(1.5, profileColor.brightness)
        )
        
        return UIColor(
            red: CGFloat(profileColor.r * b),
            green: CGFloat(profileColor.g * b),
            blue: CGFloat(profileColor.b * b),
            alpha: 1.0
        )
    }
}
