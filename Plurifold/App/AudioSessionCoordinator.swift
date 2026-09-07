import AVFoundation
import Foundation

/// Serializes ownership of the one audio session shared by all native players.
/// A previous player's delayed completion must never deactivate its successor.
@MainActor
final class AudioSessionCoordinator {
    static let shared = AudioSessionCoordinator()

    private var owner: UUID?
    private var stopOwner: (@MainActor () -> Void)?

    private init() {}

    func acquire(
        owner newOwner: UUID,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions = [],
        onOwnershipLost: @escaping @MainActor () -> Void
    ) throws {
        guard owner != newOwner else { return }
        let stopPrevious = stopOwner
        // Transfer first: the old owner's stop/release is now harmless.
        owner = newOwner
        stopOwner = onOwnershipLost
        stopPrevious?()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: mode, options: options)
            try session.setActive(true)
        } catch {
            // A VideoPlayer may already have started before its KVO callback
            // acquires the session. Stop it before attempting deactivation.
            stopOwner?()
            release(owner: newOwner)
            throw error
        }
    }

    func release(owner oldOwner: UUID) {
        guard owner == oldOwner else { return }
        owner = nil
        stopOwner = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
