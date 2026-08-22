import Foundation

/// Simple local storage using Codable + file persistence.
/// This storage is intentionally tiny and synchronous for simplicity.
/// All data is local-only (Application support), no server/network interactions.

public final class BiogramStorage {
    private let queue = DispatchQueue(label: "org.biogram.storage", qos: .utility)
    private let storageURL: URL

    public struct StoragePayload: Codable {
        public var customizations: BiogramCustomizations
        public var aliases: [String]
        public var virtualNumbers: [BiogramVirtualNumber]
        public var collectibles: [BiogramCollectible]

        public init(customizations: BiogramCustomizations = BiogramCustomizations(), aliases: [String] = [], virtualNumbers: [BiogramVirtualNumber] = [], collectibles: [BiogramCollectible] = []) {
            self.customizations = customizations
            self.aliases = aliases
            self.virtualNumbers = virtualNumbers
            self.collectibles = collectibles
        }
    }

    private var payload: StoragePayload

    public init(baseDirectory: URL? = nil) {
        let base = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("Biogram", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        self.storageURL = folder.appendingPathComponent("biogram.json", isDirectory: false)

        if let data = try? Data(contentsOf: self.storageURL), let decoded = try? JSONDecoder().decode(StoragePayload.self, from: data) {
            self.payload = decoded
        } else {
            self.payload = StoragePayload()
            self.saveSync()
        }
    }

    // MARK: - Read accessors

    public func getCustomizations(completion: @escaping (BiogramCustomizations) -> Void) {
        queue.async {
            completion(self.payload.customizations)
        }
    }

    public func getAliases(completion: @escaping ([String]) -> Void) {
        queue.async {
            completion(self.payload.aliases)
        }
    }

    public func getVirtualNumbers(completion: @escaping ([BiogramVirtualNumber]) -> Void) {
        queue.async {
            completion(self.payload.virtualNumbers)
        }
    }

    public func getCollectibles(completion: @escaping ([BiogramCollectible]) -> Void) {
        queue.async {
            completion(self.payload.collectibles)
        }
    }

    // MARK: - Mutations

    public func setCustomizations(_ custom: BiogramCustomizations, completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.customizations = custom
            self.saveSync()
            completion?()
        }
    }

    public func addAlias(_ alias: String, completion: (() -> Void)? = nil) {
        queue.async {
            if !self.payload.aliases.contains(alias) {
                self.payload.aliases.append(alias)
                self.saveSync()
            }
            completion?()
        }
    }

    public func removeAlias(_ alias: String, completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.aliases.removeAll(where: { $0 == alias })
            self.saveSync()
            completion?()
        }
    }

    public func addVirtualNumber(_ number: BiogramVirtualNumber, completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.virtualNumbers.append(number)
            self.saveSync()
            completion?()
        }
    }

    public func removeVirtualNumber(id: String, completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.virtualNumbers.removeAll(where: { $0.id == id })
            self.saveSync()
            completion?()
        }
    }

    public func addCollectible(_ collectible: BiogramCollectible, completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.collectibles.append(collectible)
            self.saveSync()
            completion?()
        }
    }

    public func removeCollectible(id: String, completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.collectibles.removeAll(where: { $0.id == id })
            self.saveSync()
            completion?()
        }
    }
        public func replaceVirtualNumbers(_ numbers: [BiogramVirtualNumber], completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.virtualNumbers = numbers
            self.saveSync()
            completion?()
        }
    }

    public func replaceAliases(_ aliases: [String], completion: (() -> Void)? = nil) {
        queue.async {
            self.payload.aliases = aliases
            self.saveSync()
            completion?()
        }
    }

    // MARK: - Save/Load

    private func saveSync() {
        if let data = try? JSONEncoder().encode(self.payload) {
            try? data.write(to: self.storageURL, options: [.atomic])
        }
    }
}
