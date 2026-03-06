import Foundation

struct FireRedSpeechGateResult {
    let rawSpeaking: Bool
    let ambientLevelDb: Float?
    let deltaDb: Float
    let remainingCalibrationFrames: Int
    let candidateActive: Bool
}

final class FireRedSpeechGate {
    private let activationProbability: Float
    private let sustainProbability: Float
    private let activationLevelDeltaDb: Float
    private let activationAbsoluteLevelDb: Float
    private let sustainAbsoluteLevelDb: Float
    private let ambientRiseAlpha: Float
    private let ambientFallAlpha: Float
    private let calibrationFrameCount: Int

    private(set) var ambientLevelDb: Float?
    private(set) var remainingCalibrationFrames: Int
    private(set) var candidateActive = false

    init(
        speechThreshold: Float,
        activationProbabilityFloor: Float = 0.9,
        sustainProbabilityFloor: Float = 0.7,
        activationLevelDeltaDb: Float = 8,
        activationAbsoluteLevelDb: Float = -39,
        sustainAbsoluteLevelDb: Float = -43,
        ambientRiseAlpha: Float = 0.12,
        ambientFallAlpha: Float = 0.04,
        calibrationFrameCount: Int = 50
    ) {
        self.activationProbability = max(speechThreshold, activationProbabilityFloor)
        self.sustainProbability = max(speechThreshold, sustainProbabilityFloor)
        self.activationLevelDeltaDb = activationLevelDeltaDb
        self.activationAbsoluteLevelDb = activationAbsoluteLevelDb
        self.sustainAbsoluteLevelDb = sustainAbsoluteLevelDb
        self.ambientRiseAlpha = ambientRiseAlpha
        self.ambientFallAlpha = ambientFallAlpha
        self.calibrationFrameCount = calibrationFrameCount
        self.remainingCalibrationFrames = calibrationFrameCount
    }

    func process(probability: Float, levelDb: Float) -> FireRedSpeechGateResult {
        let ambientLevelDb = self.ambientLevelDb
        let deltaDb = ambientLevelDb.map { levelDb - $0 } ?? .nan
        let rawSpeaking = evaluate(probability: probability, levelDb: levelDb, deltaDb: deltaDb)

        updateAmbientLevel(with: levelDb, allowRise: !rawSpeaking)
        if remainingCalibrationFrames > 0 {
            remainingCalibrationFrames -= 1
        }

        return FireRedSpeechGateResult(
            rawSpeaking: rawSpeaking,
            ambientLevelDb: ambientLevelDb,
            deltaDb: deltaDb,
            remainingCalibrationFrames: remainingCalibrationFrames,
            candidateActive: candidateActive
        )
    }

    func reset() {
        ambientLevelDb = nil
        remainingCalibrationFrames = calibrationFrameCount
        candidateActive = false
    }

    private func evaluate(probability: Float, levelDb: Float, deltaDb: Float) -> Bool {
        guard remainingCalibrationFrames == 0 else {
            candidateActive = false
            return false
        }

        if shouldActivate(probability: probability, levelDb: levelDb, deltaDb: deltaDb) {
            candidateActive = true
            return true
        }

        if candidateActive && shouldSustain(probability: probability, levelDb: levelDb) {
            return true
        }

        candidateActive = false
        return false
    }

    private func shouldActivate(probability: Float, levelDb: Float, deltaDb: Float) -> Bool {
        guard probability >= activationProbability else { return false }
        guard levelDb >= activationAbsoluteLevelDb else { return false }
        return deltaDb.isFinite && deltaDb >= activationLevelDeltaDb
    }

    private func shouldSustain(probability: Float, levelDb: Float) -> Bool {
        guard probability >= sustainProbability else { return false }
        return levelDb >= sustainAbsoluteLevelDb
    }

    private func updateAmbientLevel(with levelDb: Float, allowRise: Bool) {
        guard levelDb.isFinite else { return }

        if let ambientLevelDb {
            let alpha: Float
            if levelDb >= ambientLevelDb {
                alpha = allowRise ? ambientRiseAlpha : 0
            } else {
                alpha = ambientFallAlpha
            }
            self.ambientLevelDb = ambientLevelDb + alpha * (levelDb - ambientLevelDb)
        } else {
            ambientLevelDb = levelDb
        }
    }
}
