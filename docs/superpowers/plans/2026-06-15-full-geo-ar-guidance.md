# Full Geo-AR Guidance Implementation Plan

> **For agentic workers:** Execute this plan task-by-task. Recommended path:
> dispatch a fresh subagent per task, review each result with `review-quality`,
> then continue. For complex multi-agent splits, use
> `parallel-feature-development`, `team-composition-patterns`, and
> `team-communication-protocols`. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Replace the simulated AR screen with a real ARKit/RealityKit experience that gates far-away users into distance/bearing guidance and Apple Maps directions.

**Architecture:** Keep SwiftUI as the shell and isolate camera/location/session logic into small services. Use CoreLocation to classify proximity before launching AR, ARGeoTrackingConfiguration for geo-AR when supported/available, ARWorldTrackingConfiguration as nearby fallback, and MapKit for real directions when the user is too far away.

**Tech Stack:** SwiftUI, ARKit, RealityKit, CoreLocation, MapKit, Xcode generated Info.plist build settings, existing `MuseumSpace`/`Exhibit` models.

---

## File structure

- Create `ios-invisible-museum/InvisibleMuseum/GeoMath.swift` — pure distance/bearing/proximity helpers.
- Create `ios-invisible-museum/InvisibleMuseum/LocationService.swift` — `CLLocationManager` wrapper for authorization, location, heading.
- Create `ios-invisible-museum/InvisibleMuseum/ARCapabilityResolver.swift` — decides between `geoAR`, `worldTrackingFallback`, `guidanceOnly`, and `unsupported`.
- Create `ios-invisible-museum/InvisibleMuseum/ARCameraView.swift` — `UIViewRepresentable` wrapper around RealityKit `ARView`.
- Modify `ios-invisible-museum/InvisibleMuseum/ARMuseumSession.swift` — expand state machine and own AR session state.
- Modify `ios-invisible-museum/InvisibleMuseum/ARMuseumView.swift` — replace fake camera with guidance/real AR/fallback shell.
- Modify `ios-invisible-museum/InvisibleMuseum/ARHUD.swift` — show proximity, tracking, geo availability, and selected exhibit status.
- Modify `ios-invisible-museum/InvisibleMuseum/MuseumDetailView.swift` — route “Begin AR Experience” through proximity guidance.
- Modify `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj` — add Swift files and privacy usage descriptions.
- Update `README.md` — document real-device AR requirements and fallback behavior.

## Task 1: Geo math and proximity model

**Files:**
- Create: `ios-invisible-museum/InvisibleMuseum/GeoMath.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add pure geo helpers**

```swift
import CoreLocation
import Foundation

enum UserProximity: Equatable {
    case unknown
    case tooFar(distanceMeters: Double, bearingDegrees: Double)
    case nearby(distanceMeters: Double, bearingDegrees: Double)
    case inside(distanceMeters: Double)
}

enum GeoMath {
    static let nearbyMultiplier = 2.0

    static func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    static func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        return fmod((atan2(y, x) * 180 / .pi) + 360, 360)
    }

    static func relativeBearingDegrees(targetBearing: Double, heading: Double?) -> Double {
        guard let heading else { return targetBearing }
        return fmod((targetBearing - heading) + 360, 360)
    }

    static func classify(user: CLLocationCoordinate2D?, target: CLLocationCoordinate2D, radiusMeters: Double, heading: Double? = nil) -> UserProximity {
        guard let user else { return .unknown }
        let distance = distanceMeters(from: user, to: target)
        let bearing = relativeBearingDegrees(targetBearing: bearingDegrees(from: user, to: target), heading: heading)
        if distance <= radiusMeters { return .inside(distanceMeters: distance) }
        if distance <= radiusMeters * nearbyMultiplier { return .nearby(distanceMeters: distance, bearingDegrees: bearing) }
        return .tooFar(distanceMeters: distance, bearingDegrees: bearing)
    }
}
```

- [ ] **Step 2: Register the file in Xcode project**

Add `GeoMath.swift` to the app target source phase in `InvisibleMuseum.xcodeproj/project.pbxproj`, following the existing source-file pattern.

- [ ] **Step 3: Build**

Run:

```bash
cd ios-invisible-museum && xcodebuild -project "InvisibleMuseum.xcodeproj" -scheme "InvisibleMuseum" -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`.

## Task 2: Location service and permissions

**Files:**
- Create: `ios-invisible-museum/InvisibleMuseum/LocationService.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add location service**

