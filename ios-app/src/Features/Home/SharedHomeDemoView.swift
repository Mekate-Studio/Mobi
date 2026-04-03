import KotlinModules
import SwiftUI

struct SharedHomeDemoView: UIViewControllerRepresentable {
    let factory: SharedHomeViewControllerFactory

    func makeUIViewController(context: Context) -> UIViewController {
        factory.create()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
