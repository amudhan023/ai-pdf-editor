import Foundation
import InferenceAPI

/// Compile-time architecture check — sufficient for the coarse
/// Apple-Silicon-vs-Intel split the registry selects against
/// (ARCHITECTURE.md §7.1). Finer ANE-vs-GPU-vs-CPU planning within the
/// Apple Silicon tier is a Core ML adapter concern (P1-13+), not this
/// registry-selection layer's.
public enum HardwareTierDetector {
    public static func current() -> HardwareTier {
        #if arch(arm64)
        return .appleSilicon
        #else
        return .intel
        #endif
    }
}
