import Foundation

/// Audio-time endpoint heuristic, not a linguistic speech classifier.
public struct SpeechEndpoint: Sendable {
    public private(set) var speaking = false
    private var voiced: Double = 0
    private var silence: Double = 0
    private var receivedTranscript = false
    private var noiseFloor = -60.0
    private var speechLevel = -100.0
    private var candidateLevel = -100.0
    public let silenceDuration: Double
    public init(silenceDuration: Double = 0.8) { self.silenceDuration = silenceDuration }
    public mutating func observe(decibels: Double, duration: Double, hasTranscript: Bool) -> Bool {
        guard decibels.isFinite, duration.isFinite, duration > 0 else { return false }
        if hasTranscript && !receivedTranscript { silence = 0; receivedTranscript = true }
        // After sustained activity, ignore sound substantially quieter than the
        // user's voice. A fixed low floor alone treats room noise as more speech.
        let threshold = max(-45, min(-25, max(noiseFloor + 12, speechLevel - 12)))
        if decibels > threshold {
            voiced += duration
            candidateLevel = max(candidateLevel, decibels)
            if voiced >= 0.12 {
                speaking = true; silence = 0
                speechLevel = max(speechLevel, candidateLevel)
            }
            // A short click/breath pauses, but does not erase, accrued silence.
        } else {
            voiced = 0; candidateLevel = -100
            if !speaking { noiseFloor += (decibels - noiseFloor) * min(1, duration * 2) }
            silence += duration
        }
        // Recognition evidence also handles soft speech below the energy threshold.
        if hasTranscript { speaking = true }
        return speaking && hasTranscript && silence >= silenceDuration
    }
}
