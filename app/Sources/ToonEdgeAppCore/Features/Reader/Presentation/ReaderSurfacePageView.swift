#if canImport(UIKit)
import UIKit

@MainActor
final class ReaderSurfacePageView: UIView {
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let message = UILabel()
    private let retry = UIButton(type: .system)
    private var assignment = ReaderSurfacePageAssignment()
    private var retryAction: (() -> Void)?
    private(set) var index: Int?
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        message.numberOfLines = 0
        message.textAlignment = .center
        message.font = .preferredFont(forTextStyle: .caption1)
        message.adjustsFontForContentSizeCategory = true
        retry.setTitle("Retry", for: .normal)
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        for child in [imageView, spinner, message, retry] { addSubview(child) }
    }
    required init?(coder: NSCoder) { fatalError("Programmatic reader page") }
    func configure(index: Int, sessionID: UUID, pipelineID: UUID, state: ReaderPageState?,
                   foreground: UIColor, background: UIColor, retryAction: @escaping () -> Void) {
        if self.index != index || assignment.token?.sessionID != sessionID ||
            assignment.token?.pipelineID != pipelineID {
            prepareForReuse()
            self.index = index
            _ = assignment.assign(sessionID: sessionID, pipelineID: pipelineID, index: index)
        }
        let token = assignment.token
        self.retryAction = { [weak self] in
            guard let self, let token, self.assignment.matches(token) else { return }
            retryAction()
        }
        backgroundColor = background
        message.textColor = foreground
        spinner.color = foreground
        retry.tintColor = foreground
        let ready = state?.status == .ready && state?.image != nil
        let failed = state?.status == .failed || (state?.status == .ready && state?.image == nil)
        imageView.image = state?.image.map { UIImage(cgImage: $0.cgImage) }
        imageView.isHidden = !ready
        imageView.accessibilityLabel = "Reader image \(index + 1)"
        imageView.accessibilityIdentifier = "reader.image.\(index + 1)"
        message.isHidden = ready
        message.text = failed
            ? "Page \(index + 1) unavailable. Connect to the internet and retry."
            : "Page \(index + 1)"
        message.accessibilityIdentifier = failed ? "reader.page.failed.\(index + 1)" : nil
        retry.isHidden = !failed
        retry.accessibilityIdentifier = "reader.page.retry.\(index + 1)"
        if !ready && !failed { spinner.startAnimating() } else { spinner.stopAnimating() }
        setNeedsLayout()
    }
    func prepareForReuse() {
        imageView.image = nil
        imageView.accessibilityLabel = nil
        imageView.accessibilityIdentifier = nil
        retryAction = nil
        retry.accessibilityIdentifier = nil
        message.accessibilityIdentifier = nil
        message.text = nil
        spinner.stopAnimating()
        assignment.clear()
        index = nil
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let centerY = min(bounds.height / 2, 180)
        spinner.center = CGPoint(x: bounds.midX, y: max(22, centerY - 55))
        message.frame = CGRect(x: 12, y: max(0, centerY - 35), width: max(0, bounds.width - 24), height: 70)
        retry.frame = CGRect(x: max(0, bounds.midX - 50), y: centerY + 35, width: 100, height: 44)
    }
    @objc private func retryTapped() { retryAction?() }
}
#endif
