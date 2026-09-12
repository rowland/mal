import Foundation
import Testing
import MalCore
@testable import MalStorage

private func fixture(version: Int = 1) -> Bank {
    Bank(id: "custom.test", title: "Test", entries: [Entry(id: "custom.test.house", lemma: "집", partOfSpeech: .noun, english: ["house", "home"], verification: "checked")], contentVersion: version)
}
@MainActor private func temporaryStore() throws -> Store {
    try Store(url: FileManager.default.temporaryDirectory.appendingPathComponent("mal-test-\(UUID().uuidString)/test.sqlite"))
}
@Test @MainActor func importsAreAtomicAndIdempotent() throws {
    let store = try temporaryStore(); defer { store.close() }
    #expect(try store.importBank(fixture()).added == 1)
    #expect(try store.importBank(fixture()).unchanged)
    var invalid = fixture(version: 2); invalid.entries.append(invalid.entries[0])
    #expect(throws: ValidationFailure.self) { try store.importBank(invalid) }
    #expect(try store.banks() == [fixture()])
    var change = fixture(); change.entries[0].lemma = "주택"
    #expect(throws: StoreError.self) { try store.importBank(change) }
}
@Test @MainActor func updateRetirementAndReactivationPreserveProgress() throws {
    let store = try temporaryStore(); defer { store.close() }
    _ = try store.importBank(fixture())
    let key = CardKey("custom.test.house", .englishToKorean, .writeIn)
    let state = try store.grade(key, answer: "집", correct: true, at: Date(), sequence: 1)
    var update = fixture(version: 2); update.entries[0].english.append("dwelling")
    #expect(try store.importBank(update).changed == 1)
    var retirement = fixture(version: 3); retirement.entries[0].id = "custom.test.book"; retirement.entries[0].lemma = "책"; retirement.entries[0].english = ["book"]
    let summary = try store.importBank(retirement)
    #expect(summary.added == 1 && summary.retired == 1)
    #expect(try store.states()[key] == state)
    var reactivated = fixture(version: 4); reactivated.entries[0].notes = "Returned"
    #expect(try store.importBank(reactivated).changed == 1)
    #expect(try store.states()[key] == state)
}
@Test @MainActor func gradingIsolationUndoAndRestart() throws {
    let store = try temporaryStore()
    let key = CardKey("custom.test.house", .englishToKorean, .multipleChoice)
    try store.present(key, at: Date())
    #expect(try store.states().isEmpty)
    let initial = try store.grade(key, answer: "집", correct: true, at: Date(), sequence: 1)
    #expect(try store.states().count == 1)
    #expect(try store.states()[CardKey(key.entryID, .englishToKorean, .writeIn)] == nil)
    #expect(try store.states()[CardKey(key.entryID, .koreanToEnglish, .multipleChoice)] == nil)
    _ = try store.grade(key, answer: "틀림", correct: false, at: Date(), sequence: 2)
    #expect(try store.undo() == key)
    #expect(try store.states()[key] == initial)
    let url = store.url; store.close()
    let reopened = try Store(url: url); defer { reopened.close() }
    #expect(try reopened.states()[key] == initial)
    #expect(try reopened.history().count == 2)
    #expect(try reopened.history().first?.undone == true)
    _ = try reopened.undo()
    #expect(try reopened.states().isEmpty)
    #expect(try reopened.answerSequence() == 0)
}
@Test @MainActor func backupRestoreAliasesAndPreferences() throws {
    let store = try temporaryStore(); defer { store.close() }
    _ = try store.importBank(fixture())
    let key = CardKey("custom.test.house", .koreanToEnglish, .writeIn)
    let state = try store.grade(key, answer: "home", correct: true, at: Date(), sequence: 1)
    try store.addAlias(entryID: key.entryID, direction: key.direction, answer: "dwelling")
    var settings = StudySettings(); settings.mode = .writeIn; settings.parts = [.noun]; settings.choiceCount = 10
    try store.saveSettings(settings)
    let backup = store.url.deletingLastPathComponent().appendingPathComponent("backup.sqlite")
    try store.backup(to: backup)
    _ = try store.grade(key, answer: "no", correct: false, at: Date(), sequence: 2)
    try store.restore(from: backup)
    #expect(try store.states()[key] == state)
    #expect(try store.settings() == settings)
    #expect(try store.aliases(direction: key.direction)[key.entryID] == ["dwelling"])
    #expect(try store.history().count == 1)
    #expect(throws: StoreError.self) { try store.backup(to: store.url) }
    let invalid = store.url.deletingLastPathComponent().appendingPathComponent("bad.sqlite")
    try Data("not SQLite".utf8).write(to: invalid)
    #expect(throws: (any Error).self) { try store.restore(from: invalid) }
    #expect(try store.states()[key] == state)
}
@Test func validationAndYAML() throws {
    let yaml = """
    schemaVersion: 1
    id: custom.colors
    contentVersion: 1
    title: Colors
    provenance:
      source: Original
      license: Personal use
    entries:
      - id: custom.colors.red
        lemma: 빨갛다
        partOfSpeech: adjective
        english: [red]
        koreanForms:
          - text: 빨간
            attributive: true
          - text: 빨개요
            speechLevel: informal-polite
        verification: checked
    """
    let bank = try BankCodec.decode(yaml)
    #expect(bank.entries[0].koreanForms[0].attributive == true)
    #expect(throws: (any Error).self) { try BankCodec.decode("entries: [broken") }
    #expect(throws: ValidationFailure.self) { try BankCodec.decode(yaml.replacingOccurrences(of: "schemaVersion: 1", with: "schemaVersion: 99")) }
    #expect(throws: ValidationFailure.self) { try BankCodec.decode(yaml.replacingOccurrences(of: "custom.colors", with: "mal.colors")) }
    #expect(throws: ValidationFailure.self) { try BankCodec.decode(yaml.replacingOccurrences(of: "english: [red]", with: "english: []")) }
}
@Test @MainActor func overrideIsAtomicAndUndoable() throws {
    let store = try temporaryStore(); defer { store.close() }
    let key = CardKey("custom.test.house", .koreanToEnglish, .writeIn)
    _ = try store.grade(key, answer: "dwelling", correct: false, at: Date(), sequence: 1)
    _ = try store.correctLastAnswer(expectedKey: key, saveAlias: true)
    #expect(try store.states()[key]?.totalCorrect == 1)
    #expect(try store.states()[key]?.totalWrong == 0)
    #expect(try store.aliases(direction: key.direction)[key.entryID] == ["dwelling"])
    #expect(try store.history().filter { !$0.undone }.count == 1)
    #expect(throws: StoreError.self) { try store.correctLastAnswer(expectedKey: key, saveAlias: true) }
    _ = try store.undo()
    #expect(try store.states().isEmpty)
}
@Test func bundledBanksHaveExpectedStructure() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    var ids = Set<String>(), lemmas = Set<String>()
    for name in ["novice", "technician", "general", "advanced", "extra"] {
        let url = root.appendingPathComponent("Sources/MalApp/Resources/Banks/\(name).yaml")
        let bank = try BankCodec.decode(String(contentsOf: url, encoding: .utf8), allowBuiltIn: true)
        #expect(bank.entries.count == 500)
        for entry in bank.entries {
            #expect(ids.insert(entry.id).inserted)
            #expect(lemmas.insert(entry.lemma).inserted)
            #expect(entry.notes?.contains("Source:") == true)
        }
    }
    #expect(ids.count == 2500)
}

