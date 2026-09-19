import Foundation

/// Audio-time endpoint heuristic, not a linguistic speech classifier.
public struct SpeechEndpoint: Sendable {
    public private(set) var speaking = false
    private var voiced: Double = 0
    private var silence: Double = 0
    private var noiseFloor = -60.0
    public let silenceDuration: Double
    public init(silenceDuration: Double = 0.8) { self.silenceDuration = silenceDuration }
    public mutating func observe(decibels: Double, duration: Double, hasTranscript: Bool) -> Bool {
        guard decibels.isFinite, duration.isFinite, duration > 0 else { return false }
        let threshold = max(-45, min(-25, noiseFloor + 12))
        if decibels > threshold {
            voiced += duration; silence = 0
            if voiced >= 0.12 { speaking = true }
        } else {
            if !speaking { voiced = 0; noiseFloor += (decibels - noiseFloor) * min(1, duration * 2) }
            silence += duration
        }
        // Recognition evidence also handles soft speech below the energy threshold.
        if hasTranscript { speaking = true }
        return speaking && hasTranscript && silence >= silenceDuration
    }
}
