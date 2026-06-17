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

    static func == (lhs: WalkingRoute, rhs: WalkingRoute) -> Bool {
        lhs.id == rhs.id
            && lhs.destinationSpaceID == rhs.destinationSpaceID
            && lhs.sourceCoordinate.latitude == rhs.sourceCoordinate.latitude
            && lhs.sourceCoordinate.longitude == rhs.sourceCoordinate.longitude
            && lhs.destinationCoordinate.latitude == rhs.destinationCoordinate.latitude
            && lhs.destinationCoordinate.longitude == rhs.destinationCoordinate.longitude
            && lhs.distanceMeters == rhs.distanceMeters
            && lhs.expectedTravelTime == rhs.expectedTravelTime
    }

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

struct TourSpace: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let latitude: Double
    let longitude: Double
    let tagline: String
}

struct TourStop: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let order: Int
    let spaceID: String
    let space: TourSpace

    private enum CodingKeys: String, CodingKey {
        case id
        case order
        case spaceID = "spaceId"
        case space
    }

    var title: String { space.title }
}

struct TourLeg: Identifiable, Hashable, Sendable {
    let id: String
    let fromStopID: String?
    let toStopID: String
    let order: Int
}

struct WalkingTour: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let estimatedMinutes: Int
    let published: Bool
    let stops: [TourStop]

    var stopIDs: [String] { stops.map(\.spaceID) }
}

struct WalkingTourProgress: Codable, Equatable, Sendable {
    let tourID: String
    var currentStopID: String?
    var visitedStopIDs: Set<String>

    init(tourID: String, currentStopID: String? = nil, visitedStopIDs: Set<String> = []) {
        self.tourID = tourID
        self.currentStopID = currentStopID
        self.visitedStopIDs = visitedStopIDs
    }
}