@Test @MainActor func allFourTracksPersistIndependently() throws {
    let store = try temporaryStore(); defer { store.close() }
    for direction in Direction.allCases {
        for mode in AnswerMode.allCases {
            _ = try store.grade(CardKey("custom.test.house", direction, mode), answer: "test", correct: mode == .writeIn, at: Date(), sequence: 1)
        }
    }
    let states = try store.states()
    #expect(states.count == 4)
    for (key, state) in states {
        #expect(state.totalCorrect == (key.mode == .writeIn ? 1 : 0))
        #expect(state.totalWrong == (key.mode == .writeIn ? 0 : 1))
    }
}
@Test func bundledColorSynonymsAreAccepted() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let bank = try BankCodec.decode(String(contentsOf: root.appendingPathComponent("Sources/MalApp/Resources/Banks/novice.yaml"), encoding: .utf8), allowBuiltIn: true)
    let red = try #require(bank.entries.first { $0.lemma == "빨갛다" })
    for value in ["빨간", "빨개요", "빨갛습니다", "붉다", "붉은", "붉어요", "붉습니다"] { #expect(Grader.isCorrect(value, entry: red, direction: .englishToKorean)) }
    #expect(!Grader.isCorrect("붉었어요", entry: red, direction: .englishToKorean))
}
