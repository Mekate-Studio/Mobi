import Foundation
import SwiftUI
import UIKit

@MainActor final class AdmittedComposeOwner {
    let owner: SharedUIOwner.HomeRouteOwner
    private let reservation: AdmissionReservation
    private let supervisor: ComposeDrainSupervisor
    private var retired = false
    private var drainID: UUID?
    init(owner: SharedUIOwner.HomeRouteOwner, reservation: AdmissionReservation, supervisor: ComposeDrainSupervisor) {
        self.owner = owner; self.reservation = reservation; self.supervisor = supervisor
    }

    func retire() -> UUID? {
        guard !retired else { return drainID }
        retired = true
        owner.retire()
        if owner.isDrained {
            reservation.release()
        } else {
            drainID = supervisor.adopt(owner) { [reservation] in reservation.release() }
        }
        return drainID
    }
}

struct SharedHomeDemoView: UIViewControllerRepresentable {
    let services: AppServices
    @MainActor final class Coordinator {
        private let services: AppServices
        weak var controller: RouteContainerController?
        private var admitted: AdmittedComposeOwner?
        private var disposed = false
        init(services: AppServices) {
            self.services = services
        }

        func retry() {
            guard !disposed, admitted == nil, let controller else { return }
            do {
                let owner = try services.makeSharedHomeOwner()
                admitted = owner
                controller.show(owner.owner.createViewController())
            } catch let failure as AdmissionError {
                controller.show(DenialViewController(failure: failure) { [weak self] in self?.retry() })
            } catch { preconditionFailure("Unexpected Compose admission failure") }
        }

        func dispose() {
            guard !disposed else { return }
            disposed = true
            _ = admitted?.retire()
            admitted = nil
            controller?.clear()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(services: services)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = RouteContainerController()
        context.coordinator.controller = controller
        context.coordinator.retry()
        return controller
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
    static func dismantleUIViewController(_: UIViewController, coordinator: Coordinator) {
        coordinator.dispose()
    }
}