```swift
import CoreLocation
import Observation

@MainActor
@Observable
final class MuseumLocationService: NSObject, CLLocationManagerDelegate {
    enum AuthorizationState: Equatable {
        case unknown
        case denied
        case authorized
    }

    private let manager = CLLocationManager()

    var authorizationState: AuthorizationState = .unknown
    var currentLocation: CLLocation?
    var currentHeading: CLHeading?
    var lastErrorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = 5
        }
        updateAuthorizationState(manager.authorizationStatus)
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationState(manager.authorizationStatus)
            if authorizationState == .authorized { start() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in currentLocation = location }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in currentHeading = newHeading }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in lastErrorMessage = error.localizedDescription }
    }

    private func updateAuthorizationState(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: authorizationState = .authorized
        case .denied, .restricted: authorizationState = .denied
        case .notDetermined: authorizationState = .unknown
        @unknown default: authorizationState = .unknown
        }
    }
}
```

- [ ] **Step 2: Add Info.plist generated keys**

In both Debug and Release build settings in `project.pbxproj`, add:

```text
INFOPLIST_KEY_NSCameraUsageDescription = "Invisible Museum uses the camera to place exhibit markers in AR.";
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Invisible Museum uses your location to guide you to nearby museum spaces and unlock location-based AR.";
INFOPLIST_KEY_NSMotionUsageDescription = "Invisible Museum uses device motion to orient AR exhibit markers.";
```

- [ ] **Step 3: Register file and build**

Add `LocationService.swift` to the app target and run the same iOS build command. Expected: build succeeds.

## Task 3: Capability resolver and guidance mode

**Files:**
- Create: `ios-invisible-museum/InvisibleMuseum/ARCapabilityResolver.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/ARMuseumSession.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add mode resolver**

```swift
import ARKit
import CoreLocation

enum ARExperienceMode: Equatable {
    case geoAR
    case worldTrackingFallback(reason: String)
    case guidanceOnly(UserProximity)
    case unsupported(reason: String)
}

enum ARCapabilityResolver {
    static func resolve(proximity: UserProximity, geoTrackingSupported: Bool = ARGeoTrackingConfiguration.isSupported, worldTrackingSupported: Bool = ARWorldTrackingConfiguration.isSupported) -> ARExperienceMode {
        switch proximity {
        case .unknown:
            return .guidanceOnly(.unknown)
        case .tooFar:
            return .guidanceOnly(proximity)
        case .nearby, .inside:
            if geoTrackingSupported { return .geoAR }
            if worldTrackingSupported { return .worldTrackingFallback(reason: "Geo tracking is unavailable here. Showing approximate nearby AR.") }
            return .unsupported(reason: "AR is not supported on this device.")
        }
    }
}
```

- [ ] **Step 2: Expand AR session state**

Replace `ARMuseumSession.Stage` with:

```swift
enum Stage: Equatable {
    case requestingPermissions
    case locatingUser
    case tooFar(distanceMeters: Double, bearingDegrees: Double)
    case checkingGeoAvailability
    case localizing
    case ready
    case fallback(String)
    case denied(String)
    case unsupported(String)
}
```

Keep existing `placedExhibitCount`, `selectedExhibitID`, and `teardown()`.

- [ ] **Step 3: Register file and build**

Add `ARCapabilityResolver.swift` to the Xcode project. Build must pass.

## Task 4: Real AR camera wrapper

**Files:**
- Create: `ios-invisible-museum/InvisibleMuseum/ARCameraView.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/ExhibitEntityFactory.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add RealityKit AR wrapper**

