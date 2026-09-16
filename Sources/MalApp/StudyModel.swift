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
    var focusedForm: Bool { current.map { practiceStyle != .dictionary && FormPractice.applies($0, style: practiceStyle) } ?? false }
    private func prepareChoices(_ entry: Entry) {
        koreanDisplays = FormPractice.displayForms(practiceEntries, style: practiceStyle, using: &random)
        if koreanDisplays[entry.id] == nil { koreanDisplays[entry.id] = FormPractice.forms(entry, style: practiceStyle).first ?? entry.lemma }
        let accepted = settings.direction == .koreanToEnglish ? FormPractice.accepted(entry, direction: settings.direction, style: practiceStyle, pool: allEntries, displayedKorean: koreanText(entry), aliases: aliases) : nil
        choices = ChoiceBuilder.choices(target: entry, pool: practiceEntries, direction: settings.direction, count: settings.choiceCount, koreanAnswers: koreanDisplays, acceptedAnswers: accepted, sensePool: allEntries, aliases: aliases, using: &random)
    }
    var answer = ""
    var feedback = ""
    var introducing = false
    var waiting = false
    var hintRevealed = false
    var error: String?
    var history: [HistoryItem] = []
    var sequence = 0
    var sinceIntroduction = 5
    var search = ""
    var showLibrary = false
    var showHistory = false
    var saveAlias = false
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
    var dueCount: Int { let keys = visibleKeys; let now = Date(); return states.filter { keys.contains($0.key) && $0.value.due <= now }.count }
    var nextDue: Date? { let keys = visibleKeys; let now = Date(); return states.filter { keys.contains($0.key) && $0.value.due > now }.map(\.value.due).min() }
    var learningCount: Int { let keys = visibleKeys; return states.filter { keys.contains($0.key) && $0.value.phase != .review }.count }
    var recognizedCount: Int {
        let keys = Set(practiceEntries.filter { settings.parts.contains($0.partOfSpeech) }.map { FormPractice.key($0, direction: settings.direction, mode: .multipleChoice, style: practiceStyle) })
        return states.filter { keys.contains($0.key) && $0.value.graduated }.count
    }
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
        history = try store.history(); sequence = try store.answerSequence()
    }
    func changeSettings() {
        lastSense = current?.id ?? lastSense
        do { try store?.saveSettings(settings); aliases = try store?.aliases(direction: settings.direction) ?? [:] }
        catch { self.error = error.localizedDescription }
        waiting = false
        next()
    }
    func next() {
        introducing = false; waiting = false; hintRevealed = false; answer = ""; saveAlias = false
        let context = QueueContext(now: Date(), sequence: sequence, answersSinceIntroduction: sinceIntroduction, previousSense: lastSense)
        guard let selection = StudyQueue.select(entries: practiceEntries, states: states, settings: settings, context: context, activeEntryIDs: Set(allEntries.map(\.id)), activeEntries: allEntries),
              let entry = selectedEntries.first(where: { $0.id == selection.entryID }) else { current = nil; return }
        current = entry
        introducing = selection.isNew
        prepareChoices(entry)
        pronounceAutomatically(entry)
        if selection.isNew { sinceIntroduction = 0 }
        do { try store?.present(studyKey(entry), at: Date()) }
        catch { self.error = error.localizedDescription }
    }
    func continueIntroduction() {
        guard introducing else { return }
        introducing = false
        // Keep this card and its choices. Reading the introduction is not a grade.
    }
    func submit(_ text: String? = nil) {
        guard !introducing else { return }
        if waiting { next(); return }
        guard let entry = current else { return }
        let value = text ?? answer
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        answer = value
        let correct = FormPractice.accepted(entry, direction: settings.direction, style: practiceStyle, pool: allEntries, displayedKorean: koreanText(entry), aliases: aliases).contains(Grader.normalize(value, direction: settings.direction))
        pronounceAutomatically(entry, submittedAnswer: value, correct: correct)
        record(entry, value, correct: correct)
    }
    private func record(_ entry: Entry, _ value: String, correct: Bool) {
        do {
            let key = studyKey(entry)
            _ = try store?.grade(key, answer: value, correct: correct, at: Date(), sequence: sequence + 1)
            try reload(includeContent: false); sinceIntroduction += 1
            lastSense = entry.id; lastGraded = entry
            feedback = "\(correct ? "Correct" : "Incorrect") · \(koreanText(entry)) — \(entry.english.joined(separator: "; "))"
            if correct { next() } else { waiting = true }
        } catch { self.error = error.localizedDescription }
    }
    func acceptAnswer() {
        guard waiting, let entry = current else { return }
        do {
            _ = try store?.correctLastAnswer(expectedKey: studyKey(entry), saveAlias: saveAlias)
            try reload(includeContent: false)
            feedback = "Accepted · \(koreanText(entry)) — \(entry.english.joined(separator: "; "))"
            next()
        } catch { self.error = error.localizedDescription }
    }
    func undo() {
        do {
            guard let key = try store?.undo() else { return }
            try reload(includeContent: false); settings.direction = key.direction; settings.mode = key.mode
            aliases = try store?.aliases(direction: key.direction) ?? [:]
            try store?.saveSettings(settings)
            current = allEntries.first { $0.id == key.entryID } ?? lastGraded
            if let style = key.formStyle { settings.formStyle = style }
            else if let current, FormPractice.applies(current, style: practiceStyle) { settings.formStyle = .dictionary }
            try store?.saveSettings(settings)
            introducing = false; waiting = false; hintRevealed = false; answer = ""; feedback = "Previous grade undone."
            sinceIntroduction = max(0, sinceIntroduction - 1); lastSense = nil
            if let current { prepareChoices(current) }
        } catch { self.error = error.localizedDescription }
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
        let sequence = PronunciationRules.automaticSequence(enabled: settings.automaticPronunciation == true, direction: settings.direction, lemma: koreanText(entry), submittedAnswer: submittedAnswer, correct: correct)
        if !sequence.isEmpty { speakSequence(sequence, automatic: true) }
    }
    func speak(_ entry: Entry) { speakSequence([entry.id == current?.id ? koreanText(entry) : entry.lemma]) }
    private func speakSequence(_ texts: [String], automatic: Bool = false) {
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
