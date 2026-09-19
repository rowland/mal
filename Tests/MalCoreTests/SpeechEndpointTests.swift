import Testing
import MalCore

@Test func endpointWaitsForThinkingAndIgnoresBriefPauses() {
    var detector = SpeechEndpoint()
    for _ in 0..<600 { let done = detector.observe(decibels: -65, duration: 0.1, hasTranscript: false); #expect(!done) }
    for _ in 0..<5 { let done = detector.observe(decibels: -20, duration: 0.1, hasTranscript: true); #expect(!done) }
    for _ in 0..<5 { let done = detector.observe(decibels: -65, duration: 0.1, hasTranscript: true); #expect(!done) }
    let resumed = detector.observe(decibels: -20, duration: 0.1, hasTranscript: true); #expect(!resumed)
    let done = detector.observe(decibels: -65, duration: 0.81, hasTranscript: true); #expect(done)
}
@Test func noiseWithoutRecognitionCannotSubmitAnAnswer() {
    var detector = SpeechEndpoint()
    _ = detector.observe(decibels: -10, duration: 0.5, hasTranscript: false)
    let done = detector.observe(decibels: -65, duration: 10, hasTranscript: false)
    #expect(!done)
    let invalid = detector.observe(decibels: .nan, duration: 1, hasTranscript: true)
    #expect(!invalid)
}
