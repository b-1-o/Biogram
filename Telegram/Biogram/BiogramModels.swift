import Foundation

public struct BiogramCollectible: Codable, Equatable {
    public let id: String
    public var title: String?
    public var author: String?
    public var assetFilename: String
    public var assetType: String
    public var createdAt: Date
    /// Telegram gift slug / emoji key if from catalog
    public var giftSlug: String?

    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        author: String? = nil,
        assetFilename: String,
        assetType: String,
        createdAt: Date = Date(),
        giftSlug: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.assetFilename = assetFilename
        self.assetType = assetType
        self.createdAt = createdAt
        self.giftSlug = giftSlug
    }
}

public struct BiogramVirtualNumber: Codable, Equatable {
    public let id: String
    public var label: String?
    public var number: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        label: String? = nil,
        number: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.number = number
        self.createdAt = createdAt
    }
}

public struct BiogramProfileColor: Codable, Equatable {
    /// 0...1 RGB
    public var r: Double
    public var g: Double
    public var b: Double
    /// 0...1 brightness multiplier
    public var brightness: Double

    public init(r: Double, g: Double, b: Double, brightness: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.brightness = brightness
    }

    public static let presets: [(String, BiogramProfileColor)] = [
        ("Blue", BiogramProfileColor(r: 0.25, g: 0.55, b: 0.95)),
        ("Dark Red", BiogramProfileColor(r: 0.55, g: 0.08, b: 0.12)),
        ("Purple", BiogramProfileColor(r: 0.55, g: 0.25, b: 0.85)),
        ("Green", BiogramProfileColor(r: 0.15, g: 0.65, b: 0.40)),
        ("Orange", BiogramProfileColor(r: 0.95, g: 0.45, b: 0.15)),
        ("Teal", BiogramProfileColor(r: 0.10, g: 0.70, b: 0.70)),
        ("Pink", BiogramProfileColor(r: 0.90, g: 0.30, b: 0.55)),
        ("Gray", BiogramProfileColor(r: 0.45, g: 0.45, b: 0.50)),
    ]
}

public struct BiogramCustomizations: Codable, Equatable {
    public var localPremiumEnabled: Bool
    public var showPremiumBadge: Bool
    public var badgeStyle: String?
    public var localAliases: [String]
    public var profileColor: BiogramProfileColor?
    public var profileColorEnabled: Bool

    public init(
        localPremiumEnabled: Bool = false,
        showPremiumBadge: Bool = true,
        badgeStyle: String? = "stars",
        localAliases: [String] = [],
        profileColor: BiogramProfileColor? = nil,
        profileColorEnabled: Bool = false
    ) {
        self.localPremiumEnabled = localPremiumEnabled
        self.showPremiumBadge = showPremiumBadge
        self.badgeStyle = badgeStyle
        self.localAliases = localAliases
        self.profileColor = profileColor
        self.profileColorEnabled = profileColorEnabled
    }
}

/// Каталог «как TG gifts» — локальные названия, без сервера
public enum BiogramGiftCatalog {
    public static let items: [(slug: String, title: String)] = [
        ("delicious_cake", "Delicious Cake"),
        ("green_star", "Green Star"),
        ("blue_star", "Blue Star"),
        ("red_star", "Red Star"),
        ("gift_box", "Gift Box"),
        ("diamond", "Diamond"),
        ("trophy", "Trophy"),
        ("rocket", "Rocket"),
        ("heart", "Heart"),
        ("bear", "Bear"),
        ("flower", "Flower"),
        ("champagne", "Champagne"),
        ("lol_pop", "Lol Pop"),
        ("hypno_lollipop", "Hypno Lollipop"),
        ("eternal_rose", "Eternal Rose"),
        ("precious_peach", "Precious Peach"),
        ("spiced_wine", "Spiced Wine"),
        ("jelly_bunny", "Jelly Bunny"),
        ("durovs_cap", "Durov's Cap"),
        ("swiss_watch", "Swiss Watch"),
    ]
}
