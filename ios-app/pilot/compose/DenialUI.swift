import UIKit

@MainActor final class RetryButton: UIButton {
    override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        sendActions(for: .touchUpInside)
        return true
    }
}

@MainActor final class DenialViewController: UIViewController {
    let failure: AdmissionError
    private let retry: @MainActor () -> Void
    private(set) var retryButton: RetryButton?
    init(failure: AdmissionError, retry: @escaping @MainActor () -> Void) {
        self.failure = failure; self.retry = retry
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Diagnostic programmatic UI")
    }

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = failure == .full ? "This screen is busy" : "Session ended"
        title.font = .preferredFont(forTextStyle: .title1); title.adjustsFontForContentSizeCategory = true
        title.numberOfLines = 0; title.isAccessibilityElement = true; title.accessibilityLabel = title.text
        let message = UILabel(); message.text = failure.message
        message.font = .preferredFont(forTextStyle: .body); message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0; message.isAccessibilityElement = true; message.accessibilityLabel = message.text
        let stack = UIStackView(arrangedSubviews: [title, message]); stack.axis = .vertical; stack.spacing = 20
        if failure == .full {
            let button = RetryButton(type: .system)
            button.setTitle("Try shared screen again", for: .normal)
            button.isAccessibilityElement = true; button.accessibilityLabel = "Try shared screen again"
            button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            button.addAction(UIAction { [weak self] _ in self?.retry() }, for: .touchUpInside)
            retryButton = button; stack.addArrangedSubview(button)
        }
        view.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }
}

/// Stable representable host: replace the fallback with one admitted Compose child.
/// Ownership retirement precedes UIKit containment removal; retry never queues work.
@MainActor final class RouteContainerController: UIViewController {
    private(set) var content: UIViewController?
    func show(_ next: UIViewController) {
        clear()
        loadViewIfNeeded(); addChild(next)
        view.addSubview(next.view); next.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            next.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            next.view.topAnchor.constraint(equalTo: view.topAnchor),
            next.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        next.didMove(toParent: self); content = next
    }

    func clear() {
        guard let old = content else { return }
        old.willMove(toParent: nil); old.view.removeFromSuperview(); old.removeFromParent(); content = nil
    }
}
