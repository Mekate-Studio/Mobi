import Foundation
import MobiIOSDependencies

extension HomeFeature {
    @ObservableState
    struct State: Equatable {
        var counterLoadable = HomeCounterLoadable.initial

        let cancellationID = UUID()
        var activeRequest: UUID?
        var previousValue: HomeCounterLoadable?
        var retired = false
        var admissionFailure: AdmissionError?

        var title: String {
            "Shared feature, platform rendering"
        }

        var message: String {
            "Shared business logic feeding a platform-specific screen."
        }

        var supportingText: String {
            admissionFailure?.message ?? counterLoadable.supportingText
        }

        var canRequestRefresh: Bool {
            !retired && admissionFailure != .closed
        }

        var primaryActionLabel: String {
            admissionFailure == .full ? "Try counter again" : admissionFailure == .closed ? "Session ended" : "Load next counter value"
        }
    }
}
