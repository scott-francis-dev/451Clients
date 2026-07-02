import SwiftUI
import RealityKit
import Combine

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
#endif

struct RealityKitMoleculeView: View {
    let molecule: any MolecularStructure
    @Binding var autorotate: Bool
    @Binding var visualizationStyle: MoleculeVisualizationStyle

    @State private var yaw: Float = 0
    @State private var pitch: Float = 0
    @State private var dragStartYaw: Float = 0
    @State private var dragStartPitch: Float = 0
    @State private var currentScale: Float = 1.0
    @State private var baseScale: Float = 1.0
    @State private var isDragging = false

    private var sceneSignature: String {
        "\(molecule.atoms.count)-\(molecule.bonds.count)-\(molecule.centerOfMass.x)-\(visualizationStyle)"
    }

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = sceneSignature
            populate(root)
            content.add(root)
        } update: { content in
            guard let root = content.entities.first else { return }
            if root.name != sceneSignature {
                root.children.removeAll()
                root.name = sceneSignature
                populate(root)
            }
            let qYaw = simd_quatf(angle: yaw, axis: [0, 1, 0])
            let qPitch = simd_quatf(angle: pitch, axis: [1, 0, 0])
            root.transform.rotation = simd_mul(qYaw, qPitch)
            root.transform.scale = SIMD3<Float>(repeating: currentScale)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    yaw = dragStartYaw + Float(value.translation.width) * 0.005
                    pitch = dragStartPitch + Float(value.translation.height) * 0.005
                }
                .onEnded { _ in
                    dragStartYaw = yaw
                    dragStartPitch = pitch
                    isDragging = false
                }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    currentScale = max(0.2, min(4.0, baseScale * Float(value.magnification)))
                }
                .onEnded { _ in
                    baseScale = currentScale
                }
        )
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            guard autorotate && !isDragging else { return }
            yaw += 0.005
        }
    }

    // MARK: - Scene building

    private var coordinateScale: Float {
        let extent = max(
            molecule.maximumLimits.x - molecule.minimumLimits.x,
            molecule.maximumLimits.y - molecule.minimumLimits.y,
            molecule.maximumLimits.z - molecule.minimumLimits.z
        )
        // Target world size ~1.4 units — fits comfortably in the RealityView
        // viewport, which sits roughly 2 units from the default camera.
        return extent > 0 ? (1.4 / extent) : 0.18
    }

    private func populate(_ root: Entity) {
        let center = molecule.centerOfMass
        let scale = coordinateScale

        switch visualizationStyle {
        case .spacefilling:
            for atom in molecule.atoms {
                root.addChild(makeAtomEntity(atom: atom, center: center, scale: scale, radiusFactor: 1.0))
            }
        case .ballAndStick:
            for atom in molecule.atoms {
                root.addChild(makeAtomEntity(atom: atom, center: center, scale: scale, radiusFactor: 0.4))
            }
            for bond in molecule.bonds {
                if let entity = makeBondEntity(bond: bond, center: center, scale: scale) {
                    root.addChild(entity)
                }
            }
        case .electronCloud:
            for atom in molecule.atoms {
                root.addChild(makeAtomEntity(atom: atom, center: center, scale: scale, radiusFactor: 1.6, cloud: true))
            }
        }
    }

    private func makeAtomEntity(atom: Atom, center: Coordinate, scale: Float, radiusFactor: Float, cloud: Bool = false) -> ModelEntity {
        let radius = atom.element.vanderWaalsRadius * scale * radiusFactor
        let mesh = MeshResource.generateSphere(radius: radius)
        let material: any RealityKit.Material = cloud ? cloudMaterial(for: atom.element) : atomMaterial(for: atom.element)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        let pos = atom.location - center
        entity.position = SIMD3<Float>(pos.x * scale, pos.y * scale, pos.z * scale)
        return entity
    }

    private func makeBondEntity(bond: Bond, center: Coordinate, scale: Float) -> ModelEntity? {
        let start = bond.start - center
        let end = bond.end - center
        let s = SIMD3<Float>(start.x * scale, start.y * scale, start.z * scale)
        let e = SIMD3<Float>(end.x * scale, end.y * scale, end.z * scale)
        let diff = e - s
        let length = simd_length(diff)
        guard length > 0.0001 else { return nil }

        let bondRadius = scale * 0.06
        let mesh = MeshResource.generateCylinder(height: length, radius: bondRadius)
        let entity = ModelEntity(mesh: mesh, materials: [bondMaterial()])
        entity.position = (s + e) / 2
        entity.orientation = orientationAlignedToY(diff)
        return entity
    }

    /// Returns a quaternion that rotates the Y-axis to point along `direction`.
    private func orientationAlignedToY(_ direction: SIMD3<Float>) -> simd_quatf {
        let dir = simd_normalize(direction)
        let up = SIMD3<Float>(0, 1, 0)
        let axis = simd_cross(up, dir)
        let axisLen = simd_length(axis)
        guard axisLen > 0.001 else {
            // Parallel or anti-parallel to Y
            return simd_dot(up, dir) > 0
                ? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                : simd_quatf(angle: .pi, axis: [1, 0, 0])
        }
        let angle = acos(max(-1, min(1, simd_dot(up, dir))))
        return simd_quatf(angle: angle, axis: simd_normalize(axis))
    }

    // MARK: - Materials

    private func atomMaterial(for element: Atom.Element) -> SimpleMaterial {
        let c = element.color
        var mat = SimpleMaterial()
        mat.color = .init(tint: PlatformColor(red: CGFloat(c.red), green: CGFloat(c.green), blue: CGFloat(c.blue), alpha: 1))
        mat.roughness = .init(floatLiteral: 0.3)
        return mat
    }

    private func bondMaterial() -> SimpleMaterial {
        var mat = SimpleMaterial()
        mat.color = .init(tint: PlatformColor(white: 0.55, alpha: 1))
        mat.roughness = .init(floatLiteral: 0.4)
        return mat
    }

    private func cloudMaterial(for element: Atom.Element) -> PhysicallyBasedMaterial {
        let c = element.color
        var mat = PhysicallyBasedMaterial()
        let tint = PlatformColor(
            red: CGFloat(c.red),
            green: CGFloat(c.green),
            blue: CGFloat(c.blue),
            alpha: 0.35
        )
        mat.baseColor = .init(tint: tint)
        mat.roughness = .init(floatLiteral: 0.85)
        mat.metallic = .init(floatLiteral: 0.0)
        mat.blending = .transparent(opacity: .init(floatLiteral: 0.35))
        mat.faceCulling = .none
        return mat
    }
}
