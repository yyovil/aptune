import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum MicrophonePermissionError: Error, CustomStringConvertible {
    case denied
    case unavailable

    public var description: String {
        switch self {
        case .denied:
            return "Microphone access is required. Enable it in System Settings > Privacy & Security > Microphone, then rerun aptune."
        case .unavailable:
            return "Microphone permission API unavailable on this platform. Aptune v1 supports macOS audio capture APIs."
        }
    }
}

public enum MicrophonePermissionChecker {
    public static func ensureMicrophoneAccess() throws {
        #if canImport(AVFoundation)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                granted = allowed
                semaphore.signal()
            }
            semaphore.wait()
            if !granted {
                throw MicrophonePermissionError.denied
            }
        case .denied, .restricted:
            throw MicrophonePermissionError.denied
        @unknown default:
            throw MicrophonePermissionError.denied
        }
        #else
        throw MicrophonePermissionError.unavailable
        #endif
    }
}
