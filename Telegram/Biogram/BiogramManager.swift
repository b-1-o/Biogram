import Foundation
import UIKit

/// Singleton manager that exposes current Biogram state to the app.
/// All Biogram state is local-only and stored separately for every Telegram account.
public final class BiogramManager {
    public static let shared = BiogramManager()

    private let storage: BiogramStorage
    private let bannerIOQueue = DispatchQueue(label: "org.biogram.banner.io", qos: .utility)

    // All cache mutations are delivered on the main queue.
    private var currentAccountId: String = "default"
    private var switchGeneration: UInt64 = 0
    private var loadedAccountId: String?

    private var cachedCustomizations: BiogramCustomizations
    private var cachedAliases: [String]
    private var cachedVirtualNumbers: [BiogramVirtualNumber]
    private var cachedCollectibles: [BiogramCollectible]
    private var cachedBanner: BiogramBanner?
    private var cachedBannerImage: UIImage?

    private init(storageBase: URL? = nil) {
        self.storage = BiogramStorage(baseDirectory: storageBase)
        self.cachedCustomizations = BiogramCustomizations()
        self.cachedAliases = []
        self.cachedVirtualNumbers = []
        self.cachedCollectibles = []
        self.cachedBanner = nil
        self.cachedBannerImage = nil
    }

    // MARK: - Account

    /// Switch the local Biogram state to a Telegram account.
    /// The completion is called on the main queue only after JSON and banner image are loaded.
    public func switchToAccount(accountId: String, completion: (() -> Void)? = nil) {
        assert(Thread.isMainThread)

        if accountId == self.loadedAccountId {
            completion?()
            return
        }

        self.currentAccountId = accountId
        self.switchGeneration &+= 1
        let generation = self.switchGeneration

        self.storage.setCurrentAccountId(accountId)

        self.storage.load(for: accountId) { [weak self] payload in
            guard let self else { return }

            // Decode the image off the main thread. This is intentionally not done from the UI path.
            var bannerImage: UIImage?
            if let banner = payload.banner {
                let url = Self.bannersDirectory().appendingPathComponent(banner.localFilename)
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    bannerImage = image
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard generation == self.switchGeneration,
                      accountId == self.currentAccountId else {
                    return
                }

                self.cachedCustomizations = payload.customizations
                self.cachedAliases = payload.aliases
                self.cachedVirtualNumbers = payload.virtualNumbers
                self.cachedCollectibles = payload.collectibles
                self.cachedBanner = payload.banner
                self.cachedBannerImage = bannerImage
                self.loadedAccountId = accountId

                completion?()
            }
        }
    }

    // MARK: - Read accessors

    public var localPremiumEnabled: Bool {
        return self.cachedCustomizations.localPremiumEnabled
    }

    public func aliases() -> [String] {
        return self.cachedAliases
    }

    public func virtualNumbers() -> [BiogramVirtualNumber] {
        return self.cachedVirtualNumbers
    }

    public func collectibles() -> [BiogramCollectible] {
        return self.cachedCollectibles
    }

    public func banner() -> BiogramBanner? {
        return self.cachedBanner
    }

    public func bannerImage() -> UIImage? {
        return self.cachedBannerImage
    }

    public var bannerHeight: CGFloat {
        return CGFloat(self.cachedCustomizations.bannerHeight)
    }

    public var profileColorEnabled: Bool {
        return self.cachedCustomizations.profileColorEnabled
    }

    public var profileColor: BiogramProfileColor? {
        return self.cachedCustomizations.profileColor
    }

    // MARK: - Mutations

    public func setLocalPremiumEnabled(_ enabled: Bool, completion: (() -> Void)? = nil) {
        var custom = self.cachedCustomizations
        custom.localPremiumEnabled = enabled
        self.cachedCustomizations = custom
        self.storage.setCustomizations(custom, completion: completion)
    }

