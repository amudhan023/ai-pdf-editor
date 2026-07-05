import Foundation
import InferenceAPI

/// The real (registry + router + governor + adapter-backed) `InferenceClient`
/// — the "real service" leg of P1-12's acceptance criteria. Adapters are
/// stubbed (P1-13+ replaces their internals with real Vision/Core ML/
/// FoundationModels calls); the plumbing around them — capability→model
/// lookup, priority routing, memory accounting — is real and exercised by
/// `InferenceConformanceSuite` the same as `FakeInferenceClient`.
public actor InferenceHostClient: InferenceClient {
    private let registry: ModelRegistry
    private let router: InferenceRouter
    private let governor: MemoryGovernor
    private let hardwareTier: HardwareTier
    private let visionAdapter: VisionAdapter
    private let coreMLAdapter: CoreMLAdapter
    private let foundationModelsAdapter: FoundationModelsAdapter

    public init(
        registry: ModelRegistry,
        router: InferenceRouter = InferenceRouter(),
        governor: MemoryGovernor,
        hardwareTier: HardwareTier = HardwareTierDetector.current(),
        visionAdapter: VisionAdapter = VisionAdapter(),
        coreMLAdapter: CoreMLAdapter = CoreMLAdapter(),
        foundationModelsAdapter: FoundationModelsAdapter = FoundationModelsAdapter()
    ) {
        self.registry = registry
        self.router = router
        self.governor = governor
        self.hardwareTier = hardwareTier
        self.visionAdapter = visionAdapter
        self.coreMLAdapter = coreMLAdapter
        self.foundationModelsAdapter = foundationModelsAdapter
    }

    public func ocr(_ request: OCRRequest) async throws -> OCRResponse {
        let adapter = visionAdapter
        return try await dispatch(.ocr, priority: request.priority) { manifest in
            try await adapter.ocr(request, manifest: manifest)
        }
    }

    public func classify(_ request: ClassifyRequest) async throws -> ClassifyResponse {
        let adapter = coreMLAdapter
        return try await dispatch(.classify, priority: request.priority) { manifest in
            try await adapter.classify(request, manifest: manifest)
        }
    }

    public func extractEntities(_ request: ExtractEntitiesRequest) async throws -> ExtractEntitiesResponse {
        let adapter = coreMLAdapter
        return try await dispatch(.extractEntities, priority: request.priority) { manifest in
            try await adapter.extractEntities(request, manifest: manifest)
        }
    }

    public func embed(_ request: EmbedRequest) async throws -> EmbedResponse {
        let adapter = coreMLAdapter
        return try await dispatch(.embed, priority: request.priority) { manifest in
            try await adapter.embed(request, manifest: manifest)
        }
    }

    public func generate(_ request: GenerateRequest) async throws -> GenerateResponse {
        let adapter = foundationModelsAdapter
        return try await dispatch(.generate, priority: request.priority) { manifest in
            try await adapter.generate(request, manifest: manifest)
        }
    }

    private func dispatch<T: Sendable>(
        _ capability: InferenceCapability,
        priority: InferencePriority,
        _ work: @Sendable @escaping (ModelManifest) async throws -> T
    ) async throws -> T {
        guard let manifest = await registry.bestModel(for: capability, tier: hardwareTier) else {
            throw InferenceError.capabilityUnavailable(capability, hardwareTier)
        }
        try await governor.ensureLoaded(modelID: manifest.modelID, estimatedBytes: manifest.estimatedMemoryBytes)
        switch priority {
        case .interactive:
            return try await router.runInteractive { try await work(manifest) }
        case .background:
            return try await router.runBackground { try await work(manifest) }
        }
    }
}
