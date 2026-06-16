import ARKit
import CoreLocation

enum ARExperienceMode: Equatable {
    case geoAR
    case worldTrackingFallback(reason: String)
    case guidanceOnly(UserProximity)
    case unsupported(reason: String)
}

enum ARCapabilityResolver {
    static func resolve(
        proximity: UserProximity,
        geoTrackingSupported: Bool = ARGeoTrackingConfiguration.isSupported,
        worldTrackingSupported: Bool = ARWorldTrackingConfiguration.isSupported
    ) -> ARExperienceMode {
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