    public func addAlias(_ alias: String, completion: (() -> Void)? = nil) {
        if !self.cachedAliases.contains(alias) {
            self.cachedAliases.append(alias)
            self.storage.addAlias(alias, completion: completion)
        } else {
            completion?()
        }
    }

    public func removeAlias(_ alias: String, completion: (() -> Void)? = nil) {
        self.cachedAliases.removeAll(where: { $0 == alias })
        self.storage.removeAlias(alias, completion: completion)
    }

    public func addVirtualNumber(_ number: BiogramVirtualNumber, completion: (() -> Void)? = nil) {
        self.cachedVirtualNumbers.append(number)
        self.storage.addVirtualNumber(number, completion: completion)
    }

    public func removeVirtualNumber(id: String, completion: (() -> Void)? = nil) {
        self.cachedVirtualNumbers.removeAll(where: { $0.id == id })
        self.storage.removeVirtualNumber(id: id, completion: completion)
    }

    public func replaceAlias(old: String, new: String, completion: (() -> Void)? = nil) {
        if let index = self.cachedAliases.firstIndex(of: old) {
            self.cachedAliases[index] = new
            self.storage.replaceAliases(self.cachedAliases, completion: completion)
        } else {
            completion?()
        }
    }

    public func updateVirtualNumber(id: String, number: String, label: String?, completion: (() -> Void)? = nil) {
        if let index = self.cachedVirtualNumbers.firstIndex(where: { $0.id == id }) {
            self.cachedVirtualNumbers[index].number = number
            self.cachedVirtualNumbers[index].label = label
            self.storage.replaceVirtualNumbers(self.cachedVirtualNumbers, completion: completion)
        } else {
            completion?()
        }
    }

    public func setProfileColor(_ color: BiogramProfileColor?, enabled: Bool, completion: (() -> Void)? = nil) {
        var custom = self.cachedCustomizations
        custom.profileColor = color
        custom.profileColorEnabled = enabled
        self.cachedCustomizations = custom
        self.storage.setCustomizations(custom, completion: completion)
    }

    public func addCollectible(_ collectible: BiogramCollectible, completion: (() -> Void)? = nil) {
        self.cachedCollectibles.append(collectible)
        self.storage.addCollectible(collectible, completion: completion)
    }

    public func removeCollectible(id: String, completion: (() -> Void)? = nil) {
        self.cachedCollectibles.removeAll(where: { $0.id == id })
        self.storage.removeCollectible(id: id, completion: completion)
    }

    @discardableResult
    public func addCollectibleFromGiftLink(_ input: String, completion: (() -> Void)? = nil) -> Bool {
        guard let slug = BiogramGiftLink.slug(from: input) else {
            completion?()
            return false
        }
        guard !self.cachedCollectibles.contains(where: { $0.giftSlug == slug }) else {
            completion?()
            return false
        }

        let item = BiogramCollectible(
            title: slug,
            assetFilename: slug,
            assetType: "gift",
            giftSlug: slug,
            stickerFileId: nil
        )
        self.addCollectible(item, completion: completion)
        return true
    }

    public func moveCollectible(from fromIndex: Int, to toIndex: Int, completion: (() -> Void)? = nil) {
        guard fromIndex != toIndex,
              fromIndex >= 0,
              fromIndex < self.cachedCollectibles.count,
              toIndex >= 0,
              toIndex < self.cachedCollectibles.count else {
            completion?()
            return
        }

        let item = self.cachedCollectibles.remove(at: fromIndex)
        self.cachedCollectibles.insert(item, at: toIndex)
        self.storage.replaceCollectibles(self.cachedCollectibles, completion: completion)
    }

    public func replaceCollectibles(_ items: [BiogramCollectible], completion: (() -> Void)? = nil) {
        self.cachedCollectibles = items
        self.storage.replaceCollectibles(items, completion: completion)
    }

    // MARK: - Banner

