import Foundation
import Observation

@MainActor
@Observable
final class ARMuseumSession {
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

    var stage: Stage = .requestingPermissions
    var placedExhibitCount: Int = 0
    var selectedExhibitID: String?

    func teardown() {}
}
