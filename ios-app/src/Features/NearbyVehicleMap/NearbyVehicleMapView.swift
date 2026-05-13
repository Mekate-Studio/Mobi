import ComposableArchitecture
import Foundation
import SwiftUI

struct NearbyVehicleMapView: View {
    let store: StoreOf<NearbyVehicleMapFeature>

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
                    Button("Use rider location") {
                        store.send(.locationPermissionResponse(.granted))
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh nearby vehicles") {
                        store.send(.refreshTapped)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.canRequestRefresh)
                }

                Button("Simulate temporary location loss") {
                    store.send(.locationPermissionResponse(.temporarilyUnavailable))
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .navigationTitle("Nearby Map")
        }
        .task {
            store.send(.task)
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
            Canvas { context, size in
                let gridPath = gridPath(size: size)
                context.stroke(
                    gridPath,
                    with: .color(Color(red: 0.22, green: 0.36, blue: 0.27).opacity(0.32)),
                    lineWidth: 1,
                )

                if case let .riderCentered(riderLocation, vehicles) = mapContent {
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - 16, y: center.y - 16, width: 32, height: 32)),
                        with: .color(.green),
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)),
                        with: .color(.white),
                    )

                    for vehicle in vehicles {
                        let point = vehiclePoint(vehicle: vehicle, riderLocation: riderLocation, size: size)
                        let marker = CGRect(x: point.x - 13, y: point.y - 13, width: 26, height: 26)
                        context.fill(Path(ellipseIn: marker), with: .color(.orange))
                        context.stroke(Path(ellipseIn: marker), with: .color(.brown), lineWidth: 2)
                    }
                }
            }
            .background(Color(red: 0.92, green: 0.96, blue: 0.93))
            .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(alignment: .leading, spacing: 4) {
                Text("Rider-centered coordinate map")
                    .font(.headline)
                Text("No SDK key required; markers are projected from shared lat/lon state.")
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

    private func gridPath(size: CGSize) -> Path {
        var path = Path()
        for index in 1 ... 6 {
            let fraction = CGFloat(index) / 7
            path.move(to: CGPoint(x: size.width * fraction, y: 0))
            path.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
            path.move(to: CGPoint(x: 0, y: size.height * fraction))
            path.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
        }
        return path
    }

    private func vehiclePoint(
        vehicle: NearbyVehicleMapVehicle,
        riderLocation: NearbyVehicleMapCoordinate,
        size: CGSize,
    ) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let xOffset = (vehicle.location.longitude - riderLocation.longitude) * 1800
        let yOffset = (vehicle.location.latitude - riderLocation.latitude) * 1000
        let scale = min(size.width, size.height) * 0.42

        return CGPoint(
            x: center.x + (xOffset * scale),
            y: center.y - (yOffset * scale),
        )
    }
}
