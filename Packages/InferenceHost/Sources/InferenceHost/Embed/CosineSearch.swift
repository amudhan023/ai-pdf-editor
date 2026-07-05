import Foundation

/// In-memory nearest-neighbor ranking over embedding vectors — the
/// "cosine search utility" the embed rung needs to turn a query vector
/// into ranked candidates. Pure math, no I/O, so it stays a free function
/// rather than an actor.
public enum CosineSearch {
    /// Ranks `candidates` by cosine similarity to `query`, highest first.
    /// A candidate paired with a zero-magnitude vector sorts last (similarity
    /// defined as 0, not NaN) rather than crashing on the divide-by-zero.
    public static func rank<ID: Sendable>(
        query: [Float],
        candidates: [(id: ID, vector: [Float])]
    ) -> [(id: ID, score: Double)] {
        candidates
            .map { (id: $0.id, score: similarity(query, $0.vector)) }
            .sorted { $0.score > $1.score }
    }

    public static func similarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Double = 0, magA: Double = 0, magB: Double = 0
        for index in 0..<a.count {
            let x = Double(a[index]), y = Double(b[index])
            dot += x * y
            magA += x * x
            magB += y * y
        }
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA.squareRoot() * magB.squareRoot())
    }
}
