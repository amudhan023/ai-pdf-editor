import Foundation

/// A point in PDF page space (points, origin bottom-left per PDF spec).
/// Foundation-only (this package may not import CoreGraphics — see
/// Scripts/import-allowlist.txt), so this is a minimal local stand-in for
/// `CGPoint` rather than a re-export of it.
public struct PDFPoint: Sendable, Codable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// An axis-aligned rectangle in PDF page space. Local stand-in for `CGRect`
/// for the same reason as `PDFPoint`.
public struct PDFRect: Sendable, Codable, Equatable {
    public let origin: PDFPoint
    public let width: Double
    public let height: Double

    public init(origin: PDFPoint, width: Double, height: Double) {
        self.origin = origin
        self.width = width
        self.height = height
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: PDFPoint(x: x, y: y), width: width, height: height)
    }
}
