import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import MalCore
import MalStorage

@MainActor @Observable final class StudyModel {
    var banks: [Bank] = []
    var states: [CardKey: LearningState] = [:]
    var settings = StudySettings()
    var current: Entry?
    var choices: [String] = []
    private var koreanDisplays: [String: String] = [:]
    var practiceStyle: KoreanPracticeStyle { settings.formStyle ?? .dictionary }
    var practiceEntries: [Entry] { selectedEntries.filter { !FormPractice.forms($0, style: practiceStyle).isEmpty } }
    var unavailableFormCount: Int { selectedEntries.filter { settings.parts.contains($0.partOfSpeech) && FormPractice.forms($0, style: practiceStyle).isEmpty }.count }
    func studyKey(_ entry: Entry) -> CardKey { FormPractice.key(entry, direction: settings.direction, mode: settings.mode, style: practiceStyle) }
    func koreanText(_ entry: Entry) -> String { koreanDisplays[entry.id] ?? FormPractice.forms(entry, style: practiceStyle).first ?? entry.lemma }
    func studyPrompt(_ entry: Entry) -> String { settings.direction == .koreanToEnglish ? koreanText(entry) : entry.prompt(settings.direction) }
    func correctAnswer(_ entry: Entry) -> String { settings.direction == .englishToKorean ? koreanText(entry) : entry.answer(settings.direction) }
    func alternateKoreanAnswers(_ entry: Entry) -> String? {
        guard settings.direction == .englishToKorean, practiceStyle != .dictionary else { return nil }
        let alternatives = FormPractice.accepted(entry, direction: .englishToKorean, style: practiceStyle, pool: allEntries, aliases: aliases).filter { $0 != koreanText(entry) }.sorted()
        return alternatives.isEmpty ? nil : alternatives.joined(separator: ", ")
    }
    var canRememberAnswer: Bool { current.map { FormPractice.canRememberAlias($0, direction: settings.direction, style: practiceStyle) } ?? false }
    var focusedForm: Bool { current.map { practiceStyle != .dictionary && FormPractice.applies($0, style: practiceStyle) } ?? false }
    private func prepareChoices(_ entry: Entry) {
        koreanDisplays = FormPractice.displayForms(practiceEntries, style: practiceStyle, using: &random)
        if koreanDisplays[entry.id] == nil { koreanDisplays[entry.id] = FormPractice.forms(entry, style: practiceStyle).first ?? entry.lemma }
        let accepted = FormPractice.accepted(entry, direction: settings.direction, style: practiceStyle, pool: allEntries, displayedKorean: koreanText(entry), aliases: aliases)
        choices = ChoiceBuilder.choices(target: entry, pool: practiceEntries, direction: settings.direction, count: settings.choiceCount, koreanAnswers: koreanDisplays, acceptedAnswers: accepted, sensePool: allEntries, aliases: aliases, using: &random)
    }
    let dictation = KoreanDictation()
    var speechConfirmation: [String]?
    private var hasSpokenDraft = false
    var editingSpokenAnswer = false
    private var speechGeneration = 0
    var spokenPractice: Bool { settings.spokenAnswers == true && settings.mode == .writeIn && settings.direction == .englishToKorean }

