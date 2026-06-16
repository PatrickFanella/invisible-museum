# In-App Directions and Walking Tours Implementation Plan

> **For agentic workers:** Execute this plan task-by-task. Recommended path:
> dispatch a fresh subagent per task, review each result with `review-quality`,
> then continue. For complex multi-agent splits, use
> `parallel-feature-development`, `team-composition-patterns`, and
> `team-communication-protocols`. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Add simple in-app walking directions now, while creating a map/tour architecture that can later chain multiple museum spaces into walking tours.

**Architecture:** Start client-side: compute one walking route from current user location to a selected `MuseumSpace` using `MKDirections`, render it with SwiftUI `MapPolyline`, and show distance/ETA in the selected-place card. Then add local tour models as ordered stops and route legs. Backend tour persistence comes later after the UX is proven.

**Tech Stack:** SwiftUI, MapKit (`Map`, `MapPolyline`, `MKDirections`, `MKRoute`), CoreLocation, existing `MuseumSpace`/`LocationService`, future Go/Postgres tour schema.

---

## Current state summary

- `MapListView.swift` already has real MapKit markers, user annotation, selected-space card, optional modal close button, and optional initial selected site.
- `MuseumDetailView.swift` now has a directions prompt and can open `MapListView(initialSelectedSpace:onClose:)`.
- `LocationService.swift` tracks user location/heading.
- `GeoMath.swift` handles distance/bearing and caps AR activation at ~50m.
- There is no route model, no `MKDirections` wrapper, no polyline rendering, and no tour/stop/leg model.

## Product target

### Simple v1

When the user opens the in-app map for a selected site:

1. App shows current user location and destination marker.
2. App requests a walking route with `MKDirections`.
3. App draws the walking route on the map.
4. Selected-site card shows distance and ETA, e.g. `0.6 mi · 12 min walk`.
5. If routing fails, app shows a clear fallback and keeps **Open in Apple Maps**.

### Future walking tours

When the user chooses a walking tour:

1. App shows an ordered list of stops.
2. App calculates route legs one at a time: current location → stop 1, stop 1 → stop 2, etc.
3. Map draws the active leg prominently and future legs subtly.
4. User can mark a stop visited and advance to the next one.
5. When close enough to a stop, app offers AR.

---

## File structure

- Create `ios-invisible-museum/InvisibleMuseum/WalkingRouteService.swift` — wraps `MKDirections` and returns route summaries.
- Create `ios-invisible-museum/InvisibleMuseum/WalkingRouteModels.swift` — `WalkingRoute`, `WalkingRouteState`, future `TourStop`, `TourLeg`, `WalkingTour`.
- Modify `ios-invisible-museum/InvisibleMuseum/MapListView.swift` — load/render route for selected site; show ETA/distance card; keep marker/list behavior.
- Modify `ios-invisible-museum/InvisibleMuseum/MuseumDetailView.swift` — keep dialogue, route to in-app map first, keep Apple Maps fallback.
- Modify `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj` — register new Swift files.
- Update `docs/product/user-stories-gap-audit.md` — mark in-app route-line story as planned/in progress.
- Future backend files after UX proof:
  - `backend/migrations/00003_tours.sql`
  - `backend/internal/models/models.go`
  - `backend/internal/repository/repository.go`
  - `backend/internal/http/handlers.go`
  - `backend/internal/http/router.go`
  - `ios-invisible-museum/InvisibleMuseum/APIClient.swift`

---

## Task 1: Add route models and route service

**Files:**
- Create: `ios-invisible-museum/InvisibleMuseum/WalkingRouteModels.swift`
- Create: `ios-invisible-museum/InvisibleMuseum/WalkingRouteService.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add route/tour models**

Create `WalkingRouteModels.swift`:

```swift
import CoreLocation
import MapKit

struct WalkingRoute: Equatable {
    let id: String
    let destinationSpaceID: String
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let distanceMeters: CLLocationDistance
    let expectedTravelTime: TimeInterval
    let route: MKRoute

    var distanceText: String {
        if distanceMeters >= 1609.344 {
            return String(format: "%.1f mi", distanceMeters / 1609.344)
        }
        return String(format: "%.0f ft", distanceMeters * 3.28084)
    }

    var etaText: String {
        let minutes = max(1, Int((expectedTravelTime / 60).rounded()))
        return "\(minutes) min walk"
    }
}

enum WalkingRouteState: Equatable {
    case idle
    case loading
    case loaded(WalkingRoute)
    case failed(String)
}

struct TourStop: Identifiable, Hashable, Sendable {
    let id: String
    let spaceID: String
    let order: Int
    let title: String
    let latitude: Double
    let longitude: Double
}

struct TourLeg: Identifiable, Hashable, Sendable {
    let id: String
    let fromStopID: String?
    let toStopID: String
    let order: Int
}

