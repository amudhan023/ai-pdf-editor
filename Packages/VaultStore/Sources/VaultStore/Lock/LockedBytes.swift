import Foundation

/// A raw buffer that is `mlock`ed for its whole lifetime and explicitly
/// zeroized before being freed (CLAUDE.md §7.2: "master key... `mlock`ed,
/// zeroized on lock"). `mlock`/`munlock`/`memset_s` are POSIX calls
/// reachable with only `import Foundation` on Apple platforms — verified
/// empirically, no `Darwin` import (and so no boundary-lint entry) needed.
///
/// This only hardens the *resident* copy this instance owns. Any `Data`/
/// `SymmetricKey` a caller constructs from `withUnsafeBytes`/`data` is a
/// fresh copy outside this guarantee — same caveat `VaultAPI.SecureBytes`
/// documents about `exposeAsPlaintext()`. Callers should re-derive rather
/// than cache such copies.
final class LockedBytes: @unchecked Sendable {
    private let pointer: UnsafeMutableRawPointer
    let count: Int
    private var zeroized = false

    init(_ bytes: Data) {
        count = bytes.count
        pointer = .allocate(byteCount: max(count, 1), alignment: 1)
        bytes.withUnsafeBytes { source in
            pointer.copyMemory(from: source.baseAddress ?? UnsafeRawPointer(pointer), byteCount: count)
        }
        mlock(pointer, count)
    }

    /// A fresh copy of the current contents — callers should use this
    /// immediately (to key a cipher, etc.) rather than retain it.
    var data: Data {
        Data(bytes: pointer, count: count)
    }

    func zeroize() {
        guard !zeroized else { return }
        _ = memset_s(pointer, count, 0, count)
        zeroized = true
    }

    deinit {
        zeroize()
        munlock(pointer, count)
        pointer.deallocate()
    }
}