    var answer = ""
    var feedback = ""
    var reintroducing = false
    private var skipNextSense: String?
    var introducing = false
    var waiting = false
    var hintRevealed = false
    var error: String?
    var history: [HistoryItem] = []
    var trackSequences: [String: Int] = [:]
    var clockTrackID: String { CardKey("", settings.direction, settings.mode, formStyle: practiceStyle == .dictionary ? nil : practiceStyle).trackID }
    var sequence: Int { trackSequences[clockTrackID, default: 0] }
    func count(for key: CardKey, state: LearningState) -> Int { trackSequences[state.clockTrackID ?? key.trackID, default: 0] }
    var sinceIntroduction = 5
    var search = ""
    var showLibrary = false
    var showHistory = false
    private var lastSense: String?
    private var lastGraded: Entry?
    private var store: Store?
    private var aliases: [String: [String]] = [:]
    private let speech = AVSpeechSynthesizer()
    private var random = SystemRandomNumberGenerator()
    private var keyMonitor: Any?
    var selectedEntries: [Entry] { banks.filter { settings.bankIDs.contains($0.id) }.flatMap(\.entries) }
    var allEntries: [Entry] { banks.flatMap(\.entries) }
    var filteredLibrary: [Entry] {
        selectedEntries.filter { settings.parts.contains($0.partOfSpeech) && (search.isEmpty || $0.lemma.localizedCaseInsensitiveContains(search) || $0.english.joined(separator: " ").localizedCaseInsensitiveContains(search)) }
    }
    private var visibleKeys: Set<CardKey> { Set(practiceEntries.filter { settings.parts.contains($0.partOfSpeech) }.map(studyKey)) }
    var studyCounts: StudyCounts {
        StudyCounts.calculate(keys: visibleKeys, states: states, sequences: trackSequences, now: Date(), introduction: introducing ? current.map(studyKey) : nil)
    }
    var nextDue: Date? { let keys = visibleKeys; let now = Date(); return states.filter { keys.contains($0.key) && !Scheduler.isDue($0.value, now: now, sequence: count(for: $0.key, state: $0.value)) }.map(\.value.due).min() }
    init() {
        do {
            let override = ProcessInfo.processInfo.environment["MAL_DATA_DIRECTORY"]
            let directory = override.map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mal")
            let storage = try Store(url: directory.appendingPathComponent("Mal.sqlite")); store = storage
            let resources = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("Mal_MalApp.bundle")) } ?? Bundle.module
            guard let directoryURL = resources.url(forResource: "Banks", withExtension: nil) else { throw StoreError(message: "The bundled word banks are missing. Rebuild Mal.app.") }
            let order = ["novice", "technician", "general", "advanced", "extra"]
            for name in order {
                let path = directoryURL.appendingPathComponent(name + ".yaml")
                guard FileManager.default.fileExists(atPath: path.path) else { continue }
                let bank = try BankCodec.decode(String(contentsOf: path, encoding: .utf8), allowBuiltIn: true)
                let existing = try storage.banks().first { $0.id == bank.id }
                if existing == nil || existing!.contentVersion < bank.contentVersion { _ = try storage.importBank(bank, builtIn: true) }
            }
            settings = try storage.settings()
            if settings.singleColumnDefaultApplied != true {
                settings.choiceCount = 5
                settings.singleColumnDefaultApplied = true
                try storage.saveSettings(settings)
            }
            if settings.formStyle == nil { settings.formStyle = .polite; try storage.saveSettings(settings) }
            try reload()
            next()
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let ignore = MainActor.assumeIsolated {
                    guard let self, !self.showLibrary, !self.showHistory, event.window?.title == "Mal · 말" else { return false }
                    let modified = !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
                    switch InputRules.spokenAnswerKey(event.charactersIgnoringModifiers ?? "", enabled: self.spokenPractice && !self.introducing && !self.waiting, editing: self.editingSpokenAnswer, isRepeat: event.isARepeat, modified: modified) {
                    case .submit: self.submit(); return true
                    case .edit: self.editSpokenAnswer(); return true
                    case .ignore: return true
                    case .unhandled: break
                    }
                    return InputRules.ignoreRepeatedStudyKey(isRepeat: event.isARepeat, modified: modified, key: event.charactersIgnoringModifiers ?? "", multipleChoice: self.settings.mode == .multipleChoice, waitingForContinue: self.waiting || self.introducing)
                }
                return ignore ? nil : event
            }
        } catch { self.error = error.localizedDescription }
    }
    func reload(includeContent: Bool = true) throws {
        guard let store else { return }
        if includeContent { banks = try store.banks() }
        states = try store.states(); aliases = try store.aliases(direction: settings.direction)
        history = try store.history(); trackSequences = try store.answerSequences(); sinceIntroduction = try store.answersSinceIntroduction(trackID: clockTrackID)
    }
    func changeSettings() {
        pauseDictation()
        lastSense = current?.id ?? lastSense
        do { try store?.saveSettings(settings); aliases = try store?.aliases(direction: settings.direction) ?? [:] }
        catch { self.error = error.localizedDescription }
        waiting = false
        next()
    }
    func next() {
        pauseDictation()
        speechConfirmation = nil; hasSpokenDraft = false
        editingSpokenAnswer = false
        reintroducing = false
        let excluded = skipNextSense; skipNextSense = nil
        introducing = false; waiting = false; hintRevealed = false; answer = ""
        sinceIntroduction = (try? store?.answersSinceIntroduction(trackID: clockTrackID)) ?? 5
        let context = QueueContext(now: Date(), sequence: sequence, answersSinceIntroduction: sinceIntroduction, previousSense: lastSense, trackSequences: trackSequences)
        guard let selection = StudyQueue.select(entries: practiceEntries.filter { $0.id != excluded }, states: states, settings: settings, context: context, activeEntryIDs: Set(allEntries.map(\.id)), activeEntries: allEntries),
              let entry = selectedEntries.first(where: { $0.id == selection.entryID }) else { current = nil; return }
        current = entry
        introducing = selection.isNew
        prepareChoices(entry)
        pronounceAutomatically(entry)
        if selection.isNew { sinceIntroduction = 0 }
        beginSpokenAnswer()
        do { try store?.present(studyKey(entry), at: Date()) }
        catch { self.error = error.localizedDescription }
    }
    func continueIntroduction() {
        guard introducing else { return }
        if reintroducing { skipNextSense = current?.id; next(); return }
        introducing = false
        beginSpokenAnswer()
        // Keep this card and its choices. Reading the introduction is not a grade.
    }
    func dontKnow() {
        pauseDictation()
        guard !introducing, !waiting, let entry = current else { return }
        do {
            _ = try store?.didNotKnow(studyKey(entry), at: Date(), clockTrackID: clockTrackID)
            try reload(includeContent: false)
            lastSense = entry.id; lastGraded = entry
            answer = ""; introducing = true; reintroducing = true
            feedback = "I don’t know · \(koreanText(entry)) — \(entry.english.joined(separator: "; "))"
            pronounceAutomatically(entry)
        } catch { self.error = error.localizedDescription }
    }
    func pauseDictation() {
        speechGeneration += 1
        dictation.stop(clearStatus: true)
    }
    func setSpokenAnswers(_ enabled: Bool) {
        pauseDictation()
        speechConfirmation = nil; hasSpokenDraft = false
        settings.spokenAnswers = enabled; editingSpokenAnswer = false
        do { try store?.saveSettings(settings) } catch { self.error = error.localizedDescription }
        if enabled { beginSpokenAnswer() }
    }
    func editSpokenAnswer() {
        pauseDictation(); speechConfirmation = nil; hasSpokenDraft = false; editingSpokenAnswer = true
    }
    func toggleDictation() {
        if spokenPractice && !editingSpokenAnswer && dictation.active { editSpokenAnswer() }
        else { setSpokenAnswers(true) }
    }
    func beginSpokenAnswer() {
        guard spokenPractice, !editingSpokenAnswer, speechConfirmation == nil, !introducing, !waiting,
              current != nil, !showLibrary, !showHistory, !dictation.active else { return }
        speechGeneration += 1
        let generation = speechGeneration
        Task {
            // Let introduction/correction audio finish before reopening the microphone.
            while speech.isSpeaking {
                try? await Task.sleep(for: .milliseconds(100))
                guard generation == speechGeneration else { return }
            }
            guard generation == speechGeneration, spokenPractice, !editingSpokenAnswer,
                  !introducing, !waiting, !showLibrary, !showHistory else { return }
            await dictation.start(onText: { [weak self] text in
                guard let self, generation == self.speechGeneration else { return }
                self.answer = text; self.hasSpokenDraft = true
                guard let entry = self.current else { return }
                let accepted = FormPractice.accepted(entry, direction: self.settings.direction,
                    style: self.practiceStyle, pool: self.allEntries,
                    displayedKorean: self.koreanText(entry), aliases: self.aliases)
                // Exact matches or a unique live-enabled speech rule may submit.
                // Ambiguous rule matches wait for silence or explicit Return.
                if SpokenGrader.liveMatch(heard: text, alternatives: self.dictation.alternatives,
                    accepted: accepted) != nil { self.submit() }
            }, onUtteranceEnd: { [weak self] in
                guard let self, generation == self.speechGeneration else { return }
                self.submit()
            })
        }
    }
    func submit(_ text: String? = nil) {
        guard !introducing, speechConfirmation == nil else { return }
        if waiting { next(); return }
        guard let entry = current else { return }
        let value = text ?? answer
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pauseDictation()
        answer = value
        let accepted = FormPractice.accepted(entry, direction: settings.direction, style: practiceStyle, pool: allEntries, displayedKorean: koreanText(entry), aliases: aliases)
        var correct = accepted.contains(Grader.normalize(value, direction: settings.direction))
        var interpreted: String?
        if spokenPractice && !editingSpokenAnswer && hasSpokenDraft {
            switch SpokenGrader.decide(heard: value, alternatives: dictation.alternatives, accepted: accepted, preferredAnswer: koreanText(entry)) {
            case .correct(let matched): correct = true; interpreted = matched
            case .confirm(let candidate): speechConfirmation = SpokenGrader.confirmationOptions(accepted: accepted, preferred: candidate); return
            case .incorrect: break
            }
        }
        pronounceAutomatically(entry, submittedAnswer: value, correct: correct)
        record(entry, value, correct: correct)
        if let interpreted, interpreted != value { feedback = "Accepted as \(interpreted) · heard \(value)" }
    }
    func confirmSpokenAnswer(_ candidate: String) {
        guard let entry = current, speechConfirmation?.contains(candidate) == true else { return }
        let heard = answer; speechConfirmation = nil
        record(entry, heard, correct: true)
        feedback = "Confirmed \(candidate) · heard \(heard)"
    }
    func retrySpokenAnswer() {
        speechConfirmation = nil; answer = ""; hasSpokenDraft = false
        beginSpokenAnswer()
    }
    func rejectSpokenAnswer() {
        guard let entry = current, speechConfirmation != nil else { return }
        speechConfirmation = nil
        pronounceAutomatically(entry, submittedAnswer: answer, correct: false)
        record(entry, answer, correct: false)
    }
    private func record(_ entry: Entry, _ value: String, correct: Bool) {
        do {
            let key = studyKey(entry)
            _ = try store?.grade(key, answer: value, correct: correct, at: Date(), sequence: sequence + 1, clockTrackID: clockTrackID)
            try reload(includeContent: false)
            lastSense = entry.id; lastGraded = entry
            feedback = "\(correct ? "Correct" : "Incorrect") · \(koreanText(entry)) — \(entry.english.joined(separator: "; "))"
            if correct { next() } else { waiting = true }
        } catch { self.error = error.localizedDescription }
    }
    func acceptAnswer() {
        guard waiting, canRememberAnswer, let entry = current else { return }
        do {
            _ = try store?.correctLastAnswer(expectedKey: studyKey(entry), saveAlias: true)
            try reload(includeContent: false)
            feedback = "Accepted · \(koreanText(entry)) — \(entry.english.joined(separator: "; "))"
            next()
        } catch { self.error = error.localizedDescription }
    }
    func undo() {
        speechConfirmation = nil; hasSpokenDraft = false
        pauseDictation()
        do {
            guard let key = try store?.undo() else { return }
            try reload(includeContent: false); settings.direction = key.direction; settings.mode = key.mode
            aliases = try store?.aliases(direction: key.direction) ?? [:]
            try store?.saveSettings(settings)
            current = allEntries.first { $0.id == key.entryID } ?? lastGraded
            if let style = key.formStyle { settings.formStyle = style }
            else if let current, FormPractice.applies(current, style: practiceStyle) { settings.formStyle = .dictionary }
            try store?.saveSettings(settings)
            reintroducing = false; introducing = false; waiting = false; hintRevealed = false; answer = ""; feedback = "Previous grade undone."
            sinceIntroduction = max(0, sinceIntroduction - 1); lastSense = nil
            editingSpokenAnswer = true
            if let current { prepareChoices(current) }
        } catch { self.error = error.localizedDescription }
    }
    var nextCheckDescription: String? {
        guard let entry = lastGraded, let state = states[studyKey(entry)] else { return nil }
        let remaining = max(0, (state.dueSequence ?? 0) - count(for: studyKey(entry), state: state))
        return "Next check: \(state.due.formatted(date: .abbreviated, time: .shortened)) or \(remaining) more answers."
    }
    func checkAgain() { lastSense = nil; next() }
    func setAutomaticPronunciation(_ enabled: Bool) {
        settings.automaticPronunciation = enabled
        do { try store?.saveSettings(settings) } catch { self.error = error.localizedDescription }
        if !enabled { speech.stopSpeaking(at: .immediate) }
        else if let current, !waiting { pronounceAutomatically(current) }
    }
    private func pronounceAutomatically(_ entry: Entry, submittedAnswer: String? = nil, correct: Bool? = nil) {
        if introducing {
            if settings.automaticPronunciation == true { speakSequence([koreanText(entry)], automatic: true) }
            return
        }
        let sequence = PronunciationRules.automaticSequence(enabled: settings.automaticPronunciation == true, direction: settings.direction, lemma: koreanText(entry), submittedAnswer: submittedAnswer, correct: correct, spokenAnswer: spokenPractice)
        if !sequence.isEmpty { speakSequence(sequence, automatic: true) }
    }
    func speak(_ entry: Entry) { speakSequence([entry.id == current?.id ? koreanText(entry) : entry.lemma]) }
    private func speakSequence(_ texts: [String], automatic: Bool = false) {
        if dictation.active { return }
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("ko") }) else {
            let message = "Install a Korean voice in System Settings → Accessibility → Read & Speak → System voice. Study works without a voice."
            if automatic { feedback = message } else { error = message }
            return
        }
        speech.stopSpeaking(at: .immediate)
        for (index, text) in texts.enumerated() {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice; utterance.rate = 0.4
            utterance.postUtteranceDelay = index < texts.count - 1 ? 0.35 : 0
            speech.speak(utterance)
        }
    }
    func importBank() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.yaml, .plainText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let bank = try BankCodec.decode(String(contentsOf: url, encoding: .utf8))
            let summary = try store?.importBank(bank)
            settings.bankIDs.insert(bank.id); try store?.saveSettings(settings); try reload()
            feedback = "\(bank.title): \(summary?.description ?? "Imported")"; next()
        } catch { self.error = error.localizedDescription }
    }
    func backup() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Mal-backup.sqlite"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try store?.backup(to: url); feedback = "Backup saved." } catch { self.error = error.localizedDescription }
    }
    func restore() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert(); alert.messageText = "Restore this Mal backup?"
        alert.informativeText = "The current database will be backed up automatically before replacement."
        alert.addButton(withTitle: "Restore"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try store?.restore(from: url); settings = try store?.settings() ?? StudySettings(); try reload(); lastSense = nil; next(); feedback = "Backup restored." }
        catch { self.error = error.localizedDescription }
    }
}
