import SwiftUI

struct SharedHomeDemoView: UIViewControllerRepresentable {
    let makeViewController: @MainActor () -> UIViewController

    func makeUIViewController(context _: Context) -> UIViewController {
        makeViewController()
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}
