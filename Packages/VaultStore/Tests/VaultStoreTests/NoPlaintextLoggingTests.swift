import XCTest
@testable import VaultStore

/// Source-grep guard against `print(` in this package's product sources
/// (CLAUDE.md §16: "no `print` in product code"; §7.2/§8: never log vault
/// values). Catches a whole class of accidental plaintext leaks at the
/// cheapest possible layer, ahead of CI's own repo-wide red-line grep.
final class NoPlaintextLoggingTests: XCTestCase {
    func testNoPrintStatementsInSources() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let sourcesDir = thisFile
            .deletingLastPathComponent() // VaultStoreTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/VaultStore")

        let enumerator = FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)
        var offenders: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let contents = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains("print(") {
                offenders.append("\(url.lastPathComponent):\(index + 1)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "product code must never call print(): \(offenders)")
    }
}
