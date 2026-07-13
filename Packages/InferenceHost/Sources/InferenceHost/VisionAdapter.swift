import Foundation
import InferenceAPI

/// Real Vision-framework OCR adapter (ARCHITECTURE.md §7.1) — `manifest`
/// stays unused on purpose (same reasoning as `CoreMLAdapter.embed`): Vision
/// text recognition is an OS capability, not registry-loaded packData.
public struct VisionAdapter: Sendable {
    private let provider: VisionOCRProvider

    public init(provider: VisionOCRProvider = VisionOCRProvider()) {
        self.provider = provider
    }

    public func ocr(_ request: OCRRequest, manifest: ModelManifest) async throws -> OCRResponse {
        guard !request.imageData.isEmpty else {
            throw InferenceError.adapterFailure(reason: "empty imageData")
        }
        let recognized = try provider.recognizeText(in: request.imageData)
        let regions = recognized.map { run -> OCRTextRegion in
            // Vision's boundingBox is normalized with origin bottom-left;
            // NormalizedRect's convention (InferenceAPI) is origin top-left.
            let flippedY = 1 - run.boundingBox.origin.y - run.boundingBox.height
            return OCRTextRegion(
                text: run.text,
                boundingBox: NormalizedRect(
                    x: run.boundingBox.origin.x,
                    y: flippedY,
                    width: run.boundingBox.width,
                    height: run.boundingBox.height
                ),
                confidence: run.confidence
            )
        }
        return OCRResponse(regions: regions)
    }
}
