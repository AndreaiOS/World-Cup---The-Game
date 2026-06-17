import CoreGraphics

/// Maps engine goal coordinates (x∈[-1,1], y∈[0,1]) to points inside a scene.
/// The goal mouth occupies the top portion of the scene; the penalty spot is
/// near the bottom center.
struct GoalGeometry {
    let sceneSize: CGSize

    var goalWidth: CGFloat { sceneSize.width * 0.78 }
    var goalHeight: CGFloat { sceneSize.height * 0.27 }
    var goalCenterX: CGFloat { sceneSize.width / 2 }
    var goalLineY: CGFloat { sceneSize.height * 0.50 }      // bottom of the goal mouth
    var crossbarY: CGFloat { goalLineY + goalHeight }
    var penaltySpot: CGPoint { CGPoint(x: sceneSize.width / 2, y: sceneSize.height * 0.17) }

    /// Where in the scene a shot aimed at (aimX, aimY) lands.
    func point(aimX: Double, aimY: Double) -> CGPoint {
        let x = goalCenterX + CGFloat(aimX) * (goalWidth / 2)
        let y = goalLineY + CGFloat(aimY) * goalHeight
        return CGPoint(x: x, y: y)
    }

    /// Where the keeper stands/dives for a horizontal commit x∈[-1,1].
    func keeperPoint(x: Double) -> CGPoint {
        CGPoint(x: goalCenterX + CGFloat(x) * (goalWidth / 2),
                y: goalLineY + goalHeight * 0.25)
    }
}
