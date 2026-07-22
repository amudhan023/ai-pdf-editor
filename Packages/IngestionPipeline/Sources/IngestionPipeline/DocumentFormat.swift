import Foundation

/// Input formats the normalizer recognizes. `.docx`/`.rtf` are detected but
/// not yet normalizable — see `Normalizer`'s doc comment for why (a real
/// import-allowlist boundary gap, not an oversight).
public enum DocumentFormat: String, Sendable, Equatable, CaseIterable {
    case pdf
    case txt
    case docx
    case rtf
    case jpeg
    case png
    case heic
    case tiff
    case unknown

    /// Magic-byte sniffing first (authoritative when present), falling back
    /// to the file extension — never trusts a possibly-wrong extension over
    /// real content when both are available.
    public static func detect(fileURL: URL, prefix: Data) -> DocumentFormat {
        if let byMagic = detectByMagicBytes(prefix) {
            return byMagic
        }
        switch fileURL.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "txt": return .txt
        case "docx": return .docx
        case "rtf": return .rtf
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "tif", "tiff": return .tiff
        default: return .unknown
        }
    }

    private static func detectByMagicBytes(_ prefix: Data) -> DocumentFormat? {
        let bytes = [UInt8](prefix.prefix(12))
        guard !bytes.isEmpty else { return nil }

        if bytes.starts(with: [0x25, 0x50, 0x44, 0x46]) { return .pdf } // %PDF
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return .jpeg }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .png }
        if bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) { return .tiff }
        if bytes.count >= 12, bytes[4...7].elementsEqual([0x66, 0x74, 0x79, 0x70]) {
            // ISO base media container ("ftyp" box) — HEIC/HEIF's brand
            // sits at offset 8; only classify the common Apple brands so an
            // MP4/MOV isn't mis-sniffed as an image.
            let brand = String(bytes: bytes[8...11], encoding: .ascii) ?? ""
            if ["heic", "heix", "hevc", "heim", "heis", "hevm", "hevs", "mif1"].contains(brand) {
                return .heic
            }
        }
        if bytes.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return .docx } // ZIP signature (DOCX is a zip)
        if bytes.starts(with: Array("{\\rtf1".utf8)) { return .rtf }
        return nil
    }
}
