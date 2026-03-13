import Foundation
import RuntimeSupport

public protocol VolumeDucking {
    func duck(to downTo: Double, attackMs: Int)
    func restore(releaseMs: Int)
    func stopAndRestore()
}

public final class VolumeDucker: VolumeDucking {
    private let controller: SystemVolumeControlling
    private let queue = DispatchQueue(label: "aptune.volume.ducker")

    private var baselineVolume: Double?
    private var rampGeneration: Int = 0

    public init(controller: SystemVolumeControlling) {
        self.controller = controller
    }

    public func duck(to downTo: Double, attackMs: Int) {
        queue.async {
            let target = min(max(downTo, 0), 1)
            do {
                if self.baselineVolume == nil {
                    self.baselineVolume = try self.controller.getCurrentVolume()
                }
                let from = try self.controller.getCurrentVolume()
                self.startRamp(from: from, to: target, durationMs: attackMs)
            } catch {
                ConsoleOutput.writeStderrLine("[ERROR] Failed to duck volume: \(error)")
            }
        }
    }

    public func restore(releaseMs: Int) {
        queue.async {
            guard let baseline = self.baselineVolume else { return }
            do {
                let from = try self.controller.getCurrentVolume()
                self.startRamp(from: from, to: baseline, durationMs: releaseMs)
                self.baselineVolume = nil
            } catch {
                ConsoleOutput.writeStderrLine("[ERROR] Failed to restore volume: \(error)")
            }
        }
    }

    public func stopAndRestore() {
        let semaphore = DispatchSemaphore(value: 0)
        queue.async {
            defer { semaphore.signal() }
            self.rampGeneration += 1
            guard let baseline = self.baselineVolume else { return }
            do {
                try self.controller.setVolume(baseline)
                self.baselineVolume = nil
            } catch {
                ConsoleOutput.writeStderrLine("[ERROR] Failed to restore volume on shutdown: \(error)")
            }
        }
        semaphore.wait()
    }

    private func startRamp(from: Double, to: Double, durationMs: Int) {
        rampGeneration += 1
        let generation = rampGeneration
        let values = VolumeRampPlanner.plan(from: from, to: to, durationMs: durationMs)

        for value in values {
            guard generation == rampGeneration else { return }
            do {
                try controller.setVolume(value)
            } catch {
                ConsoleOutput.writeStderrLine("[ERROR] Failed setting volume during ramp: \(error)")
                return
            }
            if durationMs > 0 {
                usleep(useconds_t(20_000))
            }
        }
    }
}
