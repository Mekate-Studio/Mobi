import SwiftUI

struct NearbyRefreshTimer: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    private let clock: any Clock<Duration>
    private let onTick: @MainActor () -> Void

    init(clock: any Clock<Duration> = ContinuousClock(), onTick: @escaping @MainActor () -> Void) {
        self.clock = clock
        self.onTick = onTick
    }

    func body(content: Content) -> some View {
        content.task(id: scenePhase != .background) {
            guard scenePhase != .background else { return }
            while !Task.isCancelled {
                try? await clock.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                onTick()
            }
        }
    }
}
