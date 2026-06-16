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
