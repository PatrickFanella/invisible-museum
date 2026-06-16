import CoreLocation
import MapKit
import SwiftUI

struct ARMuseumView: View {
    let space: MuseumSpace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var session = ARMuseumSession()
    @State private var locationService = MuseumLocationService()
    @State private var selectedExhibit: Exhibit?
    @State private var didBootstrapLocation = false

    var body: some View {
        let proximity = currentProximity
        let mode = currentMode(for: proximity)

        ZStack {
            background

            switch mode {
            case .guidanceOnly(let userProximity):
                GuidanceCard(
                    space: space,
                    proximity: userProximity,
                    authorizationState: locationService.authorizationState,
                    lastErrorMessage: locationService.lastErrorMessage,
                    requestLocation: requestLocation,
                    openDirections: openDirections,
                    openSettings: openSettings
                )
                .padding(.horizontal, 20)

            case .unsupported(let reason):
                GuidanceCard(
                    space: space,
                    proximity: .unknown,
                    authorizationState: locationService.authorizationState,
                    lastErrorMessage: reason,
                    requestLocation: requestLocation,
                    openDirections: openDirections,
                    openSettings: openSettings
                )
                .padding(.horizontal, 20)

            case .geoAR, .worldTrackingFallback:
                ARCameraView(mode: mode, space: space, session: session)
                    .ignoresSafeArea()
            }

            ARHUD(space: space, session: session, onExit: { dismiss() })
        }
        .sheet(item: $selectedExhibit) { exhibit in
            ExhibitDetailView(space: space, exhibit: exhibit)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .statusBarHidden()
        .onAppear {
            guard !didBootstrapLocation else { return }
            didBootstrapLocation = true
            requestLocation()
            locationService.start()
        }
        .onDisappear {
            locationService.stop()
            session.teardown()
        }
        .task(id: sessionSyncKey(proximity: proximity, mode: mode)) {
            syncSessionState(proximity: proximity, mode: mode)
        }
        .task(id: selectedExhibit?.id ?? "none") {
            session.selectedExhibitID = selectedExhibit?.id
        }
    }

    private var background: some View {
        let mode = currentMode(for: currentProximity)

        return Group {
            switch mode {
            case .geoAR, .worldTrackingFallback:
                LinearGradient(colors: [Color(red: 0.11, green: 0.14, blue: 0.17), Museum.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        ZStack {
                            ForEach(0..<8) { i in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.035))
                                    .frame(width: CGFloat(120 + i * 18), height: 10)
                                    .rotationEffect(.degrees(Double(i * 17)))
                                    .offset(x: CGFloat(i * 17 - 70), y: CGFloat(i * 28 - 80))
                            }
                        }
                    }
            case .guidanceOnly, .unsupported:
                GuidanceMapBackground(
                    space: space,
                    userCoordinate: locationService.currentLocation?.coordinate,
                    authorizationState: locationService.authorizationState
                )
            }
        }
        .ignoresSafeArea()
    }

    private var currentProximity: UserProximity {
        let userCoordinate = locationService.currentLocation?.coordinate
        let targetCoordinate = CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)
        return GeoMath.classify(user: userCoordinate, target: targetCoordinate, radiusMeters: space.radiusMeters)
    }

    private var currentHeadingDegrees: Double? {
        guard let heading = locationService.currentHeading else { return nil }
        let trueHeading = heading.trueHeading
        if trueHeading >= 0 { return trueHeading }
        return heading.magneticHeading >= 0 ? heading.magneticHeading : nil
    }

    private func currentMode(for proximity: UserProximity) -> ARExperienceMode {
        ARCapabilityResolver.resolve(proximity: proximity)
    }

    private func syncSessionState(proximity: UserProximity, mode: ARExperienceMode) {
        switch locationService.authorizationState {
        case .unknown:
            session.stage = didBootstrapLocation ? .locatingUser : .requestingPermissions
        case .denied:
            session.stage = .denied("Location access is denied. Enable it in Settings to unlock AR guidance.")
        case .authorized:
            switch proximity {
            case .unknown:
                session.stage = .locatingUser
            case .tooFar(let distanceMeters, let bearingDegrees):
                session.stage = .tooFar(distanceMeters: distanceMeters, bearingDegrees: bearingDegrees)
            case .nearby, .inside:
                switch mode {
                case .geoAR:
                    session.stage = .checkingGeoAvailability
                case .worldTrackingFallback(let reason):
                    session.stage = .fallback(reason)
                case .guidanceOnly(let prox):
                    session.stage = .tooFar(distanceMeters: distance(from: prox), bearingDegrees: bearing(from: prox))
                case .unsupported(let reason):
                    session.stage = .unsupported(reason)
                }
            }
        }
    }

    private func sessionSyncKey(proximity: UserProximity, mode: ARExperienceMode) -> String {
        let locationKey: String
        if let location = locationService.currentLocation {
            locationKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        } else {
            locationKey = "nil"
        }

        let headingKey = locationService.currentHeading.map { "\($0.trueHeading),\($0.magneticHeading)" } ?? "nil"
        return "\(locationService.authorizationState)|\(didBootstrapLocation)|\(locationKey)|\(headingKey)|\(proximityKey(proximity))|\(modeKey(mode))"
    }

    private func proximityKey(_ proximity: UserProximity) -> String {
        switch proximity {
        case .unknown:
            return "unknown"
        case .tooFar(let distanceMeters, let bearingDegrees):
            return "tooFar:\(Int(distanceMeters)):\(Int(bearingDegrees))"
        case .nearby(let distanceMeters, let bearingDegrees):
            return "nearby:\(Int(distanceMeters)):\(Int(bearingDegrees))"
        case .inside(let distanceMeters):
            return "inside:\(Int(distanceMeters))"
        }
    }

    private func modeKey(_ mode: ARExperienceMode) -> String {
        switch mode {
        case .geoAR:
            return "geoAR"
        case .worldTrackingFallback(let reason):
            return "world:\(reason)"
        case .guidanceOnly(let proximity):
            return "guidance:\(proximityKey(proximity))"
        case .unsupported(let reason):
            return "unsupported:\(reason)"
        }
    }

    private func distance(from proximity: UserProximity) -> Double {
        switch proximity {
        case .tooFar(let distanceMeters, _), .nearby(let distanceMeters, _), .inside(let distanceMeters):
            return distanceMeters
        case .unknown:
            return 0
        }
    }

    private func bearing(from proximity: UserProximity) -> Double {
        switch proximity {
        case .tooFar(_, let bearingDegrees), .nearby(_, let bearingDegrees):
            return bearingDegrees
        case .inside, .unknown:
            return 0
        }
    }

    private func requestLocation() {
        locationService.requestWhenInUseAuthorization()
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = space.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func openSettings() {
        guard let url = URL(string: "app-settings:") else { return }
        openURL(url)
    }
}