struct WalkingTour: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let estimatedMinutes: Int
    let stopIDs: [String]
}
```

- [ ] **Step 2: Add route service**

Create `WalkingRouteService.swift`:

```swift
import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class WalkingRouteService {
    private var activeDirections: MKDirections?

    func route(from source: CLLocationCoordinate2D, to space: MuseumSpace) async -> WalkingRouteState {
        activeDirections?.cancel()

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)))
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        activeDirections = directions

        do {
            let response = try await directions.calculate()
            guard let route = response.routes.first else {
                return .failed("No walking route found.")
            }
            return .loaded(
                WalkingRoute(
                    id: "\(space.id)-\(Int(source.latitude * 100000))-\(Int(source.longitude * 100000))",
                    destinationSpaceID: space.id,
                    sourceCoordinate: source,
                    destinationCoordinate: CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude),
                    distanceMeters: route.distance,
                    expectedTravelTime: route.expectedTravelTime,
                    route: route
                )
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == MKError.errorDomain, nsError.code == MKError.loadingThrottled.rawValue {
                return .failed("Maps is rate limiting route requests. Try again in a moment.")
            }
            return .failed(error.localizedDescription)
        }
    }

    func cancel() {
        activeDirections?.cancel()
        activeDirections = nil
    }
}
```

- [ ] **Step 3: Register files**

Add both Swift files to `InvisibleMuseum.xcodeproj/project.pbxproj`, following the existing app source file pattern.

- [ ] **Step 4: Build**

Run:

```bash
cd ios-invisible-museum && xcodebuild -project "InvisibleMuseum.xcodeproj" -scheme "InvisibleMuseum" -destination 'generic/platform=iOS Simulator' build
```

Expected: `** BUILD SUCCEEDED **`.

---

## Task 2: Render route line in MapListView

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/MapListView.swift`

- [ ] **Step 1: Add route state**

Add state near existing `@State` properties:

```swift
@State private var routeService = WalkingRouteService()
@State private var walkingRouteState: WalkingRouteState = .idle
```

- [ ] **Step 2: Add route overlay to Map**

Inside the existing `Map(position:interactionModes:)` content, after markers/user annotation:

```swift
if case .loaded(let walkingRoute) = walkingRouteState {
    MapPolyline(walkingRoute.route)
        .stroke(Museum.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        .mapOverlayLevel(level: .aboveRoads)
}
```

- [ ] **Step 3: Calculate route when selected space and user location exist**

Add a helper:

```swift
private func updateWalkingRoute() async {
    guard let selectedSpace else {
        walkingRouteState = .idle
        return
    }
    guard let userCoordinate = locationService.currentLocation?.coordinate else {
        walkingRouteState = .failed("Location is needed to show an in-app walking route.")
        return
    }
    walkingRouteState = .loading
    walkingRouteState = await routeService.route(from: userCoordinate, to: selectedSpace)
}
```

Trigger it with `.task(id:)` on selected space + coarse location key:

```swift
.task(id: routeTaskKey) {
    await updateWalkingRoute()
}
```

Add:

```swift
private var routeTaskKey: String {
    let selected = selectedSpace?.id ?? "none"
    let lat = locationService.currentLocation?.coordinate.latitude ?? 0
    let lng = locationService.currentLocation?.coordinate.longitude ?? 0
    return "\(selected)-\(Int(lat * 1000))-\(Int(lng * 1000))"
}
```

- [ ] **Step 4: Fit camera to route**

When route is loaded, set camera to route polyline bounding map rect:

```swift
private func focusRoute(_ route: MKRoute) {
    cameraPosition = .rect(route.polyline.boundingMapRect)
}
```

Call it after `.loaded` in `updateWalkingRoute()`.

- [ ] **Step 5: Build**

Run iOS build. Expected: build succeeds.

---

## Task 3: Show route summary in selected-site card

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/MapListView.swift`

- [ ] **Step 1: Add route summary UI**

In the selected-space card, add a compact route row:

```swift
private var routeSummary: some View {
    HStack(spacing: 8) {
        Image(systemName: "figure.walk")
            .foregroundStyle(Museum.green)
        switch walkingRouteState {
        case .idle:
            Text("Select a site to calculate walking route")
        case .loading:
            Text("Calculating walking route…")
        case .loaded(let route):
            Text("\(route.distanceText) · \(route.etaText)")
        case .failed(let message):
            Text(message)
        }
    }
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(Museum.muted)
}
```

Place `routeSummary` under the selected site title/tagline.

- [ ] **Step 2: Keep Apple Maps fallback**

Add or keep a fallback button on the selected-space card:

```swift
Button {
    openInAppleMaps(selectedSpace)
} label: {
    Label("Open in Apple Maps", systemImage: "map")
}
.buttonStyle(.museum(.secondary, size: .regular))
```

Add helper if not present:

```swift
private func openInAppleMaps(_ space: MuseumSpace?) {
    guard let space else { return }
    let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate(for: space)))
    item.name = space.name
    item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
}
```

- [ ] **Step 3: Build**

Run iOS build. Expected: build succeeds.

---

## Task 4: Start local tour model without backend

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/WalkingRouteModels.swift`
- Create: `ios-invisible-museum/InvisibleMuseum/SampleTours.swift`
- Modify: `ios-invisible-museum/InvisibleMuseum.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add sample tour**

Create `SampleTours.swift`:

```swift
import Foundation

