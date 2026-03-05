import Foundation

public protocol VADEngine {
    func start(onSpeechStateChange: @escaping (SpeechState) -> Void) throws
    func stop()
}

public enum VADEngineError: Error, CustomStringConvertible {
    case unsupported(String)
    case startFailed(String)

    public var description: String {
        switch self {
        case .unsupported(let message), .startFailed(let message):
            return message
        }
    }
}
