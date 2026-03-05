import Foundation

public enum VolumeRampPlanner {
    public static func plan(from: Double, to: Double, durationMs: Int, stepMs: Int = 20) -> [Double] {
        let clampedFrom = min(max(from, 0), 1)
        let clampedTo = min(max(to, 0), 1)

        guard durationMs > 0 else {
            return [clampedTo]
        }

        let steps = max(1, durationMs / max(1, stepMs))
        let delta = clampedTo - clampedFrom

        return (1...steps).map { index in
            let progress = Double(index) / Double(steps)
            return min(max(clampedFrom + delta * progress, 0), 1)
        }
    }
}
