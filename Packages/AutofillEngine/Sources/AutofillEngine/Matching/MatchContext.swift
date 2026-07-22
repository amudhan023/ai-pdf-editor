import Foundation
import PDFEngineAPI

/// Everything the matching ladder can see about a field beyond its bare
/// name: tooltip, nearby page text, and section headers (P2-03 Requirement
/// 1). Constructing one is a pure, deterministic operation — no engine or
/// inference calls — so it's testable independent of `SemanticMatcher`.
public struct MatchContext: Sendable, Equatable {
    /// The primary label used for dictionary lookup — kept separate from
    /// the enrichment below because dictionary matching must stay exact
    /// (see `AliasMatcher.match`'s `queryText` doc comment).
    public let label: String
    public let tooltip: String?
    public let nearbyText: [String]
    public let sectionHeaders: [String]

    public init(label: String, tooltip: String? = nil, nearbyText: [String] = [], sectionHeaders: [String] = []) {
        self.label = label
        self.tooltip = tooltip
        self.nearbyText = nearbyText
        self.sectionHeaders = sectionHeaders
    }

    /// Enriched text fed to the embedding/LLM rungs only (never the
    /// dictionary rung). Ordered most- to least-informative: label,
    /// tooltip, section headers, then nearby text — so a downstream
    /// truncation (a real embedding model's token limit) drops the
    /// weakest signal first.
    public var assembledText: String {
        var parts = [label]
        if let tooltip, !tooltip.isEmpty { parts.append(tooltip) }
        parts.append(contentsOf: sectionHeaders)
        parts.append(contentsOf: nearbyText)
        return parts.joined(separator: " ")
    }
}

/// Builds a `MatchContext` from a field's geometry and a page's text runs
/// (P1-03). Proximity/header heuristics are not spec-derived — retune
/// `maxDistance`/`headerFontSizeRatio` against real forms once a labeled
/// fixture corpus exists (same class of gap as
/// `tasks/escalations/E-005-corpus-acquisition-gap.md`).
public enum ContextAssembler {
    public static func assemble(
        field: FormField,
        pageTextRuns: [TextRun],
        maxDistance: Double = 150,
        headerFontSizeRatio: Double = 1.3
    ) -> MatchContext {
        let label = field.tooltip ?? field.name
        let nearby = pageTextRuns
            .filter { $0.page == field.page }
            .map { run in (run: run, distance: distance(center(of: field.rect), center(of: run.boundingBox))) }
            .filter { $0.distance <= maxDistance }
            .sorted { $0.distance < $1.distance }

        guard !nearby.isEmpty else {
            return MatchContext(label: label, tooltip: field.tooltip)
        }

        let medianFontSize = median(nearby.map(\.run.fontSize))
        var plainText: [String] = []
        var headers: [String] = []
        for entry in nearby {
            if medianFontSize > 0, entry.run.fontSize >= medianFontSize * headerFontSizeRatio {
                headers.append(entry.run.text)
            } else {
                plainText.append(entry.run.text)
            }
        }
        return MatchContext(label: label, tooltip: field.tooltip, nearbyText: plainText, sectionHeaders: headers)
    }

    private static func center(of rect: PDFRect) -> PDFPoint {
        PDFPoint(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)
    }

    private static func distance(_ a: PDFPoint, _ b: PDFPoint) -> Double {
        let squared = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
        return squared.squareRoot()
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
