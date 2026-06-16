#if canImport(UIKit) && canImport(SwiftUI)
import ARKit
import RealityKit
import SwiftUI

struct ARCameraView: UIViewRepresentable {
    let mode: ARExperienceMode
    let space: MuseumSpace
    let session: ARMuseumSession

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.session.delegate = context.coordinator
        context.coordinator.update(mode: mode, space: space, session: session, on: arView)
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        arView.session.delegate = context.coordinator
        context.coordinator.update(mode: mode, space: space, session: session, on: arView)
    }

    static func dismantleUIView(_ arView: ARView, coordinator: Coordinator) {
        coordinator.cancel()
        arView.session.delegate = nil
        arView.session.pause()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        var mode: ARExperienceMode = .guidanceOnly(.unknown)
        var space: MuseumSpace?
        weak var session: ARMuseumSession?
        weak var arView: ARView?
        private var activeKey: String?
        private var geoAvailabilityToken = UUID()
        private var isActive = true

        func update(mode: ARExperienceMode, space: MuseumSpace, session: ARMuseumSession, on arView: ARView) {
            isActive = true
            self.mode = mode
            self.space = space
            self.session = session
            self.arView = arView

            let key = "\(key(for: mode)):\(space.id)"
            guard key != activeKey else { return }
            activeKey = key

            clearAnchors(on: arView)

            switch mode {
            case .geoAR:
                runGeoTracking(on: arView)
            case .worldTrackingFallback(let reason):
                runWorldTracking(on: arView, reason: reason)
            case .guidanceOnly, .unsupported:
                break
            }
        }

        private func runGeoTracking(on arView: ARView) {
            session?.stage = .checkingGeoAvailability
            let token = UUID()
            geoAvailabilityToken = token

            if #available(iOS 14.0, *) {
                guard let space else { return }
                let target = CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)
                ARGeoTrackingConfiguration.checkAvailability(at: target) { [weak self, weak arView] available, error in
                    guard let self, self.isActive, self.geoAvailabilityToken == token, let arView else { return }
                    if available {
                        Task { @MainActor in
                            guard self.isActive else { return }
                            self.runGeoConfiguration(on: arView)
                        }
                        return
                    }

                    let reason = error?.localizedDescription ?? "Geo tracking is unavailable here. Showing approximate nearby AR."
                    if ARWorldTrackingConfiguration.isSupported {
                        Task { @MainActor in
                            guard self.isActive else { return }
                            self.mode = .worldTrackingFallback(reason: reason)
                            self.runWorldTracking(on: arView, reason: reason)
                        }
                    } else {
                        Task { @MainActor in
                            self.session?.stage = .unsupported(reason)
                        }
                    }
                }
            } else if ARWorldTrackingConfiguration.isSupported {
                runWorldTracking(on: arView, reason: "Geo tracking is unavailable on this system. Showing approximate nearby AR.")
            } else {
                session?.stage = .unsupported("AR is not supported on this device.")
            }
        }

        @MainActor
        private func runGeoConfiguration(on arView: ARView) {
            guard let space else { return }
            let configuration = ARGeoTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            session?.stage = .localizing
            placeGeoMarkers(in: arView, space: space)
        }

        @MainActor
        private func runWorldTracking(on arView: ARView, reason: String) {
            guard let space else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            session?.stage = .fallback(reason)
            placeWorldMarkers(in: arView, space: space)
        }

        private func placeGeoMarkers(in arView: ARView, space: MuseumSpace) {
            clearAnchors(on: arView)
            let origin = CLLocationCoordinate2D(latitude: space.latitude, longitude: space.longitude)
            for exhibit in space.exhibits {
                let coordinate = GeoMath.coordinate(
                    from: origin,
                    eastMeters: Double(exhibit.offset.x),
                    northMeters: Double(-exhibit.offset.z)
                )
                let geoAnchor = ARGeoAnchor(coordinate: coordinate)
                let anchorEntity = AnchorEntity(anchor: geoAnchor)
                anchorEntity.addChild(ExhibitEntityFactory.makeMarker(for: exhibit))
                arView.scene.addAnchor(anchorEntity)
            }
            session?.placedExhibitCount = space.exhibits.count
        }

        private func placeWorldMarkers(in arView: ARView, space: MuseumSpace) {
            clearAnchors(on: arView)
            for exhibit in space.exhibits {
                let anchor = AnchorEntity(world: exhibit.offset)
                anchor.addChild(ExhibitEntityFactory.makeMarker(for: exhibit))
                arView.scene.addAnchor(anchor)
            }
            session?.placedExhibitCount = space.exhibits.count
        }

        private func clearAnchors(on arView: ARView) {
            let anchors = arView.scene.anchors
            for anchor in anchors {
                arView.scene.removeAnchor(anchor)
            }
        }

        private func key(for mode: ARExperienceMode) -> String {
            switch mode {
            case .geoAR:
                return "geoAR"
            case .worldTrackingFallback(let reason):
                return "world:\(reason)"
            case .guidanceOnly(let proximity):
                return "guidance:\(proximity)"
            case .unsupported(let reason):
                return "unsupported:\(reason)"
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            Task { @MainActor in
                switch self.mode {
                case .geoAR:
                    self.session?.stage = .ready
                case .worldTrackingFallback(let reason):
                    self.session?.stage = .fallback(reason)
                case .guidanceOnly, .unsupported:
                    break
                }
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            let reason = error.localizedDescription
            Task { @MainActor in
                switch self.mode {
                case .geoAR:
                    if let arView = self.arView, ARWorldTrackingConfiguration.isSupported {
                        self.mode = .worldTrackingFallback(reason: reason)
                        self.runWorldTracking(on: arView, reason: reason)
                    } else {
                        self.session?.stage = .unsupported(reason)
                    }
                case .worldTrackingFallback:
                    self.session?.stage = .fallback(reason)
                case .guidanceOnly, .unsupported:
                    self.session?.stage = .unsupported(reason)
                }
            }
        }

        func cancel() {
            isActive = false
            geoAvailabilityToken = UUID()
            session?.teardown()
            session = nil
            arView = nil
        }
    }
}

#endif
