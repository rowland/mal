import Foundation
import Observation
import OSLog
import Speech
@preconcurrency import AVFoundation
import MalCore
import MalNative

@MainActor @Observable final class KoreanDictation {
    private(set) var alternatives: [String] = []
    // In-memory diagnostic only; reset per attempt, bounded, never written to logs.
    private(set) var recognitionDetails: [String] = []
    private var resultNumber = 0
    private(set) var active = false
    private(set) var listening = false
    private(set) var needsDownload = false
    private(set) var status = ""
    private let timingLog = Logger(subsystem: "app.mal", category: "SpeechTiming")
    private var timingStart = ProcessInfo.processInfo.systemUptime
    private var reportedFirstResult = false
    private func trace(_ event: String) {
        let elapsed = ProcessInfo.processInfo.systemUptime - timingStart
        timingLog.notice("\(event, privacy: .public) +\(elapsed, format: .fixed(precision: 3))s")
    }
    private var draft = DictationDraft()
    private var endpoint = SpeechEndpoint()
    private var completed: (@MainActor () -> Void)?
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var results: Task<Void, Never>?
    private var timeout: Task<Void, Never>?

    func stop(clearStatus: Bool = false) {
        if !clearStatus, listening, let analyzer {
            trace("quiet endpoint; finalizing")
            listening = false
            engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
            input?.finish(); input = nil
            timeout?.cancel(); timeout = nil
            status = "Finishing transcription…"
            let id = draft.sessionID
            let resultTask = results
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                if let self, self.draft.sessionID == id { self.fail("Transcription timed out. Review the draft or try again.") }
            }
            Task {
                do { try await analyzer.finalizeAndFinishThroughEndOfInput() }
                catch { if draft.sessionID == id { fail("Transcription stopped. Review the draft or try again.") }; return }
                await resultTask?.value
                guard draft.sessionID == id else { return }
                trace("finalization complete")
                let finish = completed
                let hasAnswer = draft.text != nil
                cancel()
                if hasAnswer { finish?() }
                else { status = "No answer recognized. ⌘⇧R retries · Escape edits." }
            }
            return
        }
        cancel()
        status = clearStatus ? "" : "Listening paused. Return submits · Escape edits · ⌘⇧R resumes."
    }
    private func cancel() {
        if active { trace("session closed") }
        draft.end()
        timeout?.cancel(); timeout = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
        input?.finish(); input = nil
        results?.cancel(); results = nil
        if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
        analyzer = nil; completed = nil; active = false; listening = false
    }
    private func module() async -> SpeechTranscriber? {
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "ko-KR")) else { return nil }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .alternativeTranscriptions, .fastResults], attributeOptions: [])
    }
    func installModel() async {
        guard !active else { return }
        let id = UUID(); draft.begin(id: id); active = true
        status = "Downloading Korean speech model from Apple… Stop returns to typing; macOS may finish the download in the background."
        do {
            guard let module = await module() else { fail("On-device Korean recognition is unsupported on this Mac."); return }
            guard draft.sessionID == id else { return }
            try await AssetInventory.reserve(locale: Locale(identifier: "ko-KR"))
            if let download = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                guard draft.sessionID == id else { return }
                try await download.downloadAndInstall()
            }
            guard draft.sessionID == id else { return }
            needsDownload = false; cancel()
            status = "Korean speech model ready. Click Speak Korean to begin."
        } catch { if draft.sessionID == id { fail("Could not install Korean speech: \(error.localizedDescription)") } }
    }
    func start(onText: @escaping @MainActor (String) -> Void, onUtteranceEnd: @escaping @MainActor () -> Void) async {
        guard !active else { return }
        let id = UUID(); draft.begin(id: id); active = true
        timingStart = ProcessInfo.processInfo.systemUptime; reportedFirstResult = false
        trace("preparing")
        alternatives = []; recognitionDetails = []; resultNumber = 0
        endpoint = SpeechEndpoint(); completed = onUtteranceEnd
        status = "Checking Korean speech recognition…"
        guard let transcriber = await module() else {
            if draft.sessionID == id { fail("On-device Korean recognition is unsupported on this Mac. Typing still works.") }; return
        }
        let installed = await AssetInventory.status(forModules: [transcriber]) == .installed
        guard draft.sessionID == id else { return }
        guard installed else {
            needsDownload = true
            fail("Download Apple’s Korean speech model once to use offline dictation. Audio stays on your Mac."); return
        }
        needsDownload = false
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard draft.sessionID == id else { return }
        guard microphone else {
            fail("Microphone access is off. Enable Mal in System Settings → Privacy & Security → Microphone, or type your answer."); return
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            if draft.sessionID == id { fail("No supported audio format is available.") }; return
        }
        guard draft.sessionID == id else { return }
        let engine = AVAudioEngine()
        let source = engine.inputNode.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let converter = DictationAudioConverter(from: source, to: format) else { fail("No working microphone was found. Check your sound input settings."); return }
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer; input = continuation
        results = Task { [weak self] in
            var committed = ""
            do {
                for try await result in transcriber.results {
                    guard let self, self.draft.sessionID == id else { return }
                    if !self.reportedFirstResult {
                        self.reportedFirstResult = true; self.trace("first recognition result")
                    }
                    let fragment = String(result.text.characters)
                    self.resultNumber += 1
                    let elapsed = ProcessInfo.processInfo.systemUptime - self.timingStart
                    let phase = result.isFinal ? "Final" : "Partial"
                    let rawAlternatives = result.alternatives.map { String($0.characters) }
                    let ranked = rawAlternatives.enumerated().map { index, value in
                        "  \(index + 1). \(value.debugDescription)"
                    }.joined(separator: "\n")
                    self.recognitionDetails.append(
                        "#\(self.resultNumber) \(phase) +\(String(format: "%.2f", elapsed))s\n" +
                        "Primary: \(fragment.debugDescription)\n" +
                        "Earlier finalized text: \(committed.debugDescription)\n" +
                        "Apple alternatives (\(rawAlternatives.count)):\n" +
                        (ranked.isEmpty ? "  None returned" : ranked))
                    if self.recognitionDetails.count > 100 { self.recognitionDetails.removeFirst() }
                    let text = (committed + fragment).trimmingCharacters(in: .whitespacesAndNewlines)
                    self.alternatives = result.alternatives.compactMap { alternative in
                        var candidate = DictationDraft(); let candidateID = UUID(); candidate.begin(id: candidateID)
                        return candidate.receive(committed + String(alternative.characters), id: candidateID) ? candidate.text : nil
                    }
                    if result.isFinal { committed += fragment }
                    if self.draft.receive(text, id: id), let cleaned = self.draft.text {
                        onText(cleaned)
                        // A live vocabulary match may synchronously cancel this session.
                        guard self.draft.sessionID == id else { return }
                        // Unmatched final segments wait for the audio endpoint.
                    }
                }
            } catch { if let self, self.draft.sessionID == id { self.fail("Recognition stopped: \(error.localizedDescription). Review the draft or try again.") } }
        }
        do {
            status = "Preparing Korean recognition…"
            try await analyzer.prepareToAnalyze(in: format)
            guard draft.sessionID == id else { return }
            try await analyzer.start(inputSequence: stream)
            guard draft.sessionID == id else { return }
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: source,
                block: Self.audioTap(converter: converter, continuation: continuation, onLevel: { [weak self] level, duration in
                    Task { @MainActor [weak self] in
                        guard let self, self.draft.sessionID == id, self.listening else { return }
                        let wasSpeaking = self.endpoint.speaking
                        let finished = self.endpoint.observe(decibels: level, duration: duration, hasTranscript: self.draft.text != nil)
                        if !wasSpeaking && self.endpoint.speaking { self.trace("first voice activity") }
                        self.status = self.endpoint.speaking ? "Hearing your answer… Return submits · Escape edits." : "Ready when you are… Return submits · Escape edits."
                        if finished { self.stop() }
                    }
                }) { [weak self] in
                    Task { @MainActor [weak self] in
                        if let self, self.draft.sessionID == id { self.fail("The microphone audio could not be converted. Try another input device.") }
                    }
                })
            self.engine = engine
            engine.prepare(); try engine.start()
            listening = true; trace("microphone ready")
            status = "Ready when you are… Return submits · Escape edits."

        } catch { if draft.sessionID == id { fail("Could not start recognition: \(error.localizedDescription)") } }
    }
    private func fail(_ message: String) { cancel(); status = message }
    nonisolated private static func audioTap(converter: DictationAudioConverter,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        onLevel: @escaping @Sendable (Double, Double) -> Void,
        onError: @escaping @Sendable () -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            do {
                if let output = try converter.convert(buffer) {
                    continuation.yield(AnalyzerInput(buffer: output))
                    onLevel(AudioLevel.decibels(buffer), Double(buffer.frameLength) / buffer.format.sampleRate)
                }
            } catch { onError() }
        }
    }
}
