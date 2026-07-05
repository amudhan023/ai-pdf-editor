import Foundation

/// The closed set of typed inference endpoints (ARCHITECTURE.md §7.2).
/// Call sites ask for a capability; the registry maps it to the best
/// installed model for the current hardware tier — never name a model
/// file at a call site (CLAUDE.md §19).
public enum InferenceCapability: String, Sendable, Codable, CaseIterable, Equatable {
    case ocr
    case classify
    case extractEntities
    case embed
    case generate
}

/// Coarse hardware classes the model registry selects against
/// (ARCHITECTURE.md §7.1's "ANE on Apple Silicon; CPU fallback Intel").
public enum HardwareTier: String, Sendable, Codable, CaseIterable, Equatable {
    case appleSilicon
    case intel
}

/// Interactive requests (autofill matching) preempt background batch work
/// (ingestion OCR) per ARCHITECTURE.md §7.2.
public enum InferencePriority: String, Sendable, Codable, CaseIterable, Equatable {
    case interactive
    case background
}
