import XCTest
@testable import DocumentSession

final class AtomicSaveTests: XCTestCase {
    func testReplaceCreatesBackupAndMovesFile() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = dir.appendingPathComponent("doc.pdf")
        let temp = dir.appendingPathComponent("doc.tmp")
        try "original".data(using: .utf8)!.write(to: original)
        try "new".data(using: .utf8)!.write(to: temp)
        let saver = AtomicSaver()
        try saver.replace(original: original, withTemp: temp)
        // original should now contain "new"
        let data = try Data(contentsOf: original)
        XCTAssertEqual(String(data: data, encoding: .utf8), "new")
        // backup should exist
        let backup = original.appendingPathExtension("backup")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
    }
}
