import CoreGraphics
import CoreText
import ImageIO
import InferenceAPI
import XCTest
@testable import InferenceHost

final class VisionOCRTests: XCTestCase {
    func test_ocr_recognizesTextInRenderedImage() async throws {
        let client = try await TestSupport.makeRealClient()
        let response = try await client.ocr(OCRRequest(imageData: Self.renderedTextImage(text: "HELLO")))

        XCTAssertFalse(response.regions.isEmpty)
        let recognized = response.regions.map(\.text).joined(separator: " ")
        XCTAssertTrue(recognized.uppercased().contains("HELLO"), "expected recognized text to contain HELLO, got \(recognized)")

        for region in response.regions {
            XCTAssertTrue((0...1).contains(region.confidence))
            XCTAssertTrue((0...1).contains(region.boundingBox.x))
            XCTAssertTrue((0...1).contains(region.boundingBox.y))
            XCTAssertTrue((0...1).contains(region.boundingBox.width))
            XCTAssertTrue((0...1).contains(region.boundingBox.height))
        }
    }

    func test_ocr_undecodableImageData_throwsAdapterFailure() async throws {
        let client = try await TestSupport.makeRealClient()
        do {
            _ = try await client.ocr(OCRRequest(imageData: Data([0x01, 0x02, 0x03])))
            XCTFail("expected adapterFailure for undecodable image data")
        } catch InferenceError.adapterFailure {
            // expected: honest failure, not a fabricated region (CLAUDE.md §2)
        }
    }

    func test_ocr_emptyImageData_throwsAdapterFailure() async throws {
        let client = try await TestSupport.makeRealClient()
        do {
            _ = try await client.ocr(OCRRequest(imageData: Data()))
            XCTFail("expected adapterFailure for empty image data")
        } catch InferenceError.adapterFailure {
            // expected
        }
    }

    func test_normalizeContrast_preservesDecodability() throws {
        let original = try Self.cgImage(from: Self.renderedTextImage(text: "OK"))
        let adjusted = VisionOCRProvider.normalizeContrast(original)
        XCTAssertNotNil(adjusted)
        XCTAssertEqual(adjusted?.width, original.width)
        XCTAssertEqual(adjusted?.height, original.height)
    }

    /// Renders `text` onto a small white bitmap and encodes it as PNG data
    /// — a real, decodable image a real OCR engine can honestly recognize
    /// text in (same technique documented in ADR-012 for the InferenceAPI
    /// conformance fixture).
    private static func renderedTextImage(text: String, width: Int = 200, height: Int = 60) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("could not create bitmap context")
            return Data()
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 36, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        context.textPosition = CGPoint(x: 10, y: 12)
        CTLineDraw(line, context)

        guard let cgImage = context.makeImage() else {
            XCTFail("could not render image")
            return Data()
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            XCTFail("could not create image destination")
            return Data()
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private static func cgImage(from pngData: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ConformanceFailure("test fixture image did not decode")
        }
        return image
    }
}
