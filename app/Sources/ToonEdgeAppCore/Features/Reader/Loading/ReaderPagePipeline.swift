import Combine
import Foundation

@MainActor
public final class ReaderPagePipeline: ObservableObject {
    @Published public private(set) var states: [Int: ReaderPageState]
    public let sessionID: UUID

    private let imageURLs: [URL]
    private let sourceURL: URL
    private let requestContext: ReaderImageRequestContext?
    private let assetLoader: any ReaderPageAssetLoading
    private let decoder: any ReaderImageDecoding
    private let policy: ReaderPrefetchPolicy
    private var generation = UUID()
    private var isCancelled = false
    private var lastRevisionByIndex: [Int: Int] = [:]

    private lazy var coordinator = ReaderPageWorkCoordinator(
        imageURLs: imageURLs,
        sourceURL: sourceURL,
        requestContext: requestContext,
        assetLoader: assetLoader,
        decoder: decoder,
        policy: policy,
        generation: generation,
        publish: { [weak self] index, state, generation, revision in
            await self?.apply(index: index, state: state, generation: generation, revision: revision)
        }
    )

    public init(
        session: MockReaderSession,
        assetLoader: any ReaderPageAssetLoading = DefaultReaderPageAssetLoader(),
        decoder: any ReaderImageDecoding = ImageIOReaderImageDecoder(),
        policy: ReaderPrefetchPolicy = .init(behind: 1, ahead: 2, maximumConcurrentLoads: 3)
    ) {
        sessionID = session.id
        imageURLs = session.imageURLs
        sourceURL = session.sourceURL
        requestContext = session.imageRequestContext
        self.assetLoader = assetLoader
        self.decoder = decoder
        self.policy = policy
        states = Dictionary(uniqueKeysWithValues: session.imageURLs.indices.map {
            ($0, ReaderPageState(status: .idle, image: nil, failure: nil))
        })
    }

    public func updateVisibleIndex(_ index: Int) {
        guard !isCancelled, imageURLs.indices.contains(index) else { return }
        let coordinator = coordinator
        let generation = generation
        Task { await coordinator.reprioritize(visibleIndex: index, generation: generation) }
    }

    /// Prioritize every visible page, then the existing small prefetch margins.
    public func updateVisibleIndexes(_ indexes: [Int], loadingAnchorIndex: Int) {
        guard !isCancelled, imageURLs.indices.contains(loadingAnchorIndex) else { return }
        let visible = Array(Set(indexes.filter { imageURLs.indices.contains($0) })).sorted()
        guard !visible.isEmpty else { return }
        let coordinator = coordinator
        let generation = generation
        Task { await coordinator.reprioritize(visibleIndexes: visible,
            loadingAnchorIndex: loadingAnchorIndex, generation: generation) }
    }

    #if DEBUG
    /// Read-only coordinator observation for explicitly enabled owned native tests.
    func debugPeakActiveLoadCount() async -> Int { await coordinator.observedPeakActiveLoadCount() }
    #endif

    public func retry(index: Int) {
        guard !isCancelled, imageURLs.indices.contains(index) else { return }
        let coordinator = coordinator
        let generation = generation
        Task { await coordinator.retry(index: index, generation: generation) }
    }

    public func handleMemoryPressure() {
        guard !isCancelled else { return }
        let coordinator = coordinator
        let generation = generation
        Task { await coordinator.reduceToVisibleWork(generation: generation) }
    }

    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        generation = UUID()
        for index in states.keys {
            states[index] = ReaderPageState(status: .idle, image: nil, failure: nil)
        }
        let coordinator = coordinator
        let generation = generation
        Task { await coordinator.cancelAll(newGeneration: generation) }
    }

    func waitForWorkToDrain() async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while await coordinator.hasActiveWork(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return !(await coordinator.hasActiveWork())
    }

    private func apply(index: Int, state: ReaderPageState, generation: UUID, revision: Int) {
        guard !isCancelled, generation == self.generation,
              revision > lastRevisionByIndex[index, default: 0] else { return }
        lastRevisionByIndex[index] = revision
        states[index] = state
    }
}

