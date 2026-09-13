import AVFoundation

/// Speaks a word aloud using the system's offline text-to-speech engine,
/// used as the "how to pronounce it" affordance in the popup.
enum SpeechHelper {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ word: String) {
        guard !word.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}