private struct GuidanceMapBackground: View {
    let space: MuseumSpace
    let userCoordinate: CLLocationCoordinate2D?
    let authorizationState: MuseumLocationService.AuthorizationState

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.all]) {
            Marker(space.name, systemImage: space.kind.symbol, coordinate: destinationCoordinate)
                .tint(space.accent)

            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat))
        .overlay {
            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.36), Color.black.opacity(0.60)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .onAppear(perform: updateCamera)
        .onChange(of: userCoordinate?.latitude ?? 0) { _, _ in updateCamera() }
        .onChange(of: userCoordinate?.longitude ?? 0) { _, _ in updateCamera() }
        .onChange(of: authorizationState) { _, _ in updateCamera() }
    }

    private var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)
    }

    private func updateCamera() {
        let span = max(0.008, min(0.08, space.radiusMeters / 2500.0))
        cameraPosition = .region(
            MKCoordinateRegion(
                center: destinationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        )
    }
}

private struct GuidanceCard: View {
    let space: MuseumSpace
    let proximity: UserProximity
    let authorizationState: MuseumLocationService.AuthorizationState
    let lastErrorMessage: String?
    let requestLocation: () -> Void
    let openDirections: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: "location.viewfinder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineSpacing(4)

                if let detail = detailText {
                    Text(detail)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Museum.blue)
                }

                VStack(spacing: 10) {
                    Button(action: openDirections) {
                        Label("Walking directions", systemImage: "map")
                    }
                    .buttonStyle(.museum(.primary, size: .large))

                    if authorizationState == .unknown {
                        Button(action: requestLocation) {
                            Label("Allow location", systemImage: "location.fill")
                        }
                        .buttonStyle(.museum(.secondary, size: .regular))
                    } else if authorizationState == .denied {
                        Button(action: openSettings) {
                            Label("Open Settings", systemImage: "gearshape")
                        }
                        .buttonStyle(.museum(.secondary, size: .regular))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.60), in: RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Museum.Radius.xl, style: .continuous).stroke(Museum.borderStrong, lineWidth: 1))

            Spacer(minLength: 24)
        }
    }

    private var title: String {
        switch proximity {
        case .tooFar:
            return "Map guidance"
        case .unknown:
            if authorizationState == .denied { return "Location denied" }
            return "Finding your location"
        case .nearby, .inside:
            return "Guidance"
        }
    }

    private var message: String {
        switch proximity {
        case .tooFar(let distanceMeters, let bearingDegrees):
            let direction = GeoMath.compassDirection(for: bearingDegrees)
            return "Too far for AR. Use this map or walk \(GeoMath.formatDistance(distanceMeters)) toward \(direction) to reach \(space.name)."
        case .unknown:
            if authorizationState == .denied {
                return lastErrorMessage ?? "Location access is off, so AR guidance is unavailable."
            }
            return lastErrorMessage ?? "Allow location access to unlock nearby geo AR and distance guidance."
        case .nearby(_, let bearingDegrees):
            let direction = GeoMath.compassDirection(for: bearingDegrees)
            return "You're close. Open AR for an approximate in-world marker facing \(direction)."
        case .inside:
            return "You're inside the activation radius for this space."
        }
    }

    private var detailText: String? {
        switch proximity {
        case .tooFar(let distanceMeters, let bearingDegrees):
            return "\(GeoMath.formatDistance(distanceMeters)) away • heading \(Int(bearingDegrees))°"
        case .nearby(let distanceMeters, let bearingDegrees):
            return "\(GeoMath.formatDistance(distanceMeters)) away • heading \(Int(bearingDegrees))°"
        case .inside(let distanceMeters):
            return "\(GeoMath.formatDistance(distanceMeters)) from the target"
        case .unknown:
            return lastErrorMessage
        }
    }
}
