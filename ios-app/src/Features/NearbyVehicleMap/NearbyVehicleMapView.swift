import Foundation
import MobiIOSDependencies
import SwiftUI

struct NearbyVehicleMapView: View {
    let store: StoreOf<NearbyVehicleMapFeature>
    @StateObject private var locationClient = NearbyVehicleMapLocationClient()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.title)
                    .font(.largeTitle.bold())
                Text(store.message)
                    .font(.body)
                    .foregroundStyle(.secondary)

                NearbyVehicleCoordinateMap(
                    mapContent: store.mapContent,
                    overlay: store.overlay,
                )

                HStack {
                    Button("Refresh nearby vehicles") {
                        store.send(.refreshTapped)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.canRequestRefresh)
                }

                Button("Simulate temporary location loss") {
                    store.send(.locationResolutionResponse(.temporarilyUnavailable))
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .navigationTitle("Nearby Map")
        }
        .task {
            store.send(.task)
            locationClient.requestPreciseLocation { result in
                store.send(.locationResolutionResponse(result))
            }
            await runVisibleRefreshLoop()
        }
    }

    private func runVisibleRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            store.send(.visibleRefreshDue(nowMillis: currentTimeMillis()))
        }
    }

    private func currentTimeMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}

private struct NearbyVehicleCoordinateMap: View {
    let mapContent: NearbyVehicleMapContent
    let overlay: NearbyVehicleMapOverlay

    var body: some View {
        ZStack {
            NearbyVehicleMapRenderer(scene: scene)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text("Rider-centered native map")
                    .font(.headline)
                Text("OpenFreeMap basemap with MapLibre product markers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if case .waitingForRider = mapContent {
                Text("Waiting for rider position")
                    .font(.headline)
                    .padding(18)
                    .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
            }

            coordinateMapOverlay(overlay: overlay)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var scene: NearbyVehicleMapScene? {
        guard case let .riderCentered(scene) = mapContent else { return nil }
        return scene
    }

    @ViewBuilder
    private func coordinateMapOverlay(overlay: NearbyVehicleMapOverlay) -> some View {
        switch overlay {
        case .none:
            EmptyView()
        case let .banner(headline, message):
            coordinateMapOverlayCard(
                headline: headline,
                message: message,
                blocksMap: false,
            )
        case let .blocking(headline, message):
            coordinateMapOverlayCard(
                headline: headline,
                message: message,
                blocksMap: true,
            )
        }
    }

    private func coordinateMapOverlayCard(
        headline: String,
        message: String,
        blocksMap: Bool,
    ) -> some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(blocksMap ? .white : .brown)
        .padding(16)
        .background(
            blocksMap ? .black.opacity(0.78) : .yellow.opacity(0.86),
            in: RoundedRectangle(cornerRadius: 18),
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: blocksMap ? .center : .bottom)
        .padding(18)
    }
}
