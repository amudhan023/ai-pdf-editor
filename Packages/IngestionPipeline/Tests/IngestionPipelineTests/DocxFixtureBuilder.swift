import Compression
import Foundation
@testable import IngestionPipeline

/// Hand-constructs a minimal single-entry ZIP containing `word/document.xml`
/// — just enough of the format for `DocxTextExtractor` to parse, not a
/// general-purpose zip writer. `compressed: true` exercises the real
/// `compression_decode_buffer` inflate path (via `compression_encode_buffer`
/// to produce a genuine DEFLATE stream); `compressed: false` uses the
/// stored (method 0) path.
enum DocxFixtureBuilder {
    static func buildMinimalDocx(bodyXML: String, compressed: Bool, entryName: String = "word/document.xml") -> Data {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>\(bodyXML)</w:body>
        </w:document>
        """
        let xmlData = Data(xmlContent.utf8)
        let nameBytes = [UInt8](entryName.utf8)

        let (payload, method): (Data, UInt16) = compressed
            ? (deflate(xmlData), 8)
            : (xmlData, 0)

        var header = Data()
        header.append(contentsOf: le32(0x0403_4B50))
        header.append(contentsOf: le16(20))       // version needed
        header.append(contentsOf: le16(0))        // general purpose flag (no data descriptor)
        header.append(contentsOf: le16(method))
        header.append(contentsOf: le16(0))        // mod time
        header.append(contentsOf: le16(0))        // mod date
        header.append(contentsOf: le32(0))        // crc-32 (unchecked by our reader)
        header.append(contentsOf: le32(UInt32(payload.count)))
        header.append(contentsOf: le32(UInt32(xmlData.count)))
        header.append(contentsOf: le16(UInt16(nameBytes.count)))
        header.append(contentsOf: le16(0))        // extra field length
        header.append(contentsOf: nameBytes)
        header.append(payload)
        return header
    }

    private static func deflate(_ data: Data) -> Data {
        let capacity = data.count + 256
        var destination = [UInt8](repeating: 0, count: capacity)
        let written = destination.withUnsafeMutableBytes { destBuffer -> Int in
            data.withUnsafeBytes { srcBuffer -> Int in
                compression_encode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!, capacity,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!, data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        precondition(written > 0, "test fixture compression failed")
        return Data(destination.prefix(written))
    }

    private static func le16(_ value: UInt16) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)] }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 24 & 0xFF)]
    }
}