```swift
import ARKit
import RealityKit
import SwiftUI

struct ARCameraView: UIViewRepresentable {
    let mode: ARExperienceMode
    let space: MuseumSpace
    let session: ARMuseumSession

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        context.coordinator.configure(arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.mode = mode
        context.coordinator.space = space
        context.coordinator.session = session
        context.coordinator.run(on: arView)
    }

    static func dismantleUIView(_ arView: ARView, coordinator: Coordinator) {
        arView.session.pause()
        coordinator.session?.teardown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, space: space, session: session)
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        var mode: ARExperienceMode
        var space: MuseumSpace
        weak var session: ARMuseumSession?
        private var didRun = false

        init(mode: ARExperienceMode, space: MuseumSpace, session: ARMuseumSession) {
            self.mode = mode
            self.space = space
            self.session = session
        }

        func configure(_ arView: ARView) {
            arView.automaticallyConfigureSession = false
            arView.environment.sceneUnderstanding.options = []
        }

        func run(on arView: ARView) {
            guard !didRun else { return }
            didRun = true
            switch mode {
            case .geoAR:
                session?.stage = .localizing
                let config = ARGeoTrackingConfiguration()
                config.planeDetection = [.horizontal]
                arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                placeApproximateEntities(in: arView)
            case .worldTrackingFallback(let reason):
                session?.stage = .fallback(reason)
                let config = ARWorldTrackingConfiguration()
                config.planeDetection = [.horizontal]
                arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                placeApproximateEntities(in: arView)
            case .guidanceOnly, .unsupported:
                break
            }
        }

        private func placeApproximateEntities(in arView: ARView) {
            for exhibit in space.exhibits {
                let anchor = AnchorEntity(world: exhibit.offset)
                anchor.addChild(ExhibitEntityFactory.makeMarker(for: exhibit))
                arView.scene.addAnchor(anchor)
            }
            session?.placedExhibitCount = space.exhibits.count
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            Task { @MainActor in self.session?.stage = .ready }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in self.session?.stage = .denied(error.localizedDescription) }
        }
    }
}
```

- [ ] **Step 2: Replace empty entity factory**

```swift
import RealityKit
import UIKit

enum ExhibitEntityFactory {
    static func makeMarker(for exhibit: Exhibit) -> Entity {
        let radius: Float = 0.08
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.85), roughness: 0.2, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = exhibit.id
        return entity
    }
}
```

- [ ] **Step 3: Register file and build**

Add `ARCameraView.swift` to project. Build must pass on simulator; real AR must be tested on device.

## Task 5: Guidance UI and Apple Maps handoff

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/ARMuseumView.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum/ARHUD.swift`

- [ ] **Step 1: Add guidance screen to AR museum view**

Use `MuseumLocationService`, classify current location against `space.latitude/longitude/radiusMeters`, resolve mode, and render:

```swift
case .guidanceOnly(let proximity):
    GuidanceCard(space: space, proximity: proximity)
```

For `.geoAR` and `.worldTrackingFallback`, render `ARCameraView(mode: mode, space: space, session: session)` behind `ARHUD`.

- [ ] **Step 2: Add Apple Maps button**

In `GuidanceCard`, open walking directions:

```swift
let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude))
let item = MKMapItem(placemark: placemark)
item.name = space.name
item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
```

- [ ] **Step 3: Update HUD copy**

Show stage-specific text:
- too far: `"Too far for AR"`
- localizing: `"Localizing geo AR"`
- ready: `"AR ready"`
- fallback: `"Approximate AR"`
- unsupported/denied: exact reason.

- [ ] **Step 4: Build**

Run iOS build. Expected: build succeeds.

## Task 6: Detail entry and documentation

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/MuseumDetailView.swift`
- Modify: `README.md`

- [ ] **Step 1: Make CTA accurate**

Change CTA copy from unconditional `Begin AR Experience` to `Open AR / Directions`. The AR view decides whether to show geo-AR, approximate AR, or directions.

- [ ] **Step 2: Document behavior**

Add README notes:
- real AR requires physical iPhone/iPad with ARKit support;
- simulator only verifies UI/build;
- far-away users get Apple Maps directions;
- nearby users get geo-AR when available and approximate AR fallback otherwise.

- [ ] **Step 3: Build and smoke**

Run:

```bash
cd ios-invisible-museum && xcodebuild -project "InvisibleMuseum.xcodeproj" -scheme "InvisibleMuseum" -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds. Then test on a physical device by opening a selected place from Explore and checking permission prompts.

## Acceptance criteria

- App has camera/location usage descriptions and does not crash on permission prompts.
- Far-away selected space shows distance/bearing guidance plus Apple Maps directions.
- Nearby selected space attempts geo-AR if supported/available.
- Nearby selected space falls back to approximate world-tracking AR if geo tracking is unavailable.
- Existing Explore, Detail, Saved, Contribute, Profile, backend API config, and moderation flows still build.
- Simulator build passes; real AR behavior is explicitly marked as requiring device verification.

## Known limitations

- ARGeoTracking availability varies by device and location.
- Exhibit placement uses existing local `Exhibit.offset` around the selected space, not per-exhibit GPS coordinates.
- Straight-line bearing is for orientation only; actual route guidance is delegated to Apple Maps.
