import KotlinModules
import SwiftUI

struct SharedHomeDemoView: UIViewControllerRepresentable {
    let factory: SharedHomeViewControllerFactory

    func makeUIViewController(context _: Context) -> UIViewController {
        factory.create()
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}
