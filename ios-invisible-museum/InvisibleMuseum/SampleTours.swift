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
