import Foundation

public struct BiogramCollectible: Codable, Equatable {
    public let id: String
    public var title: String?
    public var author: String?
    public var assetFilename: String
    public var assetType: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, title: String? = nil, author: String? = nil, assetFilename: String, assetType: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.author = author
        self.assetFilename = assetFilename
        self.assetType = assetType
        self.createdAt = createdAt
    }
}

public struct BiogramVirtualNumber: Codable, Equatable {
    public let id: String
    public var label: String?
    public var number: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, label: String? = nil, number: String, createdAt: Date = Date()) {
        self.id = id
        self.label = label
        self.number = number
        self.createdAt = createdAt
    }
}

public struct BiogramCustomizations: Codable, Equatable {
    public var localPremiumEnabled: Bool
    public var showPremiumBadge: Bool
    public var badgeStyle: String?
    public var localAliases: [String]

    public init(localPremiumEnabled: Bool = false, showPremiumBadge: Bool = true, badgeStyle: String? = "stars", localAliases: [String] = []) {
        self.localPremiumEnabled = localPremiumEnabled
        self.showPremiumBadge = showPremiumBadge
        self.badgeStyle = badgeStyle
        self.localAliases = localAliases
    }
}
