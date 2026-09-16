import Foundation
import Testing
import CSQLite
import MalCore
@testable import MalStorage

private func raw(_ path: URL, _ sql: String) throws {
    var db: OpaquePointer?
    guard sqlite3_open(path.path, &db) == SQLITE_OK else { throw StoreError(message: "Fixture open failed") }
    defer { sqlite3_close(db) }
    guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw StoreError(message: "Fixture SQL failed") }
}
@Test @MainActor func migrationFromUnversionedFixturePreservesDataAndBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mal-migration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("old.sqlite")
    let bank = Bank(id: "fixture.words", title: "Historical bank", entries: [Entry(id: "fixture.words.house", lemma: "집", partOfSpeech: .noun, english: ["house"])])
    let payload = String(decoding: try JSONEncoder().encode(bank), as: UTF8.self).replacingOccurrences(of: "'", with: "''")
    try raw(path, "CREATE TABLE banks(id TEXT PRIMARY KEY,data TEXT NOT NULL); INSERT INTO banks VALUES('fixture.words','\(payload)'); PRAGMA user_version=0;")
    let store = try Store(url: path); defer { store.close() }
    #expect(try store.banks() == [bank])
    #expect(FileManager.default.fileExists(atPath: path.appendingPathExtension("pre-migration").path))
    #expect(try store.states().isEmpty)
}
@Test @MainActor func newerSchemaIsRejectedWithoutModification() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("mal-future-\(UUID().uuidString).sqlite")
    try raw(path, "PRAGMA user_version=999; CREATE TABLE future_data(value TEXT); INSERT INTO future_data VALUES('preserve me');")
    let before = try Data(contentsOf: path)
    #expect(throws: StoreError.self) { try Store(url: path) }
    #expect(try Data(contentsOf: path) == before)
}
@Test @MainActor func malformedBackupPayloadDoesNotReplaceLiveProgress() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mal-corrupt-\(UUID().uuidString)")
    let store = try Store(url: directory.appendingPathComponent("live.sqlite")); defer { store.close() }
    let key = CardKey("test.word", .englishToKorean, .writeIn)
    let state = try store.grade(key, answer: "집", correct: true, at: Date(), sequence: 1)
    let backup = directory.appendingPathComponent("backup.sqlite")
    try store.saveSettings(StudySettings()); try store.backup(to: backup)
    try raw(backup, "UPDATE preferences SET data='broken JSON';")
    #expect(throws: (any Error).self) { try store.restore(from: backup) }
    #expect(try store.states()[key] == state)
}

@Test @MainActor func vocabularyToFormMigrationPreservesHistoryAndBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mal-forms-\(UUID().uuidString)")
    let path = directory.appendingPathComponent("progress.sqlite")
    let oldKey = CardKey("test.go", .englishToKorean, .writeIn)
    let politeKey = CardKey("test.go", .englishToKorean, .writeIn, formStyle: .polite)
    let casualKey = CardKey("test.go", .englishToKorean, .writeIn, formStyle: .casual)
    let now = Date(timeIntervalSince1970: 1000)
    let original = try Store(url: path)
    let oldState = try original.grade(oldKey, answer: "가다", correct: true, at: now, sequence: 1)
    let legacyBackup = directory.appendingPathComponent("legacy.sqlite")
    try original.backup(to: legacyBackup)
    original.close()
    try raw(path, "PRAGMA user_version=1;")
    try raw(legacyBackup, "PRAGMA user_version=1;")
    let store = try Store(url: path)
    #expect(try store.states()[oldKey] == oldState)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix("progress.sqlite.pre-migration-v1-") })
    let polite = try store.grade(politeKey, answer: "가요", correct: true, at: now, sequence: 2)
    _ = try store.grade(casualKey, answer: "가요", correct: false, at: now, sequence: 3)
    #expect(try store.states().count == 3)
    #expect(try store.undo() == casualKey)
    #expect(try store.states()[casualKey] == nil)
    #expect(try store.states()[politeKey] == polite)
    #expect(try store.states()[oldKey] == oldState)
    let modernBackup = directory.appendingPathComponent("forms.sqlite")
    try store.backup(to: modernBackup)
    try store.restore(from: legacyBackup)
    #expect(try store.states().count == 1)
    try store.restore(from: modernBackup)
    store.close()
    let reopened = try Store(url: path); defer { reopened.close() }
    #expect(try reopened.states()[politeKey] == polite)
    #expect(try reopened.history().first?.key == casualKey)
    #expect(try reopened.history().first?.undone == true)
}

@Test @MainActor func legacySchedulerMigrationPreservesDueAndAccuracy() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mal-clock-migration-\(UUID().uuidString)")
    let path = dir.appendingPathComponent("legacy.sqlite")
    let key = CardKey("old", .englishToKorean, .writeIn)
    let now = Date(timeIntervalSince1970: 1000)
    let original = try Store(url: path)
    _ = try original.grade(key, answer: "old", correct: true, at: now, sequence: 1)
    original.close()
    try raw(path, "UPDATE states SET data=json_remove(data,'$.scheduleVersion','$.dueSequence','$.answerInterval','$.clockTrackID'); DROP INDEX attempt_clocks; ALTER TABLE attempts DROP COLUMN clock_track; PRAGMA user_version=2;")
    let store = try Store(url: path); defer { store.close() }
    let state = try #require(store.states()[key])
    #expect(state.totalCorrect == 1 && state.recent == [true])
    #expect(state.due == now.addingTimeInterval(60))
    #expect(state.dueSequence == 4 && state.scheduleVersion == 3)
    #expect(try store.answerSequences()[key.trackID] == 1)
    #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).contains { $0.contains("pre-migration-v2-") })
}
