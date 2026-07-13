import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import InferenceAPI
import Vision

/// Real OCR backend: the Vision framework's `VNRecognizeTextRequest`, run
/// on-device, no network (Constitution Art. 1/11). Ships with macOS — no
/// model pack to fetch, sign, or vendor, same reasoning as
/// `NLEmbeddingProvider` for `embed`. `manifest.packData` stays unused on
/// this path for the same reason.
public struct VisionOCRProvider: Sendable {
    /// One recognized text run. `boundingBox` is Vision's normalized rect
    /// (origin bottom-left) — the caller (`VisionAdapter`) converts to
    /// `InferenceAPI.NormalizedRect`'s origin-top-left convention.
    public struct TextRun {
        public let text: String
        public let boundingBox: CGRect
        public let confidence: Double
    }

    public init() {}

    /// Decodes `imageData`, applies a contrast-normalization pass for
    /// photo-input tolerance (PRD FR-1.7), then runs Vision text
    /// recognition. Never fabricates a result for undecodable input —
    /// throws `.adapterFailure` instead (CLAUDE.md §2 honest failure); an
    /// empty result is a legitimate outcome for a decodable image with no
    /// recognizable text.
    public func recognizeText(in imageData: Data) throws -> [TextRun] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw InferenceError.adapterFailure(reason: "could not decode imageData as an image")
        }

        let preprocessed = Self.normalizeContrast(cgImage) ?? cgImage

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: preprocessed, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation in
            guard let top = observation.topCandidates(1).first else { return nil }
            return TextRun(text: top.string, boundingBox: observation.boundingBox, confidence: Double(top.confidence))
        }
    }

    /// Deskew/contrast preprocessing stage for phone-photo input tolerance.
    /// `CIColorControls` boosts contrast modestly; a `nil` return (filter
    /// unavailable or output has no extent) falls back to the original
    /// image rather than failing the whole request over a best-effort step.
    static func normalizeContrast(_ image: CGImage) -> CGImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        let ciImage = CIImage(cgImage: image)
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.1, forKey: kCIInputContrastKey)
        guard let output = filter.outputImage, !output.extent.isInfinite else { return nil }
        let context = CIContext()
        return context.createCGImage(output, from: output.extent)
    }
}
