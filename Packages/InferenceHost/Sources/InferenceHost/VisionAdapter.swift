import Foundation
import InferenceAPI

/// Stub for the real Vision-framework OCR/MRZ/barcode adapter
/// (ARCHITECTURE.md §7.1) — real recognition lands in P1-13. Returns a
/// structurally valid, deterministic result so the registry/router/governor
/// plumbing around it is exercisable end-to-end before the real model is
/// wired.
public struct VisionAdapter: Sendable {
    public init() {}

    public func ocr(_ request: OCRRequest, manifest: ModelManifest) async throws -> OCRResponse {
        guard !request.imageData.isEmpty else {
            throw InferenceError.adapterFailure(reason: "empty imageData")
        }
        return OCRResponse(regions: [
            OCRTextRegion(
                text: "STUB_OCR_TEXT",
                boundingBox: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                confidence: 0.5
            )
        ])
    }
}
