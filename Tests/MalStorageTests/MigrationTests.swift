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
