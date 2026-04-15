import Foundation
@preconcurrency import KotlinModules

enum HomeCounterLoadable: Equatable {
    case initial
    case loading(previousValue: Int?)
    case loaded(value: Int)
    case error(previousValue: Int?, message: String)

    init(sharedLoadable: CounterLoadable) {
        switch onEnum(of: sharedLoadable) {
        case .initial:
            self = .initial

        case let .loading(loading):
            self = .loading(previousValue: loading.previousValue?.intValue)

        case let .loaded(loaded):
            self = .loaded(value: Int(loaded.value))

        case let .error(error):
            self = .error(
                previousValue: error.previousValue?.intValue,
                message: error.message
            )
        }
    }

    var currentValueForRefresh: Int {
        switch self {
        case .initial:
            return 0
        case let .loading(previousValue):
            return previousValue ?? 0
        case let .loaded(value):
            return value
        case let .error(previousValue, _):
            return previousValue ?? 0
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
        case let .error(previousValue, message):
            if let previousValue {
                return "\(message) Showing last known counter value \(previousValue)."
            }
            return "\(message) No fibonacci counter value was loaded yet."
        }
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}
