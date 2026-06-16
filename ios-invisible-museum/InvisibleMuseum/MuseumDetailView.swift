import CoreLocation
import MapKit
import SwiftUI

struct MuseumDetailView: View {
    let space: MuseumSpace
    @Environment(MuseumStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var enterAR = false
    @State private var showingMapList = false
    @State private var locationService = MuseumLocationService()
    @State private var actionPrompt: PlaceActionPrompt?
    @State private var readerExhibit: Exhibit?

    var body: some View {
        MuseumScreen(bottomInset: 36, topInset: 0) {
            banner
            summary
            actions
            exhibits
            contributors
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { backButton }
        .task { locationService.start() }
        .sheet(item: $actionPrompt) { prompt in
            DirectionsPromptView(
                space: space,
                prompt: prompt,
                requestLocation: requestLocation,
                openSettings: openSettings,
                openWalkingDirections: openWalkingDirections,
                viewOnMap: viewOnMap,
                tryARAnyway: tryARAnyway
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showingMapList) {
            MapListView(initialSelectedSpace: space, onClose: { showingMapList = false })
        }
        .fullScreenCover(isPresented: $enterAR) { ARMuseumView(space: space) }
        .sheet(item: $readerExhibit) { ExhibitDetailView(space: space, exhibit: $0).presentationDetents([.medium, .large]).presentationDragIndicator(.visible).presentationBackground(.ultraThinMaterial) }
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous)
                .fill(Museum.accentGradient.opacity(0.56))
                .overlay(alignment: .center) {
                    Image(systemName: space.kind.symbol)
                        .font(.system(size: 132, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.20))
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Museum.ink], startPoint: .top, endPoint: .bottom)
                        .frame(height: 160)
                }

            VStack(alignment: .leading, spacing: 8) {
                Overline(text: space.kind.label, color: .white.opacity(0.82))
                Text(space.name)
                    .font(Museum.title(34))
                    .foregroundStyle(Museum.text)
                Text(space.tagline)
                    .font(Museum.bodyFont(15))
                    .foregroundStyle(Museum.text.opacity(0.72))
            }
            .padding(22)
        }
        .frame(height: 320)
        .overlay(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous).stroke(Museum.border, lineWidth: 1))
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Museum.text)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.42), in: Circle())
                .overlay(Circle().stroke(Museum.border, lineWidth: 1))
        }
        .padding(.leading, 16)
        .padding(.top, 54)
    }

    private var summary: some View {
        let liveDistanceText: String
        switch currentProximity {
        case .tooFar(let distanceMeters, _), .nearby(let distanceMeters, _), .inside(let distanceMeters):
            liveDistanceText = GeoMath.formatDistance(distanceMeters)
        case .unknown:
            liveDistanceText = GeoMath.formatDistance(space.distanceMeters)
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(space.summary)
                .font(Museum.bodyFont(15))
                .lineSpacing(4)
                .foregroundStyle(Museum.text.opacity(0.78))
            HStack(spacing: 10) {
                stat("\(space.exhibitCount)", "Exhibits", color: Museum.blue)
                stat("\(space.contributorCount)", "Contributors", color: Museum.purple)
                stat(liveDistanceText, "Away", color: Museum.green)
            }
        }
    }

    private func stat(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Museum.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .museumGlassCard(radius: Museum.Radius.md)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { decideARFlow() } label: {
                Label("Open AR / Directions", systemImage: "sparkles")
            }
            .buttonStyle(.museum(.primary, size: .large))

            Button { store.toggleDownloaded(space) } label: {
                Label(store.isDownloaded(space) ? "Available Offline" : "Download for Offline", systemImage: store.isDownloaded(space) ? "checkmark.circle.fill" : "arrow.down.circle")
            }
            .buttonStyle(.museum(.secondary, size: .regular))
        }
    }

    private var currentProximity: UserProximity {
        let userCoordinate = locationService.currentLocation?.coordinate
        let targetCoordinate = CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)
        let activationRadius = GeoMath.arActivationRadius(for: space.radiusMeters)
        return GeoMath.classify(user: userCoordinate, target: targetCoordinate, radiusMeters: activationRadius)
    }

    private func decideARFlow() {
        switch locationService.authorizationState {
        case .unknown:
            requestLocation()
            actionPrompt = .locationNeeded

        case .denied:
            actionPrompt = .locationDenied(distanceText: proximityText, bearingText: bearingText)

        case .authorized:
            switch currentProximity {
            case .unknown:
                actionPrompt = .locationNeeded
            case .tooFar(let distanceMeters, let bearingDegrees):
                actionPrompt = .tooFar(distanceMeters: distanceMeters, bearingDegrees: bearingDegrees)
            case .nearby(let distanceMeters, let bearingDegrees):
                actionPrompt = .nearby(distanceMeters: distanceMeters, bearingDegrees: bearingDegrees)
            case .inside:
                enterAR = true
            }
        }
    }

    private var proximityText: String? {
        switch currentProximity {
        case .tooFar(let distanceMeters, _), .nearby(let distanceMeters, _), .inside(let distanceMeters):
            return GeoMath.formatDistance(distanceMeters)
        case .unknown:
            return nil
        }
    }

    private var bearingText: String? {
        switch currentProximity {
        case .tooFar(_, let bearingDegrees), .nearby(_, let bearingDegrees):
            return "\(GeoMath.compassDirection(for: bearingDegrees)) • \(Int(bearingDegrees))°"
        case .inside, .unknown:
            return nil
        }
    }

    private func requestLocation() {
        locationService.requestWhenInUseAuthorization()
    }

    private func openWalkingDirections() {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = space.name
        dismissPromptIfNeeded()
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func viewOnMap() {
        dismissPromptIfNeeded()
        showingMapList = true
    }

    private func tryARAnyway() {
        dismissPromptIfNeeded()
        enterAR = true
    }

    private func openSettings() {
        guard let url = URL(string: "app-settings:") else { return }
        openURL(url)
    }

    private func dismissPromptIfNeeded() {
        actionPrompt = nil
    }

    private var exhibits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exhibits")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Museum.text)
            ForEach(space.exhibits) { exhibit in
                Button { readerExhibit = exhibit } label: {
                    HStack(spacing: 12) {
                        Image(systemName: exhibit.kind.symbol)
                            .foregroundStyle(space.accent)
                            .frame(width: 40, height: 40)
                            .background(Museum.surfaceElevated, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Overline(text: exhibit.kind.label, color: space.accent)
                            Text(exhibit.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Museum.text)
                            Text(exhibit.body)
                                .font(Museum.bodyFont(12))
                                .foregroundStyle(Museum.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .museumGlassCard(radius: Museum.Radius.md)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var contributors: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Museum.accentGradient)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.2.fill").foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("Community Contributions")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Museum.text)
                Text("Local residents keep this museum alive with memories and sources.")
                    .font(Museum.bodyFont(12))
                    .foregroundStyle(Museum.muted)
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Museum.blue.opacity(0.25), Museum.purple.opacity(0.20)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: Museum.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Museum.Radius.lg).stroke(Museum.blue.opacity(0.22), lineWidth: 1))
    }
}

private enum PlaceActionPrompt: Equatable, Identifiable {
    case locationNeeded
    case locationDenied(distanceText: String?, bearingText: String?)
    case nearby(distanceMeters: Double, bearingDegrees: Double)
    case tooFar(distanceMeters: Double, bearingDegrees: Double)

    var id: String {
        switch self {
        case .locationNeeded: return "locationNeeded"
        case .locationDenied(let distanceText, let bearingText): return "locationDenied-\(distanceText ?? "none")-\(bearingText ?? "none")"
        case .nearby(let distanceMeters, let bearingDegrees): return "nearby-\(Int(distanceMeters))-\(Int(bearingDegrees))"
        case .tooFar(let distanceMeters, let bearingDegrees): return "tooFar-\(Int(distanceMeters))-\(Int(bearingDegrees))"
        }
    }
}

private struct DirectionsPromptView: View {
    let space: MuseumSpace
    let prompt: PlaceActionPrompt
    let requestLocation: () -> Void
    let openSettings: () -> Void
    let openWalkingDirections: () -> Void
    let viewOnMap: () -> Void
    let tryARAnyway: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(Museum.title(24))
                    .foregroundStyle(Museum.text)
                Text(message)
                    .font(Museum.bodyFont(14))
                    .foregroundStyle(Museum.muted)
            }

            compactSiteCard

            if let detailText {
                HStack(spacing: 8) {
                    Image(systemName: "location.north.line")
                        .foregroundStyle(Museum.blue)
                    Text(detailText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Museum.text)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .museumGlassCard(radius: Museum.Radius.md)
            }

            VStack(spacing: 10) {
                switch prompt {
                case .locationNeeded:
                    Button(action: requestLocation) {
                        Label("Allow location", systemImage: "location.fill")
                    }
                    .buttonStyle(.museum(.primary, size: .large))

                    Button(action: tryARAnyway) {
                        Label("Try AR Anyway", systemImage: "sparkles")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                case .locationDenied:
                    Button(action: viewOnMap) {
                        Label("Open In-App Map", systemImage: "map.fill")
                    }
                    .buttonStyle(.museum(.primary, size: .large))

                    Button(action: openSettings) {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                    Button(action: openWalkingDirections) {
                        Label("Open in Apple Maps", systemImage: "map")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                    Button(action: tryARAnyway) {
                        Label("Try AR Anyway", systemImage: "sparkles")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                case .nearby:
                    Button(action: viewOnMap) {
                        Label("Open In-App Map", systemImage: "map.fill")
                    }
                    .buttonStyle(.museum(.primary, size: .large))

                    Button(action: openWalkingDirections) {
                        Label("Open in Apple Maps", systemImage: "map")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                    Button(action: tryARAnyway) {
                        Label("Try AR Anyway", systemImage: "sparkles")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                case .tooFar:
                    Button(action: viewOnMap) {
                        Label("Open In-App Map", systemImage: "map.fill")
                    }
                    .buttonStyle(.museum(.primary, size: .large))

                    Button(action: openWalkingDirections) {
                        Label("Open in Apple Maps", systemImage: "map")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))

                    Button(action: tryARAnyway) {
                        Label("Try AR Anyway", systemImage: "sparkles")
                    }
                    .buttonStyle(.museum(.secondary, size: .regular))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var title: String {
        switch prompt {
        case .locationNeeded:
            return "Location needed"
        case .locationDenied:
            return "Location denied"
        case .nearby:
            return "Not close enough for AR"
        case .tooFar:
            return "Too far for AR"
        }
    }

    private var message: String {
        switch prompt {
        case .locationNeeded:
            return "This space needs your current location so we can decide whether to open AR or directions."
        case .locationDenied:
            return "Turn on location access to get guidance, walking directions, and AR unlocks within ~50m. You can still open the in-app map or Apple Maps."
        case .nearby(let distanceMeters, let bearingDegrees):
            return "AR unlocks within ~50m. You're \(GeoMath.formatDistance(distanceMeters)) away. Walk toward \(GeoMath.compassDirection(for: bearingDegrees)) or open the map first."
        case .tooFar(let distanceMeters, let bearingDegrees):
            return "AR unlocks within ~50m. You're \(GeoMath.formatDistance(distanceMeters)) away. Walk toward \(GeoMath.compassDirection(for: bearingDegrees)) or open the map first."
        }
    }

    private var detailText: String? {
        switch prompt {
        case .locationNeeded:
            return nil
        case .locationDenied(let distanceText, let bearingText):
            if let distanceText, let bearingText {
                return "AR unlocks within ~50m • \(distanceText) away • heading \(bearingText)"
            }
            return distanceText.map { "AR unlocks within ~50m • \($0) away" }
        case .nearby(let distanceMeters, let bearingDegrees):
            return "AR unlocks within ~50m • \(GeoMath.formatDistance(distanceMeters)) away • heading \(Int(bearingDegrees))°"
        case .tooFar(let distanceMeters, let bearingDegrees):
            return "AR unlocks within ~50m • \(GeoMath.formatDistance(distanceMeters)) away • heading \(Int(bearingDegrees))°"
        }
    }

    private var compactSiteCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Museum.accentGradient)
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: space.kind.symbol).foregroundStyle(.white))

            VStack(alignment: .leading, spacing: 3) {
                Overline(text: space.kind.label, color: space.accent)
                Text(space.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Museum.text)
                Text(space.tagline)
                    .font(Museum.bodyFont(12))
                    .foregroundStyle(Museum.muted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .museumGlassCard(radius: Museum.Radius.md)
    }
}
