import AppKit

extension PageImage {
    /// Converts the tile's raw RGBA8 bytes into a displayable `NSImage`.
    /// `DocumentSession`'s import allowlist has no `CoreGraphics` entry
    /// (see package `CLAUDE.md`), so this goes through `NSBitmapImageRep`
    /// rather than `CGImage` directly — AppKit alone is enough to build one
    /// from a raw bitmap plane.
    public func makeNSImage() -> NSImage {
        let width = tile.pixelWidth
        let height = tile.pixelHeight
        let image = NSImage(size: NSSize(width: width, height: height))

        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: width * 4,
                bitsPerPixel: 32
              ),
              let planeData = rep.bitmapData
        else { return image }

        tile.pixelData.withUnsafeBytes { source in
            guard let base = source.bindMemory(to: UInt8.self).baseAddress else { return }
            planeData.update(from: base, count: min(source.count, width * height * 4))
        }

        image.addRepresentation(rep)
        return image
    }
}
