import Foundation
import CoreGraphics

/// Converts a raw swipe in scene points into normalized engine inputs.
/// Scene coordinates have y up, so an upward flick toward the goal yields dy > 0.
struct SwipeReader {
    let sceneSize: CGSize

    func read(start: CGPoint, end: CGPoint, control: CGPoint,
              duration: TimeInterval) -> (dx: Double, dy: Double, speed: Double, curve: Double) {
        let w = Double(sceneSize.width)
        let h = Double(sceneSize.height)

        // A horizontal flick of ~35% of width = full aim left/right.
        let dx = Double(end.x - start.x) / (w * 0.35)
        // An upward flick of ~45% of height = full aim to the crossbar.
        let dy = Double(end.y - start.y) / (h * 0.45)

        let dist = Double(hypot(end.x - start.x, end.y - start.y))
        let pxPerSec = dist / max(duration, 0.016)
        // ~2000 px/s reads as full power.
        let speed = pxPerSec / 2000.0

        // Curve = sideways offset of the control (mid) point from the straight
        // line start->end, normalized by half the swipe length.
        let mx = Double(end.x - start.x), my = Double(end.y - start.y)
        let len = max(hypot(mx, my), 1)
        let cx = Double(control.x - start.x), cy = Double(control.y - start.y)
        let cross = (mx * cy - my * cx) / len     // signed perpendicular distance
        let curve = cross / (len * 0.5)

        return (dx, dy, speed, curve)
    }
}