    public func setBannerHeight(_ height: CGFloat, completion: (() -> Void)? = nil) {
        var custom = self.cachedCustomizations
        custom.bannerHeight = Double(max(60.0, min(400.0, height)))
        self.cachedCustomizations = custom
        self.storage.setCustomizations(custom, completion: completion)
    }

    public func bannerFileURL() -> URL? {
        guard let name = self.cachedBanner?.localFilename else {
            return nil
        }
        return Self.bannersDirectory().appendingPathComponent(name)
    }

    public func setBanner(_ banner: BiogramBanner?, completion: (() -> Void)? = nil) {
        let oldName = self.cachedBanner?.localFilename
        self.cachedBanner = banner
        if banner == nil {
            self.cachedBannerImage = nil
        }

        self.storage.setBanner(banner) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            if let oldName, oldName != banner?.localFilename {
                self.bannerIOQueue.async {
                    let oldURL = Self.bannersDirectory().appendingPathComponent(oldName)
                    try? FileManager.default.removeItem(at: oldURL)
                }
            }
            completion?()
        }
    }

    public func clearBanner(completion: (() -> Void)? = nil) {
        let oldName = self.cachedBanner?.localFilename
        self.cachedBanner = nil
        self.cachedBannerImage = nil

        self.storage.setBanner(nil) { [weak self] in
            guard let self else {
                completion?()
                return
            }
            if let oldName {
                self.bannerIOQueue.async {
                    let url = Self.bannersDirectory().appendingPathComponent(oldName)
                    try? FileManager.default.removeItem(at: url)
                }
            }
            completion?()
        }
    }

    /// Saves a banner without blocking the UI thread.
    /// The image is scaled down to a sensible maximum size before JPEG encoding.
    @discardableResult
    public func saveBannerImage(
        _ image: UIImage,
        aspectRatio: String = "free",
        completion: (() -> Void)? = nil
    ) -> Bool {
        guard image.size.width > 0.0, image.size.height > 0.0 else {
            completion?()
            return false
        }

        let oldName = self.cachedBanner?.localFilename
        let filename = "banner_\(UUID().uuidString).jpg"
        let dir = Self.bannersDirectory()
        let url = dir.appendingPathComponent(filename)
        let banner = BiogramBanner(localFilename: filename, aspectRatio: aspectRatio)

        self.cachedBanner = banner
        self.cachedBannerImage = image

        self.bannerIOQueue.async { [weak self] in
            guard let self else { return }
            autoreleasepool {
                do {
                    try FileManager.default.createDirectory(
                        at: dir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )

                    let optimizedImage = Self.optimizedBannerImage(image, maxDimension: 2048)
                    guard let data = optimizedImage.jpegData(compressionQuality: 0.88) else {
                        DispatchQueue.main.async {
                            completion?()
                        }
                        return
                    }

                    try data.write(to: url, options: [.atomic])

                    self.storage.setBanner(banner) {
                        if let oldName, oldName != filename {
                            self.bannerIOQueue.async {
                                let oldURL = dir.appendingPathComponent(oldName)
                                try? FileManager.default.removeItem(at: oldURL)
                            }
                        }
                        DispatchQueue.main.async {
                            completion?()
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
            }
        }

        return true
    }

    public func setBannerImage(
        _ image: UIImage?,
        aspectRatio: String = "free",
        completion: (() -> Void)? = nil
    ) {
        if let image {
            _ = self.saveBannerImage(image, aspectRatio: aspectRatio, completion: completion)
        } else {
            self.clearBanner(completion: completion)
        }
    }

    // MARK: - Image helpers

    private static func optimizedBannerImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else {
            return image
        }

        let scale = maxDimension / longest
        let targetSize = CGSize(
            width: max(1.0, floor(image.size.width * scale)),
            height: max(1.0, floor(image.size.height * scale))
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func bannersDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("Biogram/banners", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }
}
