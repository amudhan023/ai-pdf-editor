import Compression
import Foundation

/// DOCX text extraction (ADR-017): DOCX is a ZIP archive; `word/document.xml`
/// holds the document body as OOXML. This walks the ZIP's local file headers
/// to find that one entry's compressed bytes, inflates them with Apple's
/// `Compression` framework (raw DEFLATE = `COMPRESSION_ZLIB` in this API's
/// naming — matches ZIP's compression method 8), then extracts plain text
/// via `Foundation.XMLParser` (already unrestricted) by collecting every
/// `<w:t>` run-text element's character data.
///
/// **Scope cut (documented, not silently assumed away):** only the common
/// case where the local file header carries real compressed/uncompressed
/// sizes is supported — some zip writers set the "data descriptor" bit
/// (general-purpose flag bit 3) and leave local-header sizes at 0, requiring
/// a central-directory scan to find the true sizes. Office/LibreOffice's
/// DOCX writers don't do this (verified against real `.docx` output), so
/// this is a real-world-safe simplification, not a correctness gap for the
/// documents this product actually ingests — a zip using the streamed form
/// fails as a typed `.corruptInput`, never a crash or garbled output.
enum DocxTextExtractor {
    private static let localFileHeaderSignature: UInt32 = 0x0403_4B50
    private static let targetEntryName = "word/document.xml"

    static func extractPlainText(from zipData: Data) throws -> String {
        let xml = try extractEntry(named: targetEntryName, from: zipData)
        return try TextRunXMLParser.extractText(from: xml, elementName: "w:t")
    }

    /// Scans local file header records from the start of the archive
    /// (bounded by `zipData.count` on every field read — a truncated or
    /// adversarial length never walks past the buffer) until it finds
    /// `name`, then returns that entry's decompressed bytes.
    private static func extractEntry(named name: String, from zipData: Data) throws -> Data {
        let bytes = [UInt8](zipData)
        var offset = 0

        while offset + 30 <= bytes.count {
            let signature = readUInt32LE(bytes, at: offset)
            guard signature == localFileHeaderSignature else {
                // Not a local file header (likely walked into the central
                // directory) - the target entry wasn't found before this.
                break
            }
            let generalPurposeFlag = readUInt16LE(bytes, at: offset + 6)
            let compressionMethod = readUInt16LE(bytes, at: offset + 8)
            let compressedSize = Int(readUInt32LE(bytes, at: offset + 18))
            let uncompressedSize = Int(readUInt32LE(bytes, at: offset + 22))
            let nameLength = Int(readUInt16LE(bytes, at: offset + 26))
            let extraLength = Int(readUInt16LE(bytes, at: offset + 28))

            guard (generalPurposeFlag & 0x08) == 0 else {
                throw IngestionError.corruptInput(.docx, reason: "streamed (data-descriptor) zip entries are not supported")
            }

            let nameStart = offset + 30
            let nameEnd = nameStart + nameLength
            guard nameEnd <= bytes.count else {
                throw IngestionError.corruptInput(.docx, reason: "truncated zip: file name overruns buffer")
            }
            let entryName = String(bytes: bytes[nameStart..<nameEnd], encoding: .utf8) ?? ""

            let dataStart = nameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            guard dataStart >= 0, dataEnd <= bytes.count, dataStart <= dataEnd else {
                throw IngestionError.corruptInput(.docx, reason: "truncated zip: entry data overruns buffer")
            }

            if entryName == name {
                let entryData = Data(bytes[dataStart..<dataEnd])
                switch compressionMethod {
                case 0:
                    return entryData
                case 8:
                    return try inflate(entryData, uncompressedSize: uncompressedSize)
                default:
                    throw IngestionError.corruptInput(.docx, reason: "unsupported zip compression method \(compressionMethod)")
                }
            }

            offset = dataEnd
        }

        throw IngestionError.corruptInput(.docx, reason: "\(name) not found in archive")
    }

    /// `compression_decode_buffer` writes at most `uncompressedSize` bytes
    /// into a buffer sized exactly for that — the declared size from the
    /// zip's own local header, never attacker-controlled beyond what the
    /// entry itself already claims, and bounded (no growth loop) either way.
    private static func inflate(_ compressed: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }
        var destination = [UInt8](repeating: 0, count: uncompressedSize)
        let written = destination.withUnsafeMutableBytes { destBuffer -> Int in
            compressed.withUnsafeBytes { srcBuffer -> Int in
                guard let destBase = destBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let srcBase = srcBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destBase, uncompressedSize,
                    srcBase, compressed.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == uncompressedSize else {
            throw IngestionError.corruptInput(.docx, reason: "deflate stream did not decompress to the declared size")
        }
        return Data(destination)
    }

    private static func readUInt16LE(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }
}

/// Collects character data inside every occurrence of `elementName`,
/// joined with a space between elements — mirrors how `w:t` runs are meant
/// to be concatenated into a paragraph's visible text.
private final class TextRunXMLParser: NSObject, XMLParserDelegate {
    private let elementName: String
    private var insideTarget = false
    private var current = ""
    private var collected: [String] = []
    private var parseError: Error?

    private init(elementName: String) {
        self.elementName = elementName
    }

    static func extractText(from xmlData: Data, elementName: String) throws -> String {
        let delegate = TextRunXMLParser(elementName: elementName)
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        guard parser.parse() else {
            throw delegate.parseError ?? IngestionError.corruptInput(.docx, reason: "malformed document.xml")
        }
        return delegate.collected.joined(separator: " ")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == self.elementName {
            insideTarget = true
            current = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideTarget { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == self.elementName {
            insideTarget = false
            if !current.isEmpty { collected.append(current) }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = IngestionError.corruptInput(.docx, reason: "XML parse error: \(parseError.localizedDescription)")
    }
}
