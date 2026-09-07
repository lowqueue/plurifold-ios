import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published var notice: String?
    private let synthesizer = AVSpeechSynthesizer()
    private let audioOwnerID = UUID()
    private var currentUtterance: AVSpeechUtterance?
    private var audioObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        synthesizer.delegate = self
        let center = NotificationCenter.default
        audioObservers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor [weak self] in self?.stop() }
        })
        audioObservers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in self?.stop() }
        })
    }

    deinit {
        for observer in audioObservers { NotificationCenter.default.removeObserver(observer) }
        synthesizer.stopSpeaking(at: .immediate)
        let owner = audioOwnerID
        Task { @MainActor in AudioSessionCoordinator.shared.release(owner: owner) }
    }

    func speak(_ text: String, language: String) {
        stop()
        notice = nil
        guard let voice = AVSpeechSynthesisVoice(language: language) else {
            notice = "A voice for this language is not available on this device. Check the voice downloads in your device's accessibility settings."
            return
        }
        do {
            try AudioSessionCoordinator.shared.acquire(
                owner: audioOwnerID, mode: .spokenAudio, options: .duckOthers
            ) { [weak self] in self?.stop() }
        } catch {
            notice = "Audio could not start. Please try again."
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        currentUtterance = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        AudioSessionCoordinator.shared.release(owner: audioOwnerID)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.stop()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.stop()
        }
    }
}
