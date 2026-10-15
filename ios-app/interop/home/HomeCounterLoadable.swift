import Foundation
@_implementationOnly import MobiHome

typealias Home = ExportedKotlinPackages.studio.mekate.mobi.feature.home

enum HomeCounterLoadable: Equatable, Sendable {
    case initial
    case loading(previousValue: Int?)
    case loaded(value: Int)
    case error(previousValue: Int?, reason: HomeCounterLoadFailureReason)

    @MainActor init(sharedValue: any Home.CounterLoadable) {
        switch sharedValue.sealedType() {
        case .initial: self = .initial
        case let .loading(state): self = .loading(previousValue: state.value.previousValue.map(Int.init))
        case let .loaded(state): self = .loaded(value: Int(state.value.value))
        case let .error(state):
            self = .error(
                previousValue: state.value.previousValue.map(Int.init),
                reason: HomeCounterLoadFailureReason(sharedReason: state.value.reason),
            )
        }
    }

    var currentValueForRefresh: Int {
        switch self {
        case .initial:
            0
        case let .loading(previousValue):
            previousValue ?? 0
        case let .loaded(value):
            value
        case let .error(previousValue, _):
            previousValue ?? 0
        }
    }

    var displayedCounterText: String {
        switch self {
        case .initial:
            return "Counter value: Not loaded yet"
        case let .loading(previousValue):
            if let previousValue {
                return "Counter value: \(previousValue)"
            }
            return "Counter value: Loading first result…"
        case let .loaded(value):
            return "Counter value: \(value)"
        case let .error(previousValue, _):
            if let previousValue {
                return "Counter value: \(previousValue)"
            }
            return "Counter value: No value available"
        }
    }

    var supportingText: String {
        switch self {
        case .initial:
            return "Tap the action to load the next fibonacci counter value from the fake repository."
        case .loading:
            return "Loading the next fibonacci counter value from the fake repository."
        case let .loaded(value):
            return "The fake repository returned fibonacci counter value \(value)."
        case let .error(previousValue, reason):
            if let previousValue {
                return "\(reason.headlineText) Showing last known counter value \(previousValue)."
            }
            return "\(reason.headlineText) No fibonacci counter value was loaded yet."
        }
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

enum HomeCounterLoadFailureReason: Equatable, Sendable {
    case repositoryUnavailable
    case unexpected

    @MainActor init(sharedReason: any Home.CounterLoadFailureReason) {
        switch sharedReason.sealedType() {
        case .repositoryUnavailable: self = .repositoryUnavailable
        case .unexpected: self = .unexpected
        }
    }

    var headlineText: String {
        switch self {
        case .repositoryUnavailable:
            "The fake repository failed to load the next fibonacci counter value."
        case .unexpected:
            "Something went wrong while loading the next fibonacci counter value."
        }
    }
}
