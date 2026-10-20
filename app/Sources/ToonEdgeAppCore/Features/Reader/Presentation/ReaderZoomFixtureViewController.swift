#if DEBUG && canImport(UIKit)
import Foundation
import UIKit

public enum ReaderZoomFixtureCommand: Equatable {
    case reset, enlarge, shrink, first, middle, last
}

/// Experimental presentation only. One native scroll owner; no repository or pipeline.
@MainActor
public final class ReaderZoomFixtureViewController: UIViewController,
    UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public let sessionID: UUID
    public var onSnapshot: ((String) -> Void)?
    public var onSingleTap: (() -> Void)?

    private let pageCount: Int
    private let scroll = UIScrollView()
    private let canvas = UIView()
    private var state: ReaderZoomFixtureState?
    private var pages: [Int: ReaderZoomFixturePageView] = [:]
    private var applying = false
    private var canvasShift = CGPoint.zero
    private var createdCount = 0
    private var reusedCount = 0
    private var lastSnapshot = ""
    private var pinch: UIPinchGestureRecognizer!

    public init(sessionID: UUID, pageCount: Int = 80) {
        self.sessionID = sessionID
        self.pageCount = pageCount
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic synthetic fixture only") }

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
        scroll.accessibilityIdentifier = "zoom.fixture.canvas"
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
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !applying, view.bounds.width > 0, view.bounds.height > 24 else { return }
        let size = view.bounds.size
        if state == nil {
            state = ReaderZoomFixtureState(sessionID: sessionID,
                viewportSize: size, pageCount: pageCount)
            applyPresentation()
        } else if state?.layout.viewportSize != size {
            if pinch.isEnabled {
                pinch.isEnabled = false
                pinch.isEnabled = true
            }
            scroll.panGestureRecognizer.isEnabled = true
            _ = state?.resize(viewportSize: size)
            applyPresentation()
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if state?.isPinching == true {
            state?.cancelPinch()
            scroll.panGestureRecognizer.isEnabled = true
            applyPresentation()
        }
    }

    public func perform(_ command: ReaderZoomFixtureCommand) {
        guard let state else { return }
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
        case .first: self.state?.jump(to: 0)
        case .middle: self.state?.jump(to: pageCount / 2)
        case .last: self.state?.jump(to: pageCount - 1)
        }
        applyPresentation()
    }

    @objc private func pinchChanged(_ recognizer: UIPinchGestureRecognizer) {
        let point = recognizer.location(in: view)
        switch recognizer.state {
        case .began:
            scroll.setContentOffset(scroll.contentOffset, animated: false)
            synchronizeNativeOffset()
            state?.endPan(cancelled: false)
            scroll.panGestureRecognizer.isEnabled = false
            state?.beginPinch(at: point)
            publishSnapshot()
        case .changed:
            state?.updatePinch(magnification: Double(recognizer.scale), at: point)
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

    @objc private func panChanged(_ recognizer: UIPanGestureRecognizer) {
        guard !applying, state?.isPinching != true else { return }
        switch recognizer.state {
        case .began:
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
        synchronizeNativeOffset()
        state?.doubleTap(at: recognizer.location(in: view))
        applyPresentation()
    }

    @objc private func singleTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onSingleTap?()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !applying, state?.isPinching != true else { return }
        synchronizeNativeOffset()
        reconcilePages()
        reconcileReset()
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
        applying = true
        let transform = state.presentation
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
        publishSnapshot()
    }

    private func reconcilePages() {
        guard let state else { return }
        let wanted = Set(state.materializedIndexes)
        var available: [ReaderZoomFixturePageView] = []
        for index in Array(pages.keys) where !wanted.contains(index) {
            if let page = pages.removeValue(forKey: index) {
                page.removeFromSuperview()
                page.prepareForReuse()
                available.append(page)
            }
        }
        let scale = state.presentation.scale
        for index in state.materializedIndexes {
            let page: ReaderZoomFixturePageView
            if let current = pages[index] {
                page = current
            } else if let reused = available.popLast() {
                page = reused
                reusedCount += 1
                pages[index] = page
                canvas.addSubview(page)
            } else {
                page = ReaderZoomFixturePageView()
                createdCount += 1
                pages[index] = page
                canvas.addSubview(page)
            }
            let logical = state.layout.geometry.pageFrames[index]
            page.frame = CGRect(x: logical.minX * scale + canvasShift.x,
                                y: logical.minY * scale + canvasShift.y,
                                width: logical.width * scale, height: logical.height * scale)
            page.configure(index: index, sessionID: sessionID, scale: scale)
            page.layoutIfNeeded()
        }
        // Unused detached views die here; there is no hidden retained reuse pool.
    }

    private func measuredPoint(for target: ReaderZoomFixtureAnchor) -> CGPoint? {
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

    private func publishSnapshot() {
        guard let state else { return }
        var value: [String: Any] = [
            "session": sessionID.uuidString,
            "geometryRevision": state.layout.geometry.revision,
            "scale": Double(state.presentation.scale),
            "offsetX": Double(scroll.contentOffset.x),
            "offsetY": Double(scroll.contentOffset.y),
            "viewportWidth": Double(view.bounds.width),
            "viewportHeight": Double(view.bounds.height),
            "visible": state.visibleIndexes.count,
            "materialized": pages.count,
            "nativeContainers": canvas.subviews.count,
            "cap": state.visibleIndexes.isEmpty ? 2 : state.visibleIndexes.count + 2,
            "created": createdCount,
            "reused": reusedCount,
            "pageCount": pageCount,
            "pageIDs": pages.keys.sorted(),
            "scrollOwners": countScrollOwners(in: view),
            "pinching": state.isPinching,
            "resetReady": state.resetReconciled,
            "resetRequest": state.resetRequest?.id.uuidString ?? ""
        ]
        if let request = state.resetRequest,
           let actual = measuredPoint(for: request.target) {
            value["resetErrorX"] = Double(abs(actual.x - request.target.viewportPoint.x))
            value["resetErrorY"] = Double(abs(actual.y - request.target.viewportPoint.y))
            value["resetMeasuredX"] = Double(actual.x)
            value["resetMeasuredY"] = Double(actual.y)
            value["resetRequiredX"] = Double(request.target.viewportPoint.x)
            value["resetRequiredY"] = Double(request.target.viewportPoint.y)
        }
        if let logical = state.focalPoint, let expected = state.focalViewportPoint {
            let actual = canvas.convert(CGPoint(
                x: logical.x * state.presentation.scale + canvasShift.x,
                y: logical.y * state.presentation.scale + canvasShift.y), to: view)
            value["focalErrorX"] = Double(abs(actual.x - expected.x))
            value["focalErrorY"] = Double(abs(actual.y - expected.y))
        }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8), text != lastSnapshot else { return }
        lastSnapshot = text
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastSnapshot == text else { return }
            self.onSnapshot?(text)
        }
    }
}

