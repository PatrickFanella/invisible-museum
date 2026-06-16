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
        guard authorizationState == .authorized else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        #if os(iOS) || os(tvOS) || os(visionOS)
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
        #endif
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationState(manager.authorizationStatus)
            if authorizationState == .authorized {
                start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            currentHeading = newHeading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastErrorMessage = error.localizedDescription
        }
    }

    private func updateAuthorizationState(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationState = .authorized
        case .denied, .restricted:
            authorizationState = .denied
        case .notDetermined:
            authorizationState = .unknown
        @unknown default:
            authorizationState = .unknown
        }
    }
}