enum SampleTours {
    static let downtownLoop = WalkingTour(
        id: "tour-downtown-loop",
        title: "Downtown Memory Loop",
        summary: "A short walk linking the station, theater, park, and local history campus.",
        estimatedMinutes: 45,
        stopIDs: [
            "sp-main-street-station",
            "sp-tivoli-theatre",
            "sp-fishel-park",
            "sp-downers-grove-museum"
        ]
    )
}
```

- [ ] **Step 2: Register file and build**

Add `SampleTours.swift` to Xcode project. Build must pass.

---

## Task 5: Tour preview UI in Map tab

**Files:**
- Modify: `ios-invisible-museum/InvisibleMuseum/MapListView.swift`

- [ ] **Step 1: Add tour chip/header**

Add a compact card above the map/list:

```swift
private var tourPreview: some View {
    HStack(spacing: 12) {
        Image(systemName: "figure.walk.motion")
            .foregroundStyle(Museum.green)
            .frame(width: 42, height: 42)
            .background(Museum.green.opacity(0.14), in: Circle())
        VStack(alignment: .leading, spacing: 3) {
            Text(SampleTours.downtownLoop.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Museum.text)
            Text("\(SampleTours.downtownLoop.estimatedMinutes) min · \(SampleTours.downtownLoop.stopIDs.count) stops")
                .font(Museum.bodyFont(12))
                .foregroundStyle(Museum.muted)
        }
        Spacer()
        Text("Preview")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Museum.blue)
    }
    .padding(14)
    .museumGlassCard(radius: Museum.Radius.md)
}
```

- [ ] **Step 2: Add action later**

For this task, the tour preview can be non-interactive or select the first stop. Do not add full tour navigation yet.

- [ ] **Step 3: Build**

Run iOS build. Expected: build succeeds.

---

## Task 6: Future backend tour schema plan

Do not implement this until the in-app route and local tour preview feel good.

**Files when ready:**
- Create: `backend/migrations/00003_tours.sql`
- Modify: `backend/internal/models/models.go`
- Modify: `backend/internal/repository/repository.go`
- Modify: `backend/internal/http/handlers.go`
- Modify: `backend/internal/http/router.go`
- Modify: `backend/internal/http/handlers_test.go`
- Modify: `ios-invisible-museum/InvisibleMuseum/APIClient.swift`

Recommended schema:

```sql
-- +goose Up
CREATE TABLE tours (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  estimated_minutes INTEGER NOT NULL DEFAULT 0,
  accent_hue DOUBLE PRECISION NOT NULL DEFAULT 0.58,
  is_published BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tour_stops (
  tour_id TEXT NOT NULL REFERENCES tours(id) ON DELETE CASCADE,
  space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  stop_order INTEGER NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (tour_id, space_id),
  UNIQUE (tour_id, stop_order)
);

CREATE INDEX idx_tour_stops_tour_order ON tour_stops(tour_id, stop_order);

-- +goose Down
DROP TABLE IF EXISTS tour_stops;
DROP TABLE IF EXISTS tours;
```

Endpoints when ready:

- `GET /api/v1/tours`
- `GET /api/v1/tours/{tour_id}`

Keep route geometry client-side. Do not store MapKit route polylines in Postgres in v1; routes depend on current user location and Apple routing data.

---

## Acceptance criteria

### In-app walking directions v1

- Opening in-app map from the directions prompt focuses on selected site.
- If current location exists, the map draws a walking route polyline.
- Selected-site card shows walking distance and ETA.
- Route loading/failure states are visible.
- Apple Maps fallback remains available.
- Build passes on simulator.

### Walking tours foundation

- Local `WalkingTour`, `TourStop`, and `TourLeg` models exist.
- Sample downtown loop exists as local seed data.
- Map tab can visually introduce the tour concept without backend work.
- Backend schema is planned but not implemented prematurely.

## Known constraints

- `MKDirections` is one origin/destination route per request; chained tours must be modeled as ordered legs.
- Avoid recalculating on every tiny location update; throttle or quantize location keys.
- Apple Maps is still the right fallback for full turn-by-turn navigation.
- In-app v1 should focus on route visualization, distance, ETA, and next stop — not full navigation engine behavior.
