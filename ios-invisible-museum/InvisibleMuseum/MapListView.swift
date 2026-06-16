import CoreLocation
import MapKit
import SwiftUI

struct MapListView: View {
    @Environment(MuseumStore.self) private var store
    @State private var path: [MuseumSpace] = []
    @State private var activeKindFilter: SpaceKind?
    @State private var selectedSpace: MuseumSpace?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationService = MuseumLocationService()

    private var filteredSpaces: [MuseumSpace] {
        guard let activeKindFilter else { return store.spaces }
        return store.spaces.filter { $0.kind == activeKindFilter }
    }

    private var filterTitle: String {
        activeKindFilter?.label ?? "All"
    }

    private var mapSpaces: [MuseumSpace] {
        filteredSpaces.isEmpty ? store.spaces : filteredSpaces
    }

    var body: some View {
        NavigationStack(path: $path) {
            MuseumScreen {
                header
                statusBanner
                mapPanel
                filterBar
                if let selectedSpace {
                    selectedSpaceCard(selectedSpace)
                }
                listHeader
                ForEach(filteredSpaces) { space in
                    NavigationLink(value: space) {
                        SpaceRow(space: space, isDownloaded: store.isDownloaded(space))
                    }
                    .buttonStyle(.plain)
                }
                if filteredSpaces.isEmpty {
                    emptyState
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MuseumSpace.self) { MuseumDetailView(space: $0) }
            .onAppear {
                if locationService.authorizationState == .unknown {
                    locationService.requestWhenInUseAuthorization()
                }
                locationService.start()
                updateCameraPosition()
            }
            .onDisappear {
                locationService.stop()
            }
            .onChange(of: activeKindFilter) { _, _ in
                if let selectedSpace, !filteredSpaces.contains(selectedSpace) {
                    self.selectedSpace = nil
                }
                updateCameraPosition()
            }
            .onChange(of: filteredSpaces.map(\.id)) { _, _ in
                if let selectedSpace, !filteredSpaces.contains(selectedSpace) {
                    self.selectedSpace = nil
                }
                updateCameraPosition()
            }
            .onChange(of: locationService.currentLocation?.coordinate.latitude ?? 0) { _, _ in
                updateCameraPosition()
            }
            .onChange(of: locationService.currentLocation?.coordinate.longitude ?? 0) { _, _ in
                updateCameraPosition()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Overline(text: "Map view")
            Text("Downers Grove and nearby")
                .font(Museum.title(30))
                .foregroundStyle(Museum.text)
            Text("Browse the area map, then jump into any nearby space.")
                .font(Museum.bodyFont(14))
                .foregroundStyle(Museum.muted)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch store.nearbySpacesState {
        case .loading:
            compactStatusRow(
                icon: nil,
                title: "Syncing live spaces",
                subtitle: "Loading backend map data…",
                tint: Museum.blue,
                trailing: AnyView(ProgressView().tint(Museum.blue))
            )
        case .loadedFromBackend:
            compactStatusRow(
                icon: "checkmark.seal.fill",
                title: "Live backend",
                subtitle: "Nearby spaces synced.",
                tint: Museum.green
            )
        case .sampleFallback(let reason):
            compactStatusRow(
                icon: "exclamationmark.triangle.fill",
                title: "Offline sample mode",
                subtitle: reason,
                tint: Museum.purple
            )
        }
    }

    private func compactStatusRow(icon: String?, title: String, subtitle: String, tint: Color, trailing: AnyView = AnyView(EmptyView())) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.14), in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Museum.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .museumGlassCard(radius: Museum.Radius.md, fill: Museum.surface.opacity(0.72))
    }

    private var mapPanel: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition, selection: $selectedSpace) {
                ForEach(filteredSpaces) { space in
                    Marker(space.name, systemImage: space.kind.symbol, coordinate: coordinate(for: space))
                        .tint(space.accent)
                        .tag(space)
                }

                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat))
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous).stroke(Museum.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                MuseumChip(title: filterTitle, icon: "map")
                Text("Tap a marker or a space below to open details.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Museum.text.opacity(0.68))
            }
            .padding(14)
        }
    }

    private var filterBar: some View {
        MuseumFlowLayout(spacing: 10) {
            Button { activeKindFilter = nil } label: {
                MuseumChip(title: "All", isSelected: activeKindFilter == nil)
            }
            .buttonStyle(.plain)

            ForEach(SpaceKind.allCases, id: \.self) { kind in
                Button { activeKindFilter = kind } label: {
                    MuseumChip(title: kind.label, isSelected: activeKindFilter == kind, icon: kind.symbol)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var listHeader: some View {
        HStack {
            Overline(text: "Nearby spaces")
            Spacer()
            Text("\(filteredSpaces.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Museum.muted)
        }
    }

    private var emptyState: some View {
        MuseumCard(radius: Museum.Radius.lg, fill: Museum.surfaceElevated.opacity(0.52), stroke: Color.white.opacity(0.12), padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Label("No spaces in this filter", systemImage: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Museum.text)
                Text("Clear the filter to bring the nearby list back.")
                    .font(Museum.bodyFont(13))
                    .foregroundStyle(Museum.muted)
                Button("Show all spaces") {
                    activeKindFilter = nil
                }
                .buttonStyle(.museum(.secondary, size: .regular))
            }
        }
    }

    private func selectedSpaceCard(_ space: MuseumSpace) -> some View {
        Button {
            path.append(space)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Museum.accentGradient.opacity(0.85))
                    .frame(width: 58, height: 58)
                    .overlay(Image(systemName: space.kind.symbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 4) {
                    Overline(text: "Selected space", color: space.accent)
                    Text(space.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Museum.text)
                    Text("\(space.distanceMeters, format: .number.precision(.fractionLength(0)))m away • \(space.exhibitCount) exhibits")
                        .font(Museum.bodyFont(12))
                        .foregroundStyle(Museum.muted)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Museum.muted)
            }
            .padding(14)
            .museumGlassCard(radius: Museum.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    private func coordinate(for space: MuseumSpace) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)
    }

    private func updateCameraPosition() {
        let coordinates = mapSpaces.map { coordinate(for: $0) }
        let userCoordinate = locationService.currentLocation?.coordinate
        let region = coordinateRegion(for: coordinates, userCoordinate: userCoordinate)
        cameraPosition = .region(region)
    }

    private func coordinateRegion(for coordinates: [CLLocationCoordinate2D], userCoordinate: CLLocationCoordinate2D?) -> MKCoordinateRegion {
        var points = coordinates
        if let userCoordinate {
            points.append(userCoordinate)
        }

        guard let first = points.first else {
            let fallbackCenter = CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)
            return MKCoordinateRegion(
                center: fallbackCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        }

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.5, 0.02)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.5, 0.02)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}
