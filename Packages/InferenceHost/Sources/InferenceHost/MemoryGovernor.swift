import Foundation
import InferenceAPI

/// Tracks estimated resident memory of loaded models against a cap,
/// evicting least-recently-used models to make room
/// (ARCHITECTURE.md §7.2's "Memory Governor... load/unload, caps").
public actor MemoryGovernor {
    private struct LoadedModel {
        let estimatedBytes: Int
        var lastUsed: Date
    }

    private let capBytes: Int
    private var loaded: [String: LoadedModel] = [:]

    public init(capBytes: Int) {
        self.capBytes = capBytes
    }

    public var currentUsageBytes: Int {
        loaded.values.reduce(0) { $0 + $1.estimatedBytes }
    }

    public var loadedModelIDs: Set<String> {
        Set(loaded.keys)
    }

    /// Ensures `modelID` is accounted for as loaded, evicting LRU models
    /// first if needed. Throws `.memoryCapExceeded` when `estimatedBytes`
    /// alone exceeds the cap — no eviction sequence can make room for a
    /// single model bigger than the whole budget.
    public func ensureLoaded(modelID: String, estimatedBytes: Int) throws {
        if loaded[modelID] != nil {
            loaded[modelID]?.lastUsed = Date()
            return
        }
        guard estimatedBytes <= capBytes else {
            throw InferenceError.memoryCapExceeded
        }
        while currentUsageBytes + estimatedBytes > capBytes, let lruID = leastRecentlyUsedID() {
            loaded.removeValue(forKey: lruID)
        }
        loaded[modelID] = LoadedModel(estimatedBytes: estimatedBytes, lastUsed: Date())
    }

    public func unload(modelID: String) {
        loaded.removeValue(forKey: modelID)
    }

    private func leastRecentlyUsedID() -> String? {
        loaded.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key
    }
}
