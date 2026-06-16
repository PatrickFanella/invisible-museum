import Foundation
import Observation

@MainActor
@Observable
final class ARMuseumSession {
    enum Stage: Equatable { case findingFloor, ready, limited }
    var stage: Stage = .ready
    var placedExhibitCount: Int = 0
    var selectedExhibitID: String?
    func teardown() {}
}