private actor ReaderPageWorkCoordinator {
    typealias Publisher = @Sendable (Int, ReaderPageState, UUID, Int) async -> Void

    private struct ActiveWork {
        let token: UUID
        let task: Task<Void, Never>
        var isCancelling: Bool
    }

    private let imageURLs: [URL]
    private let sourceURL: URL
    private let requestContext: ReaderImageRequestContext?
    private let assetLoader: any ReaderPageAssetLoading
    private let decoder: any ReaderImageDecoding
    private let policy: ReaderPrefetchPolicy
    private let publish: Publisher

    private var generation: UUID
    private var visibleIndex: Int?
    private var visibleIndexes: [Int] = []
    private var targetIndexes: [Int] = []
    private var queuedIndexes: [Int] = []
    private var activeByURL: [URL: ActiveWork] = [:]
    #if DEBUG
    private var peakActiveLoadCount = 0
    func observedPeakActiveLoadCount() -> Int { peakActiveLoadCount }
    #endif
    private var decodedByURL: [URL: ReaderDecodedImage] = [:]
    private var states: [Int: ReaderPageState] = [:]
    private var revision = 0

    init(
        imageURLs: [URL],
        sourceURL: URL,
        requestContext: ReaderImageRequestContext?,
        assetLoader: any ReaderPageAssetLoading,
        decoder: any ReaderImageDecoding,
        policy: ReaderPrefetchPolicy,
        generation: UUID,
        publish: @escaping Publisher
    ) {
        self.imageURLs = imageURLs
        self.sourceURL = sourceURL
        self.requestContext = requestContext
        self.assetLoader = assetLoader
        self.decoder = decoder
        self.policy = policy
        self.generation = generation
        self.publish = publish
    }

    func reprioritize(visibleIndex: Int, generation: UUID) {
        guard generation == self.generation, imageURLs.indices.contains(visibleIndex) else { return }
        self.visibleIndex = visibleIndex
        self.visibleIndexes = [visibleIndex]
        setTargets(policy.targetIndexes(current: visibleIndex, pageCount: imageURLs.count))
    }

    func reprioritize(visibleIndexes: [Int], loadingAnchorIndex: Int, generation: UUID) {
        guard generation == self.generation, imageURLs.indices.contains(loadingAnchorIndex) else { return }
        let visible = Array(Set(visibleIndexes.filter { imageURLs.indices.contains($0) })).sorted()
        guard let first = visible.first, let last = visible.last else { return }
        self.visibleIndex = loadingAnchorIndex
        self.visibleIndexes = visible
        let ahead = policy.targetIndexes(current: last, pageCount: imageURLs.count).filter { $0 > last }
        let behind = policy.targetIndexes(current: first, pageCount: imageURLs.count).filter { $0 < first }
        setTargets(visible + ahead + behind)
    }

    func reduceToVisibleWork(generation: UUID) {
        guard generation == self.generation, let visibleIndex else { return }
        setTargets(visibleIndexes.isEmpty ? [visibleIndex] : visibleIndexes)
    }

    func retry(index: Int, generation: UUID) {
        guard generation == self.generation, imageURLs.indices.contains(index),
              targetIndexes.contains(index), state(at: index).status == .failed else { return }
        let url = imageURLs[index]
        for target in targetIndexes where imageURLs[target] == url && state(at: target).status == .failed {
            setState(.queued, at: target)
        }
        refreshQueueAndStart()
    }

    func cancelAll(newGeneration: UUID) {
        generation = newGeneration
        visibleIndex = nil
        visibleIndexes = []
        targetIndexes = []
        queuedIndexes = []
        decodedByURL.removeAll()
        for (url, var work) in activeByURL {
            work.isCancelling = true
            work.task.cancel()
            activeByURL[url] = work
        }
        states.removeAll()
    }

    func hasActiveWork() -> Bool {
        !activeByURL.isEmpty
    }

    private func setTargets(_ indexes: [Int]) {
        targetIndexes = indexes
        let targetSet = Set(indexes)
        let targetURLs = Set(indexes.map { imageURLs[$0] })

        for index in states.keys where !targetSet.contains(index) {
            if state(at: index).status != .failed {
                setState(.idle, at: index)
            }
        }
        decodedByURL = decodedByURL.filter { targetURLs.contains($0.key) }

        for (url, var work) in activeByURL where !targetURLs.contains(url) && !work.isCancelling {
            work.isCancelling = true
            work.task.cancel()
            activeByURL[url] = work
        }

        for index in indexes {
            let current = state(at: index)
            if let image = decodedByURL[imageURLs[index]] {
                setState(.ready, image: image, at: index)
            } else if current.status == .idle {
                setState(.queued, at: index)
            }
        }
        refreshQueueAndStart()
    }

    private func refreshQueueAndStart() {
        queuedIndexes = targetIndexes.filter { state(at: $0).status == .queued }
        for index in queuedIndexes {
            let url = imageURLs[index]
            if let work = activeByURL[url], !work.isCancelling {
                setState(.loading, at: index)
            }
        }
        queuedIndexes = targetIndexes.filter { state(at: $0).status == .queued }

        let concurrencyLimit = min(3, max(1, policy.maximumConcurrentLoads))
        while activeByURL.count < concurrencyLimit,
              let index = queuedIndexes.first(where: { activeByURL[imageURLs[$0]] == nil }) {
            let url = imageURLs[index]
            let duplicateIndexes = queuedIndexes.filter { imageURLs[$0] == url }
            for duplicate in duplicateIndexes { setState(.loading, at: duplicate) }
            queuedIndexes.removeAll { imageURLs[$0] == url }

            let token = UUID()
            let launchGeneration = generation
            let loader = assetLoader
            let decoder = decoder
            let sourceURL = sourceURL
            let requestContext = requestContext
            let task = Task {
                let result: Result<ReaderDecodedImage, ReaderPageFailure>
                do {
                    let data = try await loader.load(
                        imageURL: url,
                        sourceURL: sourceURL,
                        requestContext: requestContext
                    )
                    try Task.checkCancellation()
                    let image = try await decoder.decode(data)
                    try Task.checkCancellation()
                    result = .success(image)
                } catch {
                    if let failure = error as? ReaderPageFailure {
                        result = .failure(failure)
                    } else if error is ReaderImageDecodeError {
                        result = .failure(.decode)
                    } else {
                        result = .failure(.network)
                    }
                }
                self.finish(url: url, token: token, generation: launchGeneration, result: result)
            }
            activeByURL[url] = ActiveWork(token: token, task: task, isCancelling: false)
            #if DEBUG
            peakActiveLoadCount = max(peakActiveLoadCount, activeByURL.count)
            #endif
        }
    }

    private func finish(
        url: URL,
        token: UUID,
        generation: UUID,
        result: Result<ReaderDecodedImage, ReaderPageFailure>
    ) {
        guard let work = activeByURL[url], work.token == token else { return }
        activeByURL[url] = nil
        if generation == self.generation && !work.isCancelling {
            let affectedIndexes = targetIndexes.filter { imageURLs[$0] == url }
            if !affectedIndexes.isEmpty {
                switch result {
                case .success(let image):
                    decodedByURL[url] = image
                    for index in affectedIndexes { setState(.ready, image: image, at: index) }
                case .failure(let failure):
                    for index in affectedIndexes { setState(.failed, failure: failure, at: index) }
                }
            }
        }
        refreshQueueAndStart()
    }

    private func state(at index: Int) -> ReaderPageState {
        states[index] ?? ReaderPageState(status: .idle, image: nil, failure: nil)
    }

    private func setState(
        _ status: ReaderPageStatus,
        image: ReaderDecodedImage? = nil,
        failure: ReaderPageFailure? = nil,
        at index: Int
    ) {
        let prior = state(at: index)
        if prior.status == status && prior.image == nil && image == nil && prior.failure == failure { return }
        let learnedMetadata = image.map {
            ReaderPageMetadata(pixelWidth: Double($0.pixelWidth), pixelHeight: Double($0.pixelHeight))
        } ?? prior.learnedMetadata
        let state = ReaderPageState(
            status: status, image: image, failure: failure, learnedMetadata: learnedMetadata
        )
        states[index] = state
        revision += 1
        let revision = revision
        let generation = generation
        Task { await publish(index, state, generation, revision) }
    }
}