@MainActor
private final class ReaderZoomFixturePageView: UIView {
    private let fiducial = UIView()
    private var index: Int?
    private var scale: CGFloat = 1

    init() {
        super.init(frame: .zero)
        isOpaque = true
        contentMode = .redraw
        fiducial.backgroundColor = .systemRed
        fiducial.layer.borderWidth = 2
        fiducial.layer.borderColor = UIColor.white.cgColor
        fiducial.isAccessibilityElement = true
        fiducial.accessibilityTraits = [.image]
        addSubview(fiducial)
    }

    required init?(coder: NSCoder) { fatalError("Programmatic synthetic fixture only") }

    func configure(index: Int, sessionID: UUID, scale: CGFloat) {
        let changed = self.index != index || self.scale != scale
        self.index = index
        self.scale = scale
        fiducial.accessibilityIdentifier = "zoom.fiducial.\(index)"
        fiducial.accessibilityLabel = "Synthetic page \(index + 1) center fiducial"
        fiducial.accessibilityValue = sessionID.uuidString
        if changed {
            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    func prepareForReuse() {
        index = nil
        fiducial.accessibilityIdentifier = nil
        fiducial.accessibilityLabel = nil
        fiducial.accessibilityValue = nil
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = 14 * scale
        fiducial.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2,
                               width: side, height: side)
    }

    override func draw(_ rect: CGRect) {
        guard let index, let context = UIGraphicsGetCurrentContext() else { return }
        UIColor(hue: CGFloat(index % 8) / 8, saturation: 0.22, brightness: 0.94,
                alpha: 1).setFill()
        context.fill(bounds)
        UIColor.black.withAlphaComponent(0.22).setStroke()
        context.setLineWidth(max(1, scale))
        for fraction in [CGFloat(0.2), 0.4, 0.6, 0.8] {
            context.move(to: CGPoint(x: bounds.width * fraction, y: 0))
            context.addLine(to: CGPoint(x: bounds.width * fraction, y: bounds.height))
            context.move(to: CGPoint(x: 0, y: bounds.height * fraction))
            context.addLine(to: CGPoint(x: bounds.width, y: bounds.height * fraction))
        }
        context.strokePath()
        let label = "OWNED SYNTHETIC PAGE \(index + 1)"
        (label as NSString).draw(at: CGPoint(x: 14 * scale, y: 14 * scale), withAttributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 12 * scale, weight: .bold),
            .foregroundColor: UIColor.black
        ])
    }
}
#endif
