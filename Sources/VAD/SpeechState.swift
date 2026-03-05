import Foundation

public struct SpeechState: Equatable {
    public let isSpeaking: Bool
    public let confidence: Float
    public let timestamp: TimeInterval

    public init(isSpeaking: Bool, confidence: Float, timestamp: TimeInterval) {
        self.isSpeaking = isSpeaking
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
