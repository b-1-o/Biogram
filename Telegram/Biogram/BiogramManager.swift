import Foundation
import UIKit

/// Singleton manager that exposes current Biogram state to the app.
/// Keeps a local-only overlay state. Now supports per-account settings.
public final class BiogramManager {
    public static let shared = BiogramManager()
    
    private let storage: BiogramStorage
    
    // Текущий аккаунт
    private var currentAccountId: String = "default"
    
    // In-memory caches
    private var cachedCustomizations: BiogramCustomizations
    private var cachedAliases: [String]
    private var cachedVirtualNumbers: [BiogramVirtualNumber]
    private var cachedCollectibles: [BiogramCollectible]
    private var cachedBanner: BiogramBanner?
    private var cachedBannerImage: UIImage?
    
    private init(storageBase: URL? = nil) {
        self.storage = BiogramStorage(baseDirectory: storageBase)
        
        // На старте грузим пустые значения. Настоящие настройки подтянутся через switchToAccount
        self.cachedCustomizations = BiogramCustomizations()
        self.cachedAliases = []
        self.cachedVirtualNumbers = []
        self.cachedCollectibles = []
        self.cachedBanner = nil
        self.cachedBannerImage = nil
    }
    
    // MARK: - Переключение аккаунта
    
    /// Вызывать каждый раз, когда пользователь переключает аккаунт
    public func switchToAccount(accountId: String, completion: (() -> Void)? = nil) {
        // Сохраняем текущие настройки старого аккаунта (на всякий случай)
        storage.setCurrentAccountId(currentAccountId)
        
        // Меняем id
        currentAccountId = accountId
        storage.setCurrentAccountId(accountId)
        
        // Загружаем настройки нового аккаунта
        storage.load(for: accountId) { [weak self] payload in
            guard let self = self else { return }
            
            self.cachedCustomizations = payload.customizations
            self.cachedAliases = payload.aliases
            self.cachedVirtualNumbers = payload.virtualNumbers
            self.cachedCollectibles = payload.collectibles
            self.cachedBanner = payload.banner
            
            // Загружаем картинку баннера
            if let banner = payload.banner {
                let url = Self.bannersDirectory().appendingPathComponent(banner.localFilename)
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    self.cachedBannerImage = image
                } else {
                    self.cachedBannerImage = nil
                }
            } else {
                self.cachedBannerImage = nil
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    // MARK: - Read accessors
    
    public var localPremiumEnabled: Bool {
        return cachedCustomizations.localPremiumEnabled
    }
    
    public func aliases() -> [String] {
        return cachedAliases
    }
    
    public func virtualNumbers() -> [BiogramVirtualNumber] {
        return cachedVirtualNumbers
    }
    
    public func collectibles() -> [BiogramCollectible] {
        return cachedCollectibles
    }
    
    public func banner() -> BiogramBanner? {
        return cachedBanner
    }
    
    public func bannerImage() -> UIImage? {
        return cachedBannerImage
    }
    
    public var bannerHeight: CGFloat {
        return CGFloat(cachedCustomizations.bannerHeight)
    }
    
    public var profileColorEnabled: Bool {
        return cachedCustomizations.profileColorEnabled
    }
    
    public var profileColor: BiogramProfileColor? {
        return cachedCustomizations.profileColor
    }
    
    // MARK: - Mutations
    
    public func setLocalPremiumEnabled(_ enabled: Bool, completion: (() -> Void)? = nil) {
        var custom = cachedCustomizations
        custom.localPremiumEnabled = enabled
        self.cachedCustomizations = custom
        storage.setCustomizations(custom, completion: completion)
    }
    
    public func addAlias(_ alias: String, completion: (() -> Void)? = nil) {
        if !cachedAliases.contains(alias) {
            cachedAliases.append(alias)
            storage.addAlias(alias, completion: completion)
        } else {
            completion?()
        }
    }
    
    public func removeAlias(_ alias: String, completion: (() -> Void)? = nil) {
        cachedAliases.removeAll(where: { $0 == alias })
        storage.removeAlias(alias, completion: completion)
    }
    
    public func addVirtualNumber(_ number: BiogramVirtualNumber, completion: (() -> Void)? = nil) {
        cachedVirtualNumbers.append(number)
        storage.addVirtualNumber(number, completion: completion)
    }
    
    public func removeVirtualNumber(id: String, completion: (() -> Void)? = nil) {
        cachedVirtualNumbers.removeAll(where: { $0.id == id })
        storage.removeVirtualNumber(id: id, completion: completion)
    }
    
    public func addCollectible(_ collectible: BiogramCollectible, completion: (() -> Void)? = nil) {
        cachedCollectibles.append(collectible)
        storage.addCollectible(collectible, completion: completion)
    }
    
    public func removeCollectible(id: String, completion: (() -> Void)? = nil) {
        cachedCollectibles.removeAll(where: { $0.id == id })
        storage.removeCollectible(id: id, completion: completion)
    }
    
    public func replaceAlias(old: String, new: String, completion: (() -> Void)? = nil) {
        if let idx = cachedAliases.firstIndex(of: old) {
            cachedAliases[idx] = new
            storage.replaceAliases(cachedAliases, completion: completion)
        } else {
            completion?()
        }
    }
    
    public func updateVirtualNumber(id: String, number: String, label: String?, completion: (() -> Void)? = nil) {
        if let idx = cachedVirtualNumbers.firstIndex(where: { $0.id == id }) {
            cachedVirtualNumbers[idx].number = number
            cachedVirtualNumbers[idx].label = label
            storage.replaceVirtualNumbers(cachedVirtualNumbers, completion: completion)
        } else {
            completion?()
        }
    }
    
    public func setProfileColor(_ color: BiogramProfileColor?, enabled: Bool, completion: (() -> Void)? = nil) {
        var custom = cachedCustomizations
        custom.profileColor = color
        custom.profileColorEnabled = enabled
        self.cachedCustomizations = custom
        storage.setCustomizations(custom, completion: completion)
    }
    
    // MARK: - Gifts from NFT link
    
    @discardableResult
    public func addCollectibleFromGiftLink(_ input: String, completion: (() -> Void)? = nil) -> Bool {
        guard let slug = BiogramGiftLink.slug(from: input) else {
            completion?()
            return false
        }
        if cachedCollectibles.contains(where: { $0.giftSlug == slug }) {
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
        addCollectible(item, completion: completion)
        return true
    }
    
    public func moveCollectible(from fromIndex: Int, to toIndex: Int, completion: (() -> Void)? = nil) {
        guard fromIndex != toIndex,
              fromIndex >= 0, fromIndex < cachedCollectibles.count,
              toIndex >= 0, toIndex < cachedCollectibles.count else {
            completion?()
            return
        }
        let item = cachedCollectibles.remove(at: fromIndex)
        cachedCollectibles.insert(item, at: toIndex)
        storage.replaceCollectibles(cachedCollectibles, completion: completion)
    }
    
    public func replaceCollectibles(_ items: [BiogramCollectible], completion: (() -> Void)? = nil) {
        cachedCollectibles = items
        storage.replaceCollectibles(items, completion: completion)
    }
    
    // MARK: - Banner
    
    public func setBannerHeight(_ height: CGFloat, completion: (() -> Void)? = nil) {
        var custom = cachedCustomizations
        custom.bannerHeight = Double(max(60, min(400, height)))
        cachedCustomizations = custom
        storage.setCustomizations(custom, completion: completion)
    }
    
    public func bannerFileURL() -> URL? {
        guard let name = cachedBanner?.localFilename else { return nil }
        return Self.bannersDirectory().appendingPathComponent(name)
    }
    
    public func setBanner(_ banner: BiogramBanner?, completion: (() -> Void)? = nil) {
        if let old = cachedBanner?.localFilename, old != banner?.localFilename {
            let oldURL = Self.bannersDirectory().appendingPathComponent(old)
            try? FileManager.default.removeItem(at: oldURL)
        }
        cachedBanner = banner
        if banner == nil {
            cachedBannerImage = nil
        }
        storage.setBanner(banner, completion: completion)
    }
    
    public func clearBanner(completion: (() -> Void)? = nil) {
        if let name = cachedBanner?.localFilename {
            let url = Self.bannersDirectory().appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
        cachedBanner = nil
        cachedBannerImage = nil
        storage.setBanner(nil, completion: completion)
    }
    
    @discardableResult
    public func saveBannerImage(
        _ image: UIImage,
        aspectRatio: String = "free",
        completion: (() -> Void)? = nil
    ) -> Bool {
        let dir = Self.bannersDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        // удаляем старый файл
        if let oldName = cachedBanner?.localFilename {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(oldName))
        }
        
        let filename = "banner_\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            completion?()
            return false
        }
        
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            completion?()
            return false
        }
        
        let item = BiogramBanner(localFilename: filename, aspectRatio: aspectRatio)
        cachedBanner = item
        cachedBannerImage = image
        storage.setBanner(item, completion: completion)
        return true
    }
    
    /// Удобный метод: сохранить или удалить
    public func setBannerImage(_ image: UIImage?, aspectRatio: String = "free", completion: (() -> Void)? = nil) {
        if let image = image {
            _ = saveBannerImage(image, aspectRatio: aspectRatio, completion: completion)
        } else {
            clearBanner(completion: completion)
        }
    }
    
    private static func bannersDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Biogram/banners", isDirectory: true)
    }
}
