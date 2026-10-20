#if canImport(UIKit)
import Foundation
import UIKit
import Combine

enum ReaderSurfaceCommand: Equatable {
    case reset, enlarge, shrink
    #if DEBUG
    case first, middle, last
    #endif
}

/// One native chapter scroll owner; the injected pipeline remains VM-owned.
@MainActor
final class ReaderSurfaceViewController: UIViewController,
    UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public let sessionID: UUID
    var onSingleTap: (() -> Void)?
    var onBaselineSelection: ((ReaderViewportSelection) -> Void)?
    var restoreIndex: (() async -> Int)?

    private let session: MockReaderSession
    private let pipeline: ReaderPagePipeline
    private let pipelineIdentity: UUID
    private var contract: ReaderSurfaceContract
    private var settings: ReaderSettings
    private var foreground: UIColor = .white
    private var background: UIColor = .black
    private var subscription: AnyCancellable?
    private var stopped = false
    private var restoreTask: Task<Void, Never>?
    private var restoreFinished = false
    private var effectiveMetadata: [ReaderPageMetadata?] = []
    private var geometryRevision: UInt64 = 0
    private var lastLoadingIndexes: [Int] = []
    private var lastSelection: ReaderViewportSelection?
    private let diagnostic = UILabel()
    #if DEBUG
    // Observation only: never feeds recognizer, presentation, or policy state.
    private let pinchTraceDiagnostic = UILabel()
    private var pinchTraceSamples: [[String: Any]] = []
    private var pinchTraceCounts = [Int](repeating: 0, count: 4)
    private var pinchTraceGesture = 0
    private var pinchTraceActive = false
    private var pinchTraceGestureOverflow = false
    private var pinchTraceSampleOverflow = false
    private var pinchTraceLifecycleIncomplete = false
    #endif
    private var peakLoading = 0
    private var relayoutErrorX: CGFloat?
    private var relayoutErrorY: CGFloat?
    private var measurementGeometryRevision: UInt64?
    private var pinchSampleCount = 0
    private var pinchHeld = false
    private var pinchBelow = false
    private var pageCount: Int { session.imageURLs.count }
    private var diagnosticsEnabled: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-uiTesting") && args.contains("-readerIntegratedZoomFixture")
        #else
        return false
        #endif
    }
    private let scroll = UIScrollView()
    private let canvas = UIView()
    private var state: ReaderZoomState?
    private var pages: [Int: ReaderSurfacePageView] = [:]
    private var applying = false
    private var canvasShift = CGPoint.zero
    private var createdCount = 0
    private var reusedCount = 0
    private var lastSnapshot = ""
    private var pinch: UIPinchGestureRecognizer!

    init(session: MockReaderSession, pipeline: ReaderPagePipeline) {
        self.sessionID = session.id
        self.session = session
        self.pipeline = pipeline
        self.settings = session.settings
        let identity = UUID()
        self.pipelineIdentity = identity
        self.contract = ReaderSurfaceContract(sessionID: session.id, pipelineID: identity)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic reader surface") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scroll.frame = view.bounds
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.backgroundColor = .black
        scroll.delegate = self
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.bounces = false
        scroll.alwaysBounceHorizontal = false
        scroll.alwaysBounceVertical = false
        scroll.isDirectionalLockEnabled = false
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 1
        scroll.pinchGestureRecognizer?.isEnabled = false
        scroll.accessibilityIdentifier = "reader.readingSurface"
        scroll.panGestureRecognizer.maximumNumberOfTouches = 1
        scroll.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
        view.addSubview(scroll)
        canvas.backgroundColor = .black
        scroll.addSubview(canvas)

        pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchChanged(_:)))
        pinch.delegate = self
        scroll.addGestureRecognizer(pinch)
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        double.numberOfTapsRequired = 2
        double.require(toFail: pinch)
        double.require(toFail: scroll.panGestureRecognizer)
        scroll.addGestureRecognizer(double)
        let single = UITapGestureRecognizer(target: self, action: #selector(singleTapped(_:)))
        single.require(toFail: double)
        single.require(toFail: pinch)
        single.require(toFail: scroll.panGestureRecognizer)
        scroll.addGestureRecognizer(single)
        single.delegate = self
        double.delegate = self
        if diagnosticsEnabled {
            diagnostic.isAccessibilityElement = true
            diagnostic.accessibilityIdentifier = "reader.zoom.status"
            diagnostic.accessibilityLabel = "Reader zoom diagnostic status"
            diagnostic.font = .systemFont(ofSize: 1)
            diagnostic.text = " "
            diagnostic.isUserInteractionEnabled = false
            view.addSubview(diagnostic)
        }
        #if DEBUG
        if diagnosticsEnabled {
            pinchTraceDiagnostic.isAccessibilityElement = true
            pinchTraceDiagnostic.accessibilityIdentifier = "reader.zoom.pinchTrace"
            pinchTraceDiagnostic.accessibilityLabel = "Owned native pinch trace"
            pinchTraceDiagnostic.font = .systemFont(ofSize: 1)
            pinchTraceDiagnostic.text = " "
            pinchTraceDiagnostic.isUserInteractionEnabled = false
            view.addSubview(pinchTraceDiagnostic)
            publishPinchTrace()
        }
        #endif
        subscription = pipeline.$states.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.stopped else { return }
                #if DEBUG
                if self.diagnosticsEnabled {
                    self.peakLoading = await self.pipeline.debugPeakActiveLoadCount()
                }
                #endif
                guard !self.stopped else { return }
                self.refreshGeometry()
                self.reconcilePages()
                self.reportViewport()
                self.publishSnapshot()
            }
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !applying, view.bounds.width > 0, view.bounds.height > 24 else { return }
        diagnostic.frame = CGRect(x: 0, y: view.bounds.height - 2, width: 2, height: 2)
        #if DEBUG
        if diagnosticsEnabled {
            pinchTraceDiagnostic.frame = CGRect(x: 2, y: view.bounds.height - 2, width: 2, height: 2)
        }
        #endif
        refreshGeometry()
        if restoreTask == nil && !restoreFinished, let restoreIndex {
            let token = contract.restoreToken
            restoreTask = Task { @MainActor [weak self] in
                let index = await restoreIndex()
                guard let self, !self.stopped, !Task.isCancelled else { return }
                self.restoreFinished = true
                if self.contract.acceptsRestore(token) { self.state?.jump(to: index) }
                self.applyPresentation()
            }
        }
    }

    func configure(settings: ReaderSettings, foreground: UIColor, background: UIColor) {
        self.settings = settings
        self.foreground = foreground
        self.background = background
        guard isViewLoaded else { return }
        view.backgroundColor = background
        scroll.backgroundColor = background
        canvas.backgroundColor = background
        refreshGeometry()
        reconcilePages()
    }

    private func refreshGeometry() {
        guard !stopped, isViewLoaded, view.bounds.width > 0, view.bounds.height > 0, !applying else { return }
        let metadata = session.imageURLs.indices.map { index -> ReaderPageMetadata? in
            ReaderEffectivePageMetadata.resolve(learned: pipeline.states[index]?.learnedMetadata,
                declared: session.pageMetadata.indices.contains(index) ? session.pageMetadata[index] : nil)
        }
        let spacing: CGFloat = settings.isPageSpacingEnabled ? ToonEdgeSpacing.small : 0
        guard let old = state?.layout,
              old.viewportSize == view.bounds.size,
              metadata == effectiveMetadata,
              configuredDisplayMode == settings.displayMode,
              configuredSpacing == spacing else {
            geometryRevision &+= 1
            guard let layout = ReaderFittedLayout(sessionID: sessionID, revision: geometryRevision,
                viewportSize: view.bounds.size, displayMode: settings.displayMode,
                pageSpacing: spacing, metadata: metadata) else { return }
            relayoutErrorX = nil
            relayoutErrorY = nil
            measurementGeometryRevision = nil
            let probe = nativeRelayoutProbe(nextSize: layout.viewportSize)
            if state == nil { state = ReaderZoomState(layout: layout) }
            else if state?.relayout(layout) != true { return }
            effectiveMetadata = metadata
            configuredDisplayMode = settings.displayMode
            configuredSpacing = spacing
            applyPresentation()
            if let probe, let actual = measuredPoint(for: probe) {
                relayoutErrorX = abs(actual.x - probe.viewportPoint.x)
                relayoutErrorY = abs(actual.y - probe.viewportPoint.y)
                measurementGeometryRevision = state?.layout.geometry.revision
            }
            publishSnapshot()
            return
        }
    }
    private func nativeRelayoutProbe(nextSize: CGSize) -> ReaderZoomAnchor? {
        guard let state, let presentation = state.presentation else { return nil }
        let anchor: ReaderSemanticAnchor
        let oldPoint: CGPoint
        if state.isPinching, let focal = state.focalAnchor,
           let target = state.focalViewportPoint {
            anchor = focal
            oldPoint = target
        } else {
            guard let index = state.visibleIndexes.first else { return nil }
            let frame = state.layout.geometry.pageFrames[index].intersection(presentation.logicalViewport)
            guard !frame.isNull, let sample = state.layout.geometry.anchor(at:
                CGPoint(x: frame.midX, y: frame.midY)),
                let measured = measuredPoint(for: ReaderZoomAnchor(anchor: sample, viewportPoint: .zero))
                else { return nil }
            anchor = sample
            oldPoint = measured
        }
        return ReaderZoomAnchor(anchor: anchor, viewportPoint: CGPoint(
            x: oldPoint.x / state.layout.viewportSize.width * nextSize.width,
            y: oldPoint.y / state.layout.viewportSize.height * nextSize.height))
    }

    private var configuredDisplayMode: ReaderDisplayMode?
    private var configuredSpacing: CGFloat?

    func stop() {
        stopped = true
        restoreTask?.cancel()
        restoreTask = nil
        subscription = nil
        state?.cancelPinch()
        state?.endPan(cancelled: false)
        for page in pages.values { page.prepareForReuse() }
        pages.values.forEach { $0.removeFromSuperview() }
        pages.removeAll()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if state?.isPinching == true {
            state?.cancelPinch()
            scroll.panGestureRecognizer.isEnabled = true
            applyPresentation()
        }
    }

    public func perform(_ command: ReaderSurfaceCommand) {
        guard let state else { return }
        contract.userDidInteract()
        scroll.setContentOffset(scroll.contentOffset, animated: false)
        if state.isPinching {
            pinch.isEnabled = false
            pinch.isEnabled = true
            scroll.panGestureRecognizer.isEnabled = true
        }
        self.state?.endPan(cancelled: false)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        switch command {
        case .reset: self.state?.reset()
        case .enlarge: self.state?.inspect(scale: 2, at: center)
        case .shrink: self.state?.inspect(scale: 0.75, at: center)
        #if DEBUG
        case .first: self.state?.jump(to: 0)
        case .middle: self.state?.jump(to: pageCount / 2)
        case .last: self.state?.jump(to: pageCount - 1)
        #endif
        }
        applyPresentation()
    }

    @objc private func pinchChanged(_ recognizer: UIPinchGestureRecognizer) {
        let point = recognizer.location(in: view)
        #if DEBUG
        // Capture native inputs before the original handler, and outcomes afterward.
        let tracePre = diagnosticsEnabled ? pinchTraceState(at: point) : nil
        let traceRawScale = Double(recognizer.scale)
        let traceNativeState = recognizer.state
        defer {
            if let tracePre {
                recordPinchTrace(nativeState: traceNativeState, rawScale: traceRawScale,
                    point: point, pre: tracePre)
            }
        }
        #endif
        switch recognizer.state {
        case .began:
            contract.userDidInteract()
            scroll.setContentOffset(scroll.contentOffset, animated: false)
            synchronizeNativeOffset()
            state?.endPan(cancelled: false)
            scroll.panGestureRecognizer.isEnabled = false
            state?.beginPinch(at: point)
            pinchSampleCount = 0
            pinchHeld = false
            pinchBelow = false
            publishSnapshot()
        case .changed:
            state?.updatePinch(magnification: Double(recognizer.scale), at: point)
            pinchSampleCount += 1
            if state?.presentation?.scale == 1 { pinchHeld = true }
            if pinchHeld, (state?.presentation?.scale ?? 1) < 1 { pinchBelow = true }
            applyPresentation()
        case .ended:
            state?.endPinch()
            scroll.panGestureRecognizer.isEnabled = true
            applyPresentation()
        case .cancelled, .failed:
            state?.cancelPinch()
            scroll.panGestureRecognizer.isEnabled = true
            applyPresentation()
        default: break
        }
    }

    #if DEBUG
    private func pinchTraceNumber(_ value: Double?) -> Any {
        guard let value, value.isFinite else { return NSNull() }
        return value
    }

    private func pinchTraceState(at point: CGPoint) -> [String: Any] {
        let size = state?.layout.viewportSize
        let inside = point.x.isFinite && point.y.isFinite && size.map {
            (0...$0.width).contains(point.x) && (0...$0.height).contains(point.y)
        } == true
        return [
            "stateAvailable": state != nil,
            "scale": pinchTraceNumber(state?.presentation.map { Double($0.scale) }),
            "isPinching": state?.isPinching == true,
            "geometryRevision": state.map { $0.layout.geometry.revision } as Any? ?? NSNull(),
            "viewportWidth": pinchTraceNumber(size.map { Double($0.width) }),
            "viewportHeight": pinchTraceNumber(size.map { Double($0.height) }),
            "insideViewport": inside,
            "focalAvailable": state?.focalPoint != nil,
            "focalAnchorAvailable": state?.focalAnchor != nil,
            "focalViewportAvailable": state?.focalViewportPoint != nil,
            "focalX": pinchTraceNumber(state?.focalPoint.map { Double($0.x) }),
            "focalY": pinchTraceNumber(state?.focalPoint.map { Double($0.y) }),
            "focalViewportX": pinchTraceNumber(state?.focalViewportPoint.map { Double($0.x) }),
            "focalViewportY": pinchTraceNumber(state?.focalViewportPoint.map { Double($0.y) })
        ]
    }

    private func recordPinchTrace(nativeState: UIGestureRecognizer.State,
                                  rawScale: Double, point: CGPoint, pre: [String: Any]) {
        guard diagnosticsEnabled else { return }
        let traceHadIssue = pinchTraceGestureOverflow || pinchTraceSampleOverflow ||
            pinchTraceLifecycleIncomplete
        if nativeState == .began {
            if pinchTraceActive { pinchTraceLifecycleIncomplete = true }
            pinchTraceGesture += 1
            pinchTraceActive = true
        } else if !pinchTraceActive {
            pinchTraceLifecycleIncomplete = true
        }
        let terminal = nativeState == .ended || nativeState == .cancelled || nativeState == .failed
        defer {
            if terminal { pinchTraceActive = false }
            let firstIssue = !traceHadIssue && (pinchTraceGestureOverflow ||
                pinchTraceSampleOverflow || pinchTraceLifecycleIncomplete)
            if nativeState == .began || terminal || firstIssue {
                // Publish lifecycle/first-failure boundaries, never ordinary changed samples.
                publishPinchTrace()
            }
        }
        guard (1...4).contains(pinchTraceGesture) else {
            pinchTraceGestureOverflow = true
            return
        }
        let index = pinchTraceGesture - 1
        guard pinchTraceCounts[index] < 512 else {
            pinchTraceSampleOverflow = true
            return
        }
        pinchTraceCounts[index] += 1
        let rawValid = rawScale.isFinite && rawScale > 0
        let updateEligible = pre["isPinching"] as? Bool == true &&
            pre["insideViewport"] as? Bool == true &&
            pre["focalAvailable"] as? Bool == true && rawValid
        pinchTraceSamples.append([
            "gestureID": pinchTraceGesture,
            "sampleID": pinchTraceCounts[index],
            // UIKit numeric states: began=1, changed=2, ended=3, cancelled=4, failed=5.
            "nativeState": nativeState.rawValue,
            "rawScale": pinchTraceNumber(rawScale),
            "rawScaleValid": rawValid,
            "locationX": pinchTraceNumber(Double(point.x)),
            "locationY": pinchTraceNumber(Double(point.y)),
            "locationFinite": point.x.isFinite && point.y.isFinite,
            "nativeViewportWidth": pinchTraceNumber(Double(view.bounds.width)),
            "nativeViewportHeight": pinchTraceNumber(Double(view.bounds.height)),
            "changedInputEligible": nativeState == .changed && updateEligible,
            "pre": pre,
            "post": pinchTraceState(at: point)
        ])
    }

    private func publishPinchTrace() {
        guard diagnosticsEnabled else { return }
        let value: [String: Any] = [
            "schemaVersion": 1,
            "session": sessionID.uuidString,
            "pipeline": pipelineIdentity.uuidString,
            "gestureLimit": 4, "sampleLimitPerGesture": 512,
            "gestureCount": pinchTraceGesture,
            "sampleCounts": pinchTraceCounts,
            "gestureOverflow": pinchTraceGestureOverflow,
            "sampleOverflow": pinchTraceSampleOverflow,
            "truncated": pinchTraceGestureOverflow || pinchTraceSampleOverflow,
            "lifecycleIncomplete": pinchTraceLifecycleIncomplete,
            "active": pinchTraceActive,
            "samples": pinchTraceSamples
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: bytes, encoding: .utf8) else { return }
        pinchTraceDiagnostic.accessibilityValue = text
    }
    #endif

    @objc private func panChanged(_ recognizer: UIPanGestureRecognizer) {
        guard !applying, state?.isPinching != true else { return }
        switch recognizer.state {
        case .began:
            contract.userDidInteract()
            synchronizeNativeOffset()
            state?.beginPan()
        case .ended:
            synchronizeNativeOffset()
            state?.endPan(cancelled: false)
            publishSnapshot()
        case .cancelled:
            state?.endPan(cancelled: true)
            applyPresentation()
        default: break
        }
    }

    @objc private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        contract.userDidInteract()
        synchronizeNativeOffset()
        state?.doubleTap(at: recognizer.location(in: view))
        applyPresentation()
    }

    @objc private func singleTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        contract.userDidInteract()
        onSingleTap?()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !applying, state?.isPinching != true else { return }
        synchronizeNativeOffset()
        reconcilePages()
        reconcileReset()
        reportViewport()
        publishSnapshot()
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        synchronizeNativeOffset()
        state?.endPan(cancelled: false)
        publishSnapshot()
    }

    private func synchronizeNativeOffset() {
        guard !applying, state?.isPinching != true else { return }
        state?.recordNativeTranslation(CGPoint(
            x: canvasShift.x - scroll.contentOffset.x,
            y: canvasShift.y - scroll.contentOffset.y))
    }

    private func applyPresentation() {
        guard !applying, let state else { return }
        guard let transform = state.presentation else {
            pages.values.forEach { $0.prepareForReuse(); $0.removeFromSuperview() }
            pages.removeAll()
            scroll.contentSize = view.bounds.size
            publishSnapshot()
            return
        }
        applying = true
        let scale = transform.scale
        canvasShift = CGPoint(x: max(0, transform.translation.x),
                              y: max(0, transform.translation.y))
        canvas.frame = CGRect(origin: .zero, size: CGSize(
            width: max(view.bounds.width, state.layout.contentSize.width * scale),
            height: max(view.bounds.height, state.layout.contentSize.height * scale)))
        scroll.contentSize = canvas.bounds.size
        reconcilePages()
        scroll.setContentOffset(CGPoint(x: max(0, -transform.translation.x),
                                        y: max(0, -transform.translation.y)), animated: false)
        scroll.layoutIfNeeded()
        applying = false
        reconcileReset()
        reportViewport()
        publishSnapshot()
    }

    private func reconcilePages() {
        guard let state else { return }
        let wanted = Set(state.materializedIndexes)
        var available: [ReaderSurfacePageView] = []
        for index in Array(pages.keys) where !wanted.contains(index) {
            if let page = pages.removeValue(forKey: index) {
                page.removeFromSuperview()
                page.prepareForReuse()
                available.append(page)
            }
        }
        let scale = state.presentation?.scale ?? 1
        for index in state.materializedIndexes {
            let page: ReaderSurfacePageView
            if let current = pages[index] {
                page = current
            } else if let reused = available.popLast() {
                page = reused
                reusedCount += 1
                pages[index] = page
                canvas.addSubview(page)
            } else {
                page = ReaderSurfacePageView()
                createdCount += 1
                pages[index] = page
                canvas.addSubview(page)
            }
            let logical = state.layout.geometry.pageFrames[index]
            page.frame = CGRect(x: logical.minX * scale + canvasShift.x,
                                y: logical.minY * scale + canvasShift.y,
                                width: logical.width * scale, height: logical.height * scale)
            page.configure(index: index, sessionID: sessionID, pipelineID: pipelineIdentity,
                state: pipeline.states[index], foreground: foreground, background: background,
                retryAction: { [weak self] in self?.pipeline.retry(index: index) })
            page.layoutIfNeeded()
        }
        // Unused detached views die here; there is no hidden retained reuse pool.
    }

    private func measuredPoint(for target: ReaderZoomAnchor) -> CGPoint? {
        guard target.anchor.sessionID == sessionID,
              let page = pages[target.anchor.pageIndex] else { return nil }
        return page.convert(CGPoint(x: page.bounds.width * target.anchor.unitPoint.x,
                                    y: page.bounds.height * target.anchor.unitPoint.y), to: view)
    }

    private func reconcileReset() {
        guard let request = state?.resetRequest,
              let actual = measuredPoint(for: request.target) else { return }
        _ = state?.acknowledgeReset(request, measuredPoint: actual)
    }

    private func countScrollOwners(in root: UIView) -> Int {
        (root is UIScrollView ? 1 : 0) +
            root.subviews.reduce(0) { $0 + countScrollOwners(in: $1) }
    }

    private func reportViewport() {
        guard let state, let transform = state.presentation else { return }
        let frames = Dictionary(uniqueKeysWithValues: state.materializedIndexes.map { index in
            let logical = state.layout.geometry.pageFrames[index]
            return (index, CGRect(x: logical.minX * transform.scale + transform.translation.x,
                y: logical.minY * transform.scale + transform.translation.y,
                width: logical.width * transform.scale, height: logical.height * transform.scale))
        })
        guard let selection = ReaderViewportPageSelector.selection(frames: frames,
            viewportHeight: view.bounds.height, pipelineID: ObjectIdentifier(pipeline),
            lastPageIndex: session.imageURLs.indices.last) else { return }
        // Loading follows inspection; baseline progress remains a separate callback.
        let loadingIndexes = state.visibleIndexes.isEmpty ? [selection.loadingAnchorIndex] : state.visibleIndexes
        if lastLoadingIndexes != loadingIndexes {
            lastLoadingIndexes = loadingIndexes
            pipeline.updateVisibleIndexes(loadingIndexes, loadingAnchorIndex: selection.loadingAnchorIndex)
        }
        guard restoreFinished, state.canReportBaseline else { return }
        guard lastSelection != selection else { return }
        lastSelection = selection
        onBaselineSelection?(selection)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var candidate = touch.view
        while let current = candidate {
            if current is UIControl { return false }
            candidate = current.superview
        }
        return true
    }

    private func publishSnapshot() {
        guard diagnosticsEnabled, let state else { return }
        var value: [String: Any] = [
            "session": sessionID.uuidString,
            "pipeline": pipelineIdentity.uuidString,
            "geometryRevision": state.layout.geometry.revision,
            "scale": Double(state.presentation?.scale ?? 1),
            "offsetX": Double(scroll.contentOffset.x), "offsetY": Double(scroll.contentOffset.y),
            "viewportWidth": Double(view.bounds.width), "viewportHeight": Double(view.bounds.height),
            "visible": state.visibleIndexes.count, "materialized": pages.count,
            "nativeContainers": canvas.subviews.count, "created": createdCount, "reused": reusedCount,
            "pageCount": pageCount, "pageIDs": pages.keys.sorted(),
            "scrollOwners": countScrollOwners(in: view), "pinching": state.isPinching,
            "resetReady": state.resetReconciled,
            "resetRequest": state.resetRequest?.id.uuidString ?? "",
            "peakLoading": peakLoading,
            "ready": pipeline.states.values.filter { $0.status == .ready }.count,
            "failed": pipeline.states.values.filter { $0.status == .failed }.count,
            "firstPageStatus": String(describing: pipeline.states[0]?.status ?? .idle),
            "firstPageReady": pipeline.states[0]?.status == .ready && pipeline.states[0]?.image != nil,
            "unresolved": state.layout.unresolvedPageIndexes.count,
            "restoreFinished": restoreFinished,
            "interaction": contract.interaction,
            "displayMode": settings.displayMode.rawValue,
            "spacing": settings.isPageSpacingEnabled,
            "pinchSamples": pinchSampleCount,
            "pinchHeld": pinchHeld, "pinchBelow": pinchBelow,
            "readyVisible": state.visibleIndexes.filter { pipeline.states[$0]?.status == .ready }.count,
            "visibleIDs": state.visibleIndexes
        ]
        if let relayoutErrorX, let relayoutErrorY {
            value["relayoutErrorX"] = Double(relayoutErrorX)
            value["relayoutErrorY"] = Double(relayoutErrorY)
            value["measurementGeometryRevision"] = measurementGeometryRevision
        }
        if let request = state.resetRequest, let actual = measuredPoint(for: request.target) {
            value["resetErrorX"] = Double(abs(actual.x - request.target.viewportPoint.x))
            value["resetErrorY"] = Double(abs(actual.y - request.target.viewportPoint.y))
            value["resetMeasuredX"] = Double(actual.x); value["resetMeasuredY"] = Double(actual.y)
            value["resetRequiredX"] = Double(request.target.viewportPoint.x)
            value["resetRequiredY"] = Double(request.target.viewportPoint.y)
        }
        if let anchor = state.focalAnchor, let expected = state.focalViewportPoint,
           let page = pages[anchor.pageIndex] {
            let actual = page.convert(CGPoint(x: page.bounds.width * anchor.unitPoint.x,
                y: page.bounds.height * anchor.unitPoint.y), to: view)
            value["focalErrorX"] = Double(abs(actual.x - expected.x))
            value["focalErrorY"] = Double(abs(actual.y - expected.y))
        }
        if let frozen = state.frozenReading, let actual = measuredPoint(for: frozen) {
            value["frozenPage"] = frozen.anchor.pageIndex
            value["frozenUnitX"] = Double(frozen.anchor.unitPoint.x)
            value["frozenUnitY"] = Double(frozen.anchor.unitPoint.y)
            value["frozenMeasuredX"] = Double(actual.x)
            value["frozenMeasuredY"] = Double(actual.y)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return }
        diagnostic.accessibilityValue = text
    }
}
#endif
