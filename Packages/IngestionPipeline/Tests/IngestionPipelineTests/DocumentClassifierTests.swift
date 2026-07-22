import XCTest
import PDFEngineAPI
@testable import IngestionPipeline

/// Golden-set-shaped: one case per `DocumentType`, asserting the classifier
/// trusts a confident real response for every label in the closed set, plus
/// the two degradation paths (Acceptance Criteria: "misclassification
/// routes to generic extractor, never a crash").
final class DocumentClassifierTests: XCTestCase {
    private func pngPage() -> NormalizedPage {
        let png = PNGEncoder.encode(rgba: Data(count: 4), width: 1, height: 1)
        return NormalizedPage(index: PageIndex(0), imageData: png)
    }

    func testEveryDocumentTypeIsTrustedAtHighConfidence() async {
        for type in DocumentType.allCases {
            let mock = MockInferenceClient(behavior: .respond(label: type.rawValue, confidence: 0.95))
            let classifier = DocumentClassifier(inferenceClient: mock)

            let result = await classifier.classify(pngPage())

            XCTAssertEqual(result.type, type)
            XCTAssertFalse(result.isFallback)
        }
    }

    func testLowConfidenceRealResponseDegradesToGenericFallback() async {
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.passport.rawValue, confidence: 0.2))
        let classifier = DocumentClassifier(inferenceClient: mock)

        let result = await classifier.classify(pngPage())

        XCTAssertEqual(result.type, .generic)
        XCTAssertTrue(result.isFallback)
    }

    func testEndpointUnavailableDegradesToGenericFallbackWithoutThrowing() async {
        let mock = MockInferenceClient(behavior: .fail)
        let classifier = DocumentClassifier(inferenceClient: mock)

        let result = await classifier.classify(pngPage())

        XCTAssertEqual(result.type, .generic)
        XCTAssertTrue(result.isFallback)
    }

    func testPageWithNoImageDataDegradesToGenericWithoutCallingEndpoint() async {
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.passport.rawValue, confidence: 0.99))
        let classifier = DocumentClassifier(inferenceClient: mock)
        let textOnlyPage = NormalizedPage(index: PageIndex(0), text: "hello")

        let result = await classifier.classify(textOnlyPage)

        XCTAssertEqual(result.type, .generic)
        let requestCount = await mock.receivedRequests.count
        XCTAssertEqual(requestCount, 0)
    }

    /// Determinism: same input, same (deterministic) inference client ->
    /// same output, every time.
    func testClassificationIsDeterministicGivenSameInputAndClient() async {
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.license.rawValue, confidence: 0.8))
        let classifier = DocumentClassifier(inferenceClient: mock)
        let page = pngPage()

        let first = await classifier.classify(page)
        let second = await classifier.classify(page)
        let third = await classifier.classify(page)

        let expected = DocumentClassification(type: .license, confidence: 0.8)
        XCTAssertEqual([first, second, third], [expected, expected, expected])
    }

    func testConstrainedChoiceSendsExactlyTheSevenDocumentTypeLabels() async {
        let mock = MockInferenceClient(behavior: .respond(label: DocumentType.generic.rawValue, confidence: 0.9))
        let classifier = DocumentClassifier(inferenceClient: mock)

        _ = await classifier.classify(pngPage())

        let requests = await mock.receivedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(Set(requests[0].candidateLabels), Set(DocumentType.allCases.map(\.rawValue)))
    }
}
