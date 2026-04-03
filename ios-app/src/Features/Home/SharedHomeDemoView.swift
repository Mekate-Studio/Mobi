import KotlinModules
import SwiftUI

struct SharedHomeDemoView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SharedHomeViewControllerFactory().create()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
