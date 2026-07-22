import Foundation

/// Encodes raw RGBA8 pixel buffers (as produced by `PDFEngineAPI.RenderedTile`)
/// into a minimal, spec-valid PNG `Data` blob — the format `InferenceHost`'s
/// `VisionOCRProvider`/Core ML classifier adapter decode via `ImageIO`
/// (`CGImageSourceCreateWithData`) on the other side of the frozen
/// `InferenceAPI.OCRRequest`/`ClassifyRequest.imageData: Data` contract.
///
/// **Why this exists instead of using `CoreGraphics`/`ImageIO`:** this
/// package's import allowlist (`Scripts/import-allowlist.txt`) is
/// Foundation/PDFEngineAPI/VaultAPI/InferenceAPI only — `PDFEngineAPI` itself
/// hits the same constraint (`Geometry.swift`'s `PDFPoint`/`PDFRect` are
/// hand-rolled `CGPoint`/`CGRect` stand-ins for exactly this reason). Adding
/// ImageIO/CoreGraphics here would be a boundary change (CLAUDE.md §3.7:
/// "New cross-package dependency? Stop. Write an ADR proposal first.") for
/// something a self-contained, spec-compliant encoder covers in native
/// Foundation with no new dependency (§17's "default answer is no").
///
/// Uses uncompressed ("stored") DEFLATE blocks (RFC 1951 §3.2.4, BTYPE=00) —
/// legal, spec-compliant PNG/zlib, decodable by any conforming reader
/// including `ImageIO`; larger on the wire than a real compressor but this
/// is an internal OCR/classify transport blob, not a stored asset, so that
/// tradeoff is the right one. See `PNGEncoderTests` for a full structural
/// + stored-block round-trip verification.
public enum PNGEncoder {
    private static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// `rgba` must be exactly `width * height * 4` bytes, row-major, no
    /// padding — the same layout `RenderedTile.pixelData` documents.
    public static func encode(rgba: Data, width: Int, height: Int) -> Data {
        precondition(rgba.count == width * height * 4, "rgba buffer size must match width*height*4")

        var output = Data(signature)
        output.append(chunk(type: "IHDR", data: ihdrPayload(width: width, height: height)))
        output.append(chunk(type: "IDAT", data: [UInt8](idatPayload(rgba: rgba, width: width, height: height))))
        output.append(chunk(type: "IEND", data: []))
        return output
    }

    private static func ihdrPayload(width: Int, height: Int) -> [UInt8] {
        var payload = beBytes(UInt32(width))
        payload += beBytes(UInt32(height))
        payload += [8, 6, 0, 0, 0] // bit depth 8, color type 6 (RGBA), compression/filter/interlace 0
        return payload
    }

    /// Filtered scanlines (filter byte 0 = "None" prefixing each row, PNG
    /// spec §6.2) wrapped in a zlib stream (RFC 1950) whose deflate body
    /// (RFC 1951) is a sequence of stored blocks.
    private static func idatPayload(rgba: Data, width: Int, height: Int) -> Data {
        let rowBytes = width * 4
        var filtered = [UInt8]()
        filtered.reserveCapacity((rowBytes + 1) * height)
        rgba.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for row in 0..<height {
                filtered.append(0) // filter type None
                let start = row * rowBytes
                filtered.append(contentsOf: raw[start..<(start + rowBytes)])
            }
        }

        var zlib = Data([0x78, 0x01]) // zlib header: deflate, 32K window, no preset dict, fastest
        zlib.append(storedDeflate(filtered))
        zlib.append(beBytes(adler32(filtered)).data)
        return zlib
    }

    /// RFC 1951 §3.2.4 stored blocks: split into <=65535-byte chunks, each
    /// with a 1-byte-aligned header (BFINAL/BTYPE, byte-padded) + LEN/NLEN +
    /// raw bytes. Zero compression, fully deterministic, trivially
    /// round-trippable — see the test for the inverse check.
    private static func storedDeflate(_ bytes: [UInt8]) -> Data {
        var out = Data()
        let maxBlock = 65535
        var offset = 0
        if bytes.isEmpty {
            out.append(0x01) // BFINAL=1, BTYPE=00, single empty final block
            out.append(contentsOf: leBytes(UInt16(0)))
            out.append(contentsOf: leBytes(UInt16(0xFFFF)))
            return out
        }
        while offset < bytes.count {
            let len = min(maxBlock, bytes.count - offset)
            let isFinal = (offset + len) >= bytes.count
            out.append(isFinal ? 0x01 : 0x00)
            let len16 = UInt16(len)
            out.append(contentsOf: leBytes(len16))
            out.append(contentsOf: leBytes(~len16))
            out.append(contentsOf: bytes[offset..<(offset + len)])
            offset += len
        }
        return out
    }

    private static func chunk(type: String, data: [UInt8]) -> Data {
        var result = beBytes(UInt32(data.count)).data
        let typeBytes = [UInt8](type.utf8)
        var crcInput = typeBytes
        crcInput.append(contentsOf: data)
        result.append(contentsOf: typeBytes)
        result.append(contentsOf: data)
        result.append(beBytes(crc32(crcInput)).data)
        return result
    }

    private static func beBytes(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private static func leBytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)]
    }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        let modAdler: UInt32 = 65521
        for byte in bytes {
            a = (a + UInt32(byte)) % modAdler
            b = (b + a) % modAdler
        }
        return (b << 16) | a
    }
}

private extension [UInt8] {
    var data: Data { Data(self) }
}
