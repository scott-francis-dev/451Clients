import SwiftUI
import RealityKit
import Combine

// MARK: - Chart3DView

enum Chart3DMode {
    case scatter, surface
}

/// RealityKit-backed 3D chart view — scatter point cloud and surface grid.
/// Supports drag-to-rotate and pinch-to-zoom, matching the molecule viewer pattern.
struct Chart3DView: View {
    @ObservedObject var chartData: ChartData
    let mode: Chart3DMode

    @State private var yaw: Float = -0.6
    @State private var pitch: Float = 0.4
    @State private var dragStartYaw: Float = 0
    @State private var dragStartPitch: Float = 0
    @State private var currentScale: Float = 1.0
    @State private var baseScale: Float = 1.0
    @State private var autorotate: Bool = true
    @State private var isDragging = false

    private var sceneKey: String {
        switch mode {
        case .scatter:
            return "scatter-\(chartData.scatter3DPoints.count)-\(chartData.surface3DColormap.rawValue)"
        case .surface:
            let rows = chartData.surface3DGrid.count
            let cols = chartData.surface3DGrid.first?.count ?? 0
            return "surface-\(rows)x\(cols)-\(chartData.surface3DColormap.rawValue)"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if hasData {
                RealityView { content in
                    let root = makeRoot()
                    content.add(root)
                } update: { content in
                    guard let root = content.entities.first else { return }
                    if root.name != sceneKey {
                        root.children.removeAll()
                        root.name = sceneKey
                        populate(root)
                    }
                    let qYaw   = simd_quatf(angle: yaw,   axis: [0, 1, 0])
                    let qPitch = simd_quatf(angle: pitch, axis: [1, 0, 0])
                    root.transform.rotation = simd_mul(qYaw, qPitch)
                    root.transform.scale    = SIMD3<Float>(repeating: currentScale)
                }
                .gesture(DragGesture()
                    .onChanged { v in
                        isDragging = true
                        autorotate = false
                        yaw   = dragStartYaw   + Float(v.translation.width)  * 0.005
                        pitch = dragStartPitch + Float(v.translation.height) * 0.005
                    }
                    .onEnded { _ in
                        dragStartYaw   = yaw
                        dragStartPitch = pitch
                        isDragging     = false
                    }
                )
                .gesture(MagnifyGesture()
                    .onChanged { v in
                        currentScale = max(0.3, min(4.0, baseScale * Float(v.magnification)))
                    }
                    .onEnded { _ in baseScale = currentScale }
                )
                .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { _ in
                    guard autorotate && !isDragging else { return }
                    yaw += 0.004
                }

                // Controls overlay
                HStack(spacing: 6) {
                    Button {
                        autorotate.toggle()
                    } label: {
                        Image(systemName: autorotate ? "pause.circle.fill" : "play.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        yaw = -0.6; pitch = 0.4; currentScale = 1.0; baseScale = 1.0
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(8)

            } else {
                emptyState
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: mode == .surface ? "cube.transparent" : "cube")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(mode == .surface
                 ? "No surface data.\nUse the Type tab → Generate Sample Surface."
                 : "No 3D points.\nUse the Type tab → Generate Sample Scatter.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hasData: Bool {
        switch mode {
        case .scatter: return !chartData.scatter3DPoints.isEmpty
        case .surface: return !chartData.surface3DGrid.isEmpty && !(chartData.surface3DGrid.first?.isEmpty ?? true)
        }
    }

    // MARK: - Scene building

    private func makeRoot() -> Entity {
        let root = Entity()
        root.name = sceneKey
        populate(root)
        return root
    }

    private func populate(_ root: Entity) {
        switch mode {
        case .scatter: buildScatter(root)
        case .surface: buildSurface(root)
        }
        addAxes(root)
    }

    // MARK: - Scatter

    private func buildScatter(_ root: Entity) {
        let pts = chartData.scatter3DPoints
        guard !pts.isEmpty else { return }

        let xs = pts.map(\.x), ys = pts.map(\.y), zs = pts.map(\.z)
        let (xMin, xMax) = (xs.min()!, xs.max()!)
        let (yMin, yMax) = (ys.min()!, ys.max()!)
        let (zMin, zMax) = (zs.min()!, zs.max()!)

        func norm(_ v: Double, lo: Double, hi: Double) -> Float {
            hi > lo ? Float((v - lo) / (hi - lo)) * 1.4 - 0.7 : 0
        }

        let cmap = chartData.surface3DColormap
        for pt in pts {
            let nx = norm(pt.x, lo: xMin, hi: xMax)
            let ny = norm(pt.y, lo: yMin, hi: yMax)
            let nz = norm(pt.z, lo: zMin, hi: zMax)
            let t  = Double((ny + 0.7) / 1.4)   // color by y height

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.035),
                materials: [SimpleMaterial(color: cmap.color(for: t).resolvedPlatformColor, isMetallic: false)]
            )
            sphere.position = SIMD3<Float>(nx, ny, nz)
            root.addChild(sphere)
        }
    }

    // MARK: - Surface

    private func buildSurface(_ root: Entity) {
        let grid = chartData.surface3DGrid
        guard !grid.isEmpty, let firstRow = grid.first, !firstRow.isEmpty else { return }

        let rows = grid.count
        let cols = firstRow.count
        let allVals = grid.flatMap { $0 }
        let zMin = allVals.min() ?? 0
        let zMax = allVals.max() ?? 1
        let zSpan = zMax > zMin ? zMax - zMin : 1

        let cmap = chartData.surface3DColormap
        let scaleXZ: Float = 1.4 / Float(max(rows, cols) - 1)

        for r in 0..<(rows - 1) {
            for c in 0..<(cols - 1) {
                // Build a quad as two triangles using a thin box for each grid cell
                let avgZ = (grid[r][c] + grid[r][c+1] + grid[r+1][c] + grid[r+1][c+1]) / 4.0
                let t = (avgZ - zMin) / zSpan

                let cellH = max(0.005, Float(avgZ - zMin) / Float(zSpan) * 0.8 + 0.02)

                let box = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(scaleXZ * 0.98, cellH, scaleXZ * 0.98)),
                    materials: [SimpleMaterial(color: cmap.color(for: t).resolvedPlatformColor, isMetallic: false)]
                )
                let px = Float(c) * scaleXZ - 0.7
                let py = cellH / 2 - 0.4
                let pz = Float(r) * scaleXZ - 0.7
                box.position = SIMD3<Float>(px, py, pz)
                root.addChild(box)
            }
        }
    }

    // MARK: - Axes

    private func addAxes(_ root: Entity) {
        let axisLength: Float = 0.75
        let axisRadius: Float = 0.006
        let origin = SIMD3<Float>(-0.7, -0.7, -0.7)

        addAxisCylinder(root, length: axisLength, radius: axisRadius,
                        position: origin + [axisLength/2, 0, 0],
                        rotation: simd_quatf(angle: .pi/2, axis: [0, 0, 1]),
                        color: .systemRed)
        addAxisCylinder(root, length: axisLength, radius: axisRadius,
                        position: origin + [0, axisLength/2, 0],
                        rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                        color: .systemGreen)
        addAxisCylinder(root, length: axisLength, radius: axisRadius,
                        position: origin + [0, 0, axisLength/2],
                        rotation: simd_quatf(angle: .pi/2, axis: [1, 0, 0]),
                        color: .systemBlue)
    }

    private func addAxisCylinder(_ root: Entity, length: Float, radius: Float,
                                  position: SIMD3<Float>,
                                  rotation: simd_quatf,
                                  color: SimpleMaterial.Color) {
        let cyl = ModelEntity(
            mesh: .generateCylinder(height: length, radius: radius),
            materials: [SimpleMaterial(color: color, isMetallic: false)]
        )
        cyl.position = position
        cyl.transform.rotation = rotation
        root.addChild(cyl)
    }
}

// MARK: - Color helpers

extension HeatmapColormap {
    func platformColor(for t: Double) -> Color {
        color(for: t)
    }
}

extension Color {
    var resolvedPlatformColor: SimpleMaterial.Color {
        #if canImport(UIKit)
        UIColor(self)
        #else
        NSColor(self)
        #endif
    }
}
