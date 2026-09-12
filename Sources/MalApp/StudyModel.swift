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
    var answer = ""
    var feedback = ""
    var waiting = false
    var error: String?
    var history: [HistoryItem] = []
    var sequence = 0
    var sinceIntroduction = 5
    var batchAnswered = 0
    var batchPaused = false
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
    var selectedEntries: [Entry] { banks.filter { settings.bankIDs.contains($0.id) }.flatMap(\.entries) }
    var allEntries: [Entry] { banks.flatMap(\.entries) }
    var filteredLibrary: [Entry] {
        selectedEntries.filter { settings.parts.contains($0.partOfSpeech) && (search.isEmpty || $0.lemma.localizedCaseInsensitiveContains(search) || $0.english.joined(separator: " ").localizedCaseInsensitiveContains(search)) }
    }
    var dueCount: Int {
        let ids = Set(selectedEntries.filter { settings.parts.contains($0.partOfSpeech) }.map(\.id))
        return states.filter { ids.contains($0.key.entryID) && $0.key.direction == settings.direction && $0.key.mode == settings.mode && $0.value.due <= Date() }.count
    }
    var nextDue: Date? {
        let ids = Set(selectedEntries.filter { settings.parts.contains($0.partOfSpeech) }.map(\.id))
        return states.filter { ids.contains($0.key.entryID) && $0.key.direction == settings.direction && $0.key.mode == settings.mode && $0.value.due > Date() }.map(\.value.due).min()
    }
    var learningCount: Int { states.filter { $0.key.direction == settings.direction && $0.key.mode == settings.mode && $0.value.phase != .review }.count }
    var recognizedCount: Int { states.filter { $0.key.direction == settings.direction && $0.key.mode == .multipleChoice && $0.value.graduated }.count }
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
            try reload()
            next()
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
        batchAnswered = 0; batchPaused = false; waiting = false
        next()
    }
    func next() {
        waiting = false; answer = ""; saveAlias = false
        if batchAnswered >= settings.reviewBatch { batchPaused = true; current = nil; return }
        let context = QueueContext(now: Date(), sequence: sequence, answersSinceIntroduction: sinceIntroduction, previousSense: lastSense)
        guard let selection = StudyQueue.select(entries: selectedEntries, states: states, settings: settings, context: context),
              let entry = selectedEntries.first(where: { $0.id == selection.entryID }) else { current = nil; return }
        current = entry
        if selection.isNew { sinceIntroduction = 0 }
        choices = ChoiceBuilder.choices(target: entry, pool: selectedEntries, direction: settings.direction, count: settings.choiceCount, aliases: aliases, using: &random)
        do { try store?.present(CardKey(entry.id, settings.direction, settings.mode), at: Date()) }
        catch { self.error = error.localizedDescription }
    }
    func submit(_ text: String? = nil) {
        if waiting { next(); return }
        guard let entry = current else { return }
        let value = text ?? answer
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        answer = value
        let correct = Grader.isCorrect(value, entry: entry, direction: settings.direction, aliases: aliases[entry.id] ?? [])
        record(entry, value, correct: correct)
    }
    private func record(_ entry: Entry, _ value: String, correct: Bool) {
        do {
            let key = CardKey(entry.id, settings.direction, settings.mode)
            _ = try store?.grade(key, answer: value, correct: correct, at: Date(), sequence: sequence + 1)
            try reload(includeContent: false); sinceIntroduction += 1; batchAnswered += 1
            lastSense = entry.id; lastGraded = entry
            feedback = "\(correct ? "Correct" : "Not quite") · \(entry.lemma) — \(entry.english.joined(separator: "; "))"
            if correct { next() } else { waiting = true }
        } catch { self.error = error.localizedDescription }
    }
    func acceptAnswer() {
        guard waiting, let entry = current else { return }
        do {
            _ = try store?.correctLastAnswer(expectedKey: CardKey(entry.id, settings.direction, settings.mode), saveAlias: saveAlias)
            try reload(includeContent: false)
            feedback = "Accepted · \(entry.lemma) — \(entry.english.joined(separator: "; "))"
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
            waiting = false; batchPaused = false; answer = ""; feedback = "Previous grade undone."
            batchAnswered = max(0, batchAnswered - 1); sinceIntroduction = max(0, sinceIntroduction - 1); lastSense = nil
            if let current { choices = ChoiceBuilder.choices(target: current, pool: selectedEntries, direction: settings.direction, count: settings.choiceCount, aliases: aliases, using: &random) }
        } catch { self.error = error.localizedDescription }
    }
    func continueBatch() { batchAnswered = 0; batchPaused = false; next() }
    func checkAgain() { lastSense = nil; next() }
    func speak(_ entry: Entry) {
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("ko") }) else {
            error = "Install a Korean voice in System Settings → Accessibility → Read & Speak → System voice. Study works without a voice."; return
        }
        speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: entry.lemma); utterance.voice = voice; utterance.rate = 0.4
        speech.speak(utterance)
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
        do { try store?.restore(from: url); settings = try store?.settings() ?? StudySettings(); try reload(); lastSense = nil; batchAnswered = 0; next(); feedback = "Backup restored." }
        catch { self.error = error.localizedDescription }
    }
}
