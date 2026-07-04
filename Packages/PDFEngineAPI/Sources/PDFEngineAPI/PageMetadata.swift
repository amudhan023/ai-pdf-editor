import Foundation

/// Zero-based page position within a document. A distinct type (not a bare
/// `Int`) so page/field/annotation indices can't be accidentally swapped at
/// call sites.
public struct PageIndex: Sendable, Hashable, Codable, Comparable, ExpressibleByIntegerLiteral {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public init(integerLiteral value: Int) {
        self.value = value
    }

    public static func < (lhs: PageIndex, rhs: PageIndex) -> Bool {
        lhs.value < rhs.value
    }
}

/// Page dimensions in PDF points (1/72 inch), independent of rotation.
public struct PageSize: Sendable, Codable, Equatable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Clockwise page rotation, mirroring the PDF spec's `/Rotate` entry.
public enum PageRotation: Int, Sendable, Codable, CaseIterable {
    case none = 0
    case clockwise90 = 90
    case clockwise180 = 180
    case clockwise270 = 270
}

public struct PageMetadata: Sendable, Codable, Equatable {
    public let index: PageIndex
    public let size: PageSize
    public let rotation: PageRotation

    public init(index: PageIndex, size: PageSize, rotation: PageRotation) {
        self.index = index
        self.size = size
        self.rotation = rotation
    }
}
