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
    var settings = StudySettings(); settings.mode = .writeIn; settings.parts = [.noun]; settings.choiceCount = 10; settings.automaticPronunciation = true; settings.spokenAnswers = true; settings.formStyle = .polite
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
@Test @MainActor func nestedBankCannotTakeOwnershipOfAnEntry() throws {
    let store = try temporaryStore(); defer { store.close() }
    let original = Bank(id: "custom.parent", title: "Original", entries: [Entry(id: "custom.parent.child.word", lemma: "집", partOfSpeech: .noun, english: ["house"])])
    _ = try store.importBank(original)
    let conflicting = Bank(id: "custom.parent.child", title: "Conflicting", entries: [Entry(id: "custom.parent.child.word", lemma: "책", partOfSpeech: .noun, english: ["book"])])
    #expect(throws: StoreError.self) { try store.importBank(conflicting) }
    #expect(try store.banks() == [original])
    let reserved = Bank(id: "mal", title: "Reserved", entries: [Entry(id: "mal.fake", lemma: "집", partOfSpeech: .noun, english: ["house"])])
    #expect(throws: ValidationFailure.self) { try store.importBank(reserved) }
}

@Test @MainActor func introductionPresentationDoesNotGradeOrGraduate() throws {
    let store = try temporaryStore()
    let path = store.url
    _ = try store.importBank(fixture())
    let key = CardKey("custom.test.house", .englishToKorean, .multipleChoice)
    try store.present(key, at: Date(timeIntervalSince1970: 1000))
    #expect(try store.states().isEmpty)
    #expect(try store.history().isEmpty)
    #expect(try store.answerSequence() == 0)
    store.close()
    let reopened = try Store(url: path); defer { reopened.close() }
    #expect(try reopened.states().isEmpty)
    #expect(try reopened.history().isEmpty)
    let first = try reopened.grade(key, answer: "집", correct: true, at: Date(timeIntervalSince1970: 1001), sequence: 1)
    #expect(first.step == 1)
    #expect(first.totalCorrect == 1)
    #expect(first.totalWrong == 0)
    #expect(first.graduated == false)
}

@Test @MainActor func reinforcementSurvivesRestartAndUndo() throws {
    let store = try temporaryStore(); let path = store.url
    let key = CardKey("test.go", .englishToKorean, .writeIn, formStyle: .polite)
    let now = Date(timeIntervalSince1970: 1000)
    let first = try store.grade(key, answer: "가요", correct: true, at: now, sequence: 1)
    _ = try store.grade(key, answer: "가요", correct: true, at: now.addingTimeInterval(20), sequence: 5)
    #expect(try store.states()[key]?.reinforceAfterSequence == nil)
    #expect(try store.undo() == key)
    store.close()
    let reopened = try Store(url: path); defer { reopened.close() }
    #expect(try reopened.states()[key] == first)
    #expect(try reopened.states()[key]?.dueSequence == 4)
}

@Test @MainActor func localClocksSurviveOverrideUndoAndRestore() throws {
    let store = try temporaryStore(); defer { store.close() }
    let key = CardKey("word", .englishToKorean, .writeIn, formStyle: .polite)
    let other = CardKey("word", .koreanToEnglish, .multipleChoice, formStyle: .casual)
    let now = Date(timeIntervalSince1970: 1000)
    _ = try store.grade(key, answer: "a", correct: false, at: now, sequence: 999)
    for n in 0..<25 { _ = try store.grade(other, answer: "b", correct: true, at: now, sequence: n) }
    #expect(try store.answerSequences()[key.trackID] == 1)
    #expect(try store.states()[key]?.dueSequence == 4)
    _ = try store.grade(key, answer: "a", correct: false, at: now, sequence: 999)
    _ = try store.correctLastAnswer(expectedKey: key, saveAlias: false)
    #expect(try store.answerSequences()[key.trackID] == 2)
    #expect(try store.answersSinceIntroduction(trackID: key.trackID) == 2)
    _ = try store.undo()
    #expect(try store.answerSequences()[key.trackID] == 1)
    let backup = store.url.deletingLastPathComponent().appendingPathComponent("clocks.sqlite")
    try store.backup(to: backup)
    _ = try store.grade(key, answer: "a", correct: true, at: now, sequence: 999)
    try store.restore(from: backup)
    #expect(try store.answerSequences()[key.trackID] == 1)
    #expect(try store.answerSequences()[other.trackID] == 25)
}

@Test @MainActor func unknownRecallPersistsAndUndoRestoresSchedule() throws {
    let store = try temporaryStore(); let path = store.url
    let key = CardKey("test.go", .englishToKorean, .writeIn, formStyle: .polite)
    let now = Date(timeIntervalSince1970: 1000)
    let before = try store.grade(key, answer: "가요", correct: true, at: now, sequence: 1)
    let after = try store.didNotKnow(key, at: now, clockTrackID: key.trackID)
    #expect(after.totalWrong == 1 && after.totalCorrect == 1)
    #expect(after.due == now.addingTimeInterval(30) && after.dueSequence == 5)
    #expect(try store.history().first?.didNotKnow == true)
    #expect(try store.answerSequences()[key.trackID] == 2)
    store.close()
    let reopened = try Store(url: path); defer { reopened.close() }
    #expect(try reopened.history().first?.didNotKnow == true)
    #expect(try reopened.states()[key] == after)
    _ = try reopened.undo()
    #expect(try reopened.states()[key] == before)
    #expect(try reopened.answerSequences()[key.trackID] == 1)
    #expect(try reopened.history().first?.undone == true)
}

@Test @MainActor func bundledMeetAndRememberedEnglishAliasWorkInPolitePractice() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let bank = try BankCodec.decode(String(contentsOf: root.appendingPathComponent("Sources/MalApp/Resources/Banks/novice.yaml"), encoding: .utf8), allowBuiltIn: true)
    let meet = try #require(bank.entries.first { $0.lemma == "만나다" })
    #expect(FormPractice.accepted(meet, direction: .koreanToEnglish, style: .polite, pool: bank.entries, displayedKorean: "만나요").contains("meet"))
    let store = try temporaryStore(); let path = store.url
    let key = FormPractice.key(meet, direction: .koreanToEnglish, mode: .writeIn, style: .polite)
    _ = try store.grade(key, answer: "encounter", correct: false, at: Date(), sequence: 1)
    _ = try store.correctLastAnswer(expectedKey: key, saveAlias: true)
    store.close()
    let reopened = try Store(url: path); defer { reopened.close() }
    let accepted = FormPractice.accepted(meet, direction: .koreanToEnglish, style: .polite, pool: bank.entries, displayedKorean: "만나요", aliases: try reopened.aliases(direction: .koreanToEnglish))
    #expect(accepted.contains("encounter"))
    #expect(try reopened.states()[key]?.totalCorrect == 1)
    #expect(try reopened.states()[key]?.totalWrong == 0)
}
