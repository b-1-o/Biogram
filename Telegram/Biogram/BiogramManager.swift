import Foundation

/// Singleton manager that exposes current Biogram state to the app.
/// Keeps a local-only overlay state. No network interception or server-side changes.

public final class BiogramManager {
    public static let shared = BiogramManager()

    private let storage: BiogramStorage

    // In-memory caches (kept in sync with storage)
    private var cachedCustomizations: BiogramCustomizations
    private var cachedAliases: [String]
    private var cachedVirtualNumbers: [BiogramVirtualNumber]
    private var cachedCollectibles: [BiogramCollectible]

    private init(storageBase: URL? = nil) {
        self.storage = BiogramStorage(baseDirectory: storageBase)
        // initialize caches synchronously by reading storage via semaphores on init
        let group = DispatchGroup()

        group.enter()
        var localCustom = BiogramCustomizations()
        storage.getCustomizations { c in
            localCustom = c
            group.leave()
        }
        group.wait()
        self.cachedCustomizations = localCustom

        group.enter()
        var localAliases: [String] = []
        storage.getAliases { a in
            localAliases = a
            group.leave()
        }
        group.wait()
        self.cachedAliases = localAliases

        group.enter()
        var localNums: [BiogramVirtualNumber] = []
        storage.getVirtualNumbers { n in
            localNums = n
            group.leave()
        }
        group.wait()
        self.cachedVirtualNumbers = localNums

        group.enter()
        var localCollects: [BiogramCollectible] = []
        storage.getCollectibles { c in
            localCollects = c
            group.leave()
        }
        group.wait()
        self.cachedCollectibles = localCollects
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

    // MARK: - Mutations (update storage + cache)

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
}
