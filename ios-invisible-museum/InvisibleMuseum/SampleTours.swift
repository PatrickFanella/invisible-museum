import Foundation

enum SampleTours {
    static let downtownLoop = WalkingTour(
        id: "tour-downtown-memory-loop",
        title: "Downtown Memory Loop",
        summary: "A short walk linking the station, theater, park, and local history campus.",
        estimatedMinutes: 45,
        published: true,
        stops: [
            stop(id: "tour-stop-main-street-station", order: 1, spaceID: "sp-main-street-station"),
            stop(id: "tour-stop-tivoli-theatre", order: 2, spaceID: "sp-tivoli-theatre"),
            stop(id: "tour-stop-fishel-park", order: 3, spaceID: "sp-fishel-park"),
            stop(id: "tour-stop-downers-grove-museum", order: 4, spaceID: "sp-downers-grove-museum")
        ]
    )

    private static func stop(id: String, order: Int, spaceID: String) -> TourStop {
        let space = fallbackSpace(for: spaceID)
        return TourStop(
            id: id,
            order: order,
            spaceID: spaceID,
            space: space
        )
    }

    private static func fallbackSpace(for spaceID: String) -> TourSpace {
        switch spaceID {
        case "sp-main-street-station":
            return TourSpace(id: spaceID, title: "Main Street Station", latitude: 41.7959, longitude: -88.0092, tagline: "Downtown Downers Grove rail corridor")
        case "sp-tivoli-theatre":
            return TourSpace(id: spaceID, title: "Tivoli Theatre", latitude: 41.7952, longitude: -88.0099, tagline: "Historic downtown movie palace")
        case "sp-fishel-park":
            return TourSpace(id: spaceID, title: "Fishel Park", latitude: 41.7944, longitude: -88.0118, tagline: "Civic green and concert space")
        case "sp-downers-grove-museum":
            return TourSpace(id: spaceID, title: "Downers Grove Museum", latitude: 41.8083, longitude: -88.0111, tagline: "Local history campus")
        default:
            return TourSpace(id: spaceID, title: spaceID, latitude: 0, longitude: 0, tagline: "")
        }
    }
}
