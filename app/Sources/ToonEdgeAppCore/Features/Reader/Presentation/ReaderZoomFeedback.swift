import Foundation

/// Input is applied presentation scale, never raw recognizer magnification.
enum ReaderZoomFeedback {
    static let lingerNanoseconds: UInt64 = 800_000_000
    static func percentage(scale: Double) -> String {
        guard scale.isFinite, scale > 0 else { return "100%" }
        return "\(Int((min(3, max(0.75, scale)) * 100).rounded()))%"
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
final class ReaderZoomHUD: UIView {
    private let label = UILabel()
    private var dismissal: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var stopped = false
    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
        layer.cornerRadius = 14
        label.textColor = .white
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityIdentifier = "reader.zoom.percentage"
        label.isAccessibilityElement = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(updateContrast), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateContrast), name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
        updateContrast()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic zoom feedback") }
    @objc private func updateContrast() {
        backgroundColor = UIColor.black.withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled || traitCollection.accessibilityContrast == .high ? 1 : 0.64)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateContrast()
    }
    func show(scale: Double, ongoing: Bool) {
        guard !stopped else { return }
        generation &+= 1
        let token = generation
        dismissal?.cancel()
        layer.removeAllAnimations()
        alpha = 1
        isHidden = false
        label.text = ReaderZoomFeedback.percentage(scale: scale)
        updateContrast()
        guard !ongoing else { return }
        dismissal = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: ReaderZoomFeedback.lingerNanoseconds) }
            catch { return }
            guard let self, !Task.isCancelled, !self.stopped, self.generation == token else { return }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.16,
                delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.alpha = 0
            } completion: { [weak self] _ in
                guard let self, self.generation == token else { return }
                self.isHidden = true
            }
        }
    }
    func hide() {
        generation &+= 1
        dismissal?.cancel()
        dismissal = nil
        layer.removeAllAnimations()
        isHidden = true
        alpha = 1
    }
    func stop() { stopped = true; hide() }
}
#endif
