import Foundation
import Observation
import Speech
@preconcurrency import AVFoundation
import MalCore
import MalNative

@MainActor @Observable final class KoreanDictation {
    private(set) var active = false
    private(set) var listening = false
    private(set) var needsDownload = false
    private(set) var status = ""
    private var draft = DictationDraft()
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var results: Task<Void, Never>?
    private var timeout: Task<Void, Never>?

    func stop(clearStatus: Bool = false) {
        if !clearStatus, listening, let analyzer {
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
                cancel()
                status = "Listening paused. Return submits · Escape edits · ⌘⇧R resumes."
            }
            return
        }
        cancel()
        status = clearStatus ? "" : "Listening paused. Return submits · Escape edits · ⌘⇧R resumes."
    }
    private func cancel() {
        draft.end()
        timeout?.cancel(); timeout = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0); engine = nil
        input?.finish(); input = nil
        results?.cancel(); results = nil
        if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
        analyzer = nil; active = false; listening = false
    }
    private func module() async -> SpeechTranscriber? {
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "ko-KR")) else { return nil }
        return SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
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
                    let fragment = String(result.text.characters)
                    let text = (committed + fragment).trimmingCharacters(in: .whitespacesAndNewlines)
                    if result.isFinal { committed += fragment }
                    if self.draft.receive(text, id: id), let cleaned = self.draft.text {
                        onText(cleaned)
                        if result.isFinal {
                            self.cancel()
                            onUtteranceEnd()
                            return
                        }
                    }
                }
            } catch { if let self, self.draft.sessionID == id { self.fail("Recognition stopped: \(error.localizedDescription). Review the draft or try again.") } }
        }
        do {
            try await analyzer.start(inputSequence: stream)
            guard draft.sessionID == id else { return }
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: source,
                block: Self.audioTap(converter: converter, continuation: continuation) { [weak self] in
                    Task { @MainActor [weak self] in
                        if let self, self.draft.sessionID == id { self.fail("The microphone audio could not be converted. Try another input device.") }
                    }
                })
            self.engine = engine
            engine.prepare(); try engine.start()
            listening = true; status = "Listening… Return submits now · Escape edits."
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard let self, self.draft.sessionID == id else { return }; self.stop()
            }
        } catch { if draft.sessionID == id { fail("Could not start recognition: \(error.localizedDescription)") } }
    }
    private func fail(_ message: String) { cancel(); status = message }
    nonisolated private static func audioTap(converter: DictationAudioConverter,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        onError: @escaping @Sendable () -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            do {
                if let output = try converter.convert(buffer) { continuation.yield(AnalyzerInput(buffer: output)) }
            } catch { onError() }
        }
    }
}
