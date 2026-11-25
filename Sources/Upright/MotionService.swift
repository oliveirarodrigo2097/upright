import CoreMotion
import Foundation
import UprightCore

enum ConnectionState: Equatable {
    case unavailable      // no supported headphones / API unavailable
    case notAuthorized    // user denied Motion & Fitness access
    case waiting          // started, AirPods not connected yet
    case connected
}

/// Wraps CMHeadphoneMotionManager and delivers samples on the main actor.
@MainActor
final class MotionService: NSObject, CMHeadphoneMotionManagerDelegate {
    private let manager = CMHeadphoneMotionManager()
    private(set) var state: ConnectionState = .waiting

    var onSample: ((MotionSample) -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?

    func start() {
        manager.delegate = self
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            setState(.notAuthorized)
            return
        default:
            break
        }
        guard manager.isDeviceMotionAvailable else {
            setState(.unavailable)
            return
        }
        setState(.waiting)
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            // Runs on the main queue.
            if let error {
                let code = (error as NSError).code
                MainActor.assumeIsolated {
                    if CMHeadphoneMotionManager.authorizationStatus() == .denied {
                        self?.setState(.notAuthorized)
                    }
                    NSLog("Upright: motion error \(code): \(error.localizedDescription)")
                }
                return
            }
            guard let motion else { return }
            let a = motion.userAcceleration
            let sample = MotionSample(
                time: Date().timeIntervalSinceReferenceDate,
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw,
                acceleration: (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot())
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.state != .connected { self.setState(.connected) }
                self.onSample?(sample)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func setState(_ s: ConnectionState) {
        guard s != state else { return }
        state = s
        onStateChange?(s)
    }

    nonisolated func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in self.setState(.connected) }
    }

    nonisolated func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor in self.setState(.waiting) }
    }
}
