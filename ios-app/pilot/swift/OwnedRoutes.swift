import MobiIOSDependencies
import SwiftUI
import UIKit

struct OwnedNativeHomeRoute: UIViewControllerRepresentable {
    let services: AppServices
    @MainActor final class Coordinator {
        var owner: HomeStoreOwner?
        init(services: AppServices) {
            owner = services.makeHomeOwner()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(services: services)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIHostingController(rootView: AnyView(HomeView(store: context.coordinator.owner!.store)))
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
        coordinator.owner?.retire()
        coordinator.owner = nil
        (controller as? UIHostingController<AnyView>)?.rootView = AnyView(EmptyView())
    }
}

struct OwnedNearbyRoute: UIViewControllerRepresentable {
    let services: AppServices
    @MainActor final class Coordinator {
        var owner: NearbyStoreOwner?
        init(services: AppServices) {
            owner = services.makeNearbyOwner()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(services: services)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIHostingController(rootView: AnyView(NearbyVehicleMapView(store: context.coordinator.owner!.store)))
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
        coordinator.owner?.retire()
        coordinator.owner = nil
        (controller as? UIHostingController<AnyView>)?.rootView = AnyView(EmptyView())
    }
}
