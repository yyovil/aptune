import Foundation

public protocol SystemVolumeControlling {
    func getCurrentVolume() throws -> Double
    func setVolume(_ fraction: Double) throws
}

public enum VolumeControllerError: Error, CustomStringConvertible {
    case commandFailed(String)
    case invalidResponse(String)

    public var description: String {
        switch self {
        case .commandFailed(let message), .invalidResponse(let message):
            return message
        }
    }
}
