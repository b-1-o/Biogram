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
    ("Black", BiogramProfileColor(r: 0.08, g: 0.08, b: 0.10)),
    ("White", BiogramProfileColor(r: 0.95, g: 0.95, b: 0.97)),
]

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

/// Каталог Telegram gifts — локальный выбор для профиля
public enum BiogramGiftCatalog {
    public struct Item: Equatable {
        public let slug: String
        public let title: String
        /// Когда появится — id стикера для отрисовки
        public let stickerFileId: Int64?
        
        public init(slug: String, title: String, stickerFileId: Int64? = nil) {
            self.slug = slug
            self.title = title
            self.stickerFileId = stickerFileId
        }
    }
    
    private static func slug(_ title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
    
    public static let items: [Item] = [
        "Heart Locket",
        "Plush Pepe",
        "Durov's Cap",
        "Precious Peach",
        "Heroic Helmet",
        "Mighty Arm",
        "Ion Gem",
        "Nail Bracelet",
        "Perfume Bottle",
        "Mini Oscar",
        "Magic Potion",
        "Astral Shard",
        "Gem Signet",
        "Genie Lamp",
        "Bonded Ring",
        "Sharp Tongue",
        "Electric Skull",
        "Westside Sign",
        "Kissed Frog",
        "Loot Bag",
        "Neko Helmet",
        "Signet Ring",
        "Sleigh Bell",
        "Mad Pumpkin",
        "Love Candle",
        "Scared Cat",
        "Skull Flower",
        "Low Rider",
        "Flying Broom",
        "Tama Gadget",
        "Snow Mittens",
        "Snow Globe",
        "Top Hat",
        "Swiss Watch",
        "Crystal Ball",
        "Love Potion",
        "Vintage Cigar",
        "Diamond Ring",
        "Hanging Star",
        "Eternal Candle",
        "Voodoo Doll",
        "Trapped Heart",
        "Record Player",
        "Hex Pot",
        "Toy Bear",
        "Eternal Rose",
        "Jack-in-the-Box",
        "Star Notepad",
        "Witch Hat",
        "Lunar Snake",
        "Winter Wreath",
        "Restless Jar",
        "Spiced Wine",
        "Santa Hat",
        "Holiday Drink",
        "Sakura Flower",
        "Berry Box",
        "Spy Agaric",
        "Bunny Muffin",
        "Hypno Lollipop",
        "B-Day Candle",
        "Evil Eye",
        "Jester Hat",
        "Big Year",
        "Easter Egg",
        "Jingle Bells",
        "Light Sword",
        "Cookie Heart",
        "Party Sparkler",
        "Ginger Cookie",
        "Snake Box",
        "Jelly Bunny",
        "Candy Cane",
        "Pet Snake",
        "Homemade Cake",
        "Bow Tie",
        "Lol Pop",
        "Desk Calendar",
        "Snoop Dogg",
        "Snoop Cigar",
        "Jolly Chimp",
        "Input Key",
        "Whip Cupcake",
        "Lush Bouquet",
        "Joyful Bundle",
        "Sky Stilettos",
        "Ionic Dryer",
        "Valentine Box",
        "Cupid Charm",
        "Instant Ramen",
        "Artisan Brick",
    ].map { title in
        Item(slug: slug(title), title: title)
    }
}
