import Foundation

public final class SileroEngine: VADEngine {
    public init() {}

    public func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws {
        _ = onSpeechStateChange
        throw VADEngineError.unsupported("Silero engine is not implemented yet. Use --engine native for Aptune v1.")
    }

    public func stop() {}
}
