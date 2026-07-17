import Dispatch

/// Owns the `DispatchSourceMemoryPressure` the composition root wires to
/// `DocumentViewModel.handleMemoryPressure()` (P1-19). Lives here, not in
/// `DocumentSession`: the source's handler fires off any actor's isolation,
/// so `TileCache` exposes a call-in point instead of owning the source (see
/// that package's `CLAUDE.md` tiling-architecture note).
final class MemoryPressureMonitor {
    private let source: DispatchSourceMemoryPressure
    private let onPressure: () -> Void

    /// GCD is required here: memory-pressure signals are only surfaced via
    /// `DispatchSource` (no async-sequence equivalent exists). The handler
    /// does nothing but invoke `onPressure`, which hops straight to the
    /// main actor at the call site.
    /// Activates in `init`: libdispatch crashes on release of a source that
    /// was never activated, so a separate not-yet-started state would make
    /// every owner (including tests) responsible for avoiding that trap.
    init(queue: DispatchQueue = DispatchQueue.global(qos: .utility), onPressure: @escaping () -> Void) {
        self.onPressure = onPressure
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: queue)
        source.setEventHandler(handler: onPressure)
        source.activate()
    }

    /// Test seam: invokes the same closure the GCD source would, since
    /// real system memory-pressure events can't be raised from an XCTest
    /// process without root (`memory_pressure -S` needs sudo).
    func simulatePressureEvent() {
        onPressure()
    }

    deinit {
        source.cancel()
    }
}
