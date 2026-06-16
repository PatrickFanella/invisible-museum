import RealityKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ExhibitEntityFactory {
    static func makeMarker(for exhibit: Exhibit) -> Entity {
        let mesh = MeshResource.generateSphere(radius: 0.08)
        #if canImport(UIKit)
        let color = UIColor.systemBlue.withAlphaComponent(0.85)
        #elseif canImport(AppKit)
        let color = NSColor.systemBlue.withAlphaComponent(0.85)
        #else
        fatalError("Unsupported platform")
        #endif
        let material = SimpleMaterial(color: color, roughness: 0.2, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = exhibit.id
        return entity
    }
}
