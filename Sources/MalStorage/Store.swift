import Foundation
import CSQLite
import MalCore

public struct StoreError: Error, LocalizedError {
    public let message: String
    public init(message: String) { self.message = message }
    public var errorDescription: String? { message }
}
public struct ImportSummary: Equatable, Sendable {
    public var added: Int = 0
    public var changed: Int = 0
    public var retired: Int = 0
    public var unchanged: Bool = false
    public var description: String { unchanged ? "Already up to date." : "\(added) added, \(changed) changed, \(retired) retired." }
}
public struct HistoryItem: Identifiable, Sendable {
    public let id: Int
    public let key: CardKey
    public let answer: String
    public let correct: Bool
    // Empty answers are reserved for explicit unsuccessful recall, never submitted text.
    public var didNotKnow: Bool { !correct && answer.isEmpty }
    public let timestamp: Date
    public let undone: Bool
}
// Main-actor confinement keeps the SQLite connection and its transactions serialized.
@MainActor public final class Store {
    private var db: OpaquePointer?
    public let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw StoreError(message: "Cannot open database.") }
        sqlite3_busy_timeout(db, 5000)
        do {
            let version = Int(try rows("PRAGMA user_version").first?.first ?? "0") ?? 0
            guard version <= 3 else { throw StoreError(message: "This database requires a newer Mal version.") }
            if version == 0 {
                if !(try rows("SELECT name FROM sqlite_master WHERE type='table'")).isEmpty {
                    try backup(to: url.appendingPathExtension("pre-migration"))
                }
                try transaction {
                    try execute("CREATE TABLE IF NOT EXISTS banks(id TEXT PRIMARY KEY, data TEXT NOT NULL)")
                    try execute("CREATE TABLE IF NOT EXISTS entries(id TEXT PRIMARY KEY, bank_id TEXT NOT NULL, data TEXT NOT NULL, active INTEGER NOT NULL)")
                    try execute("CREATE TABLE IF NOT EXISTS states(id TEXT PRIMARY KEY, key_data TEXT NOT NULL, data TEXT NOT NULL)")
                    try execute("CREATE TABLE IF NOT EXISTS aliases(entry_id TEXT NOT NULL, direction TEXT NOT NULL, answer TEXT NOT NULL, UNIQUE(entry_id,direction,answer))")
                    try execute("CREATE TABLE IF NOT EXISTS presentations(id INTEGER PRIMARY KEY, key_data TEXT NOT NULL, timestamp REAL NOT NULL)")
                    try execute("CREATE TABLE IF NOT EXISTS attempts(id INTEGER PRIMARY KEY, key_data TEXT NOT NULL, answer TEXT NOT NULL, correct INTEGER NOT NULL, timestamp REAL NOT NULL, before_data TEXT, after_data TEXT NOT NULL, undone INTEGER NOT NULL DEFAULT 0, scheduler_version INTEGER NOT NULL)")
                    try execute("CREATE TABLE IF NOT EXISTS preferences(id TEXT PRIMARY KEY, data TEXT NOT NULL)")
                    try execute("PRAGMA user_version=2")
                }
            }
            if version > 0 && version < 3 {
                try backup(to: url.appendingPathExtension("pre-migration-v\(version)-" + UUID().uuidString))
            }
            try migrateClocks()
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    private func migrateClocks() throws {
        try transaction {
            if !(try rows("PRAGMA table_info(attempts)")).contains(where: { $0[1] == "clock_track" }) {
                try execute("ALTER TABLE attempts ADD COLUMN clock_track TEXT")
            }
            for row in try rows("SELECT id,key_data FROM attempts WHERE clock_track IS NULL") {
                let key = try decode(CardKey.self, row[1])
                try execute("UPDATE attempts SET clock_track=? WHERE id=?", [key.trackID, row[0]])
            }
            try execute("CREATE INDEX IF NOT EXISTS attempt_clocks ON attempts(clock_track,undone)")
            let clocks = try answerSequences()
            for (key, prior) in try states() where prior.scheduleVersion != LearningState.schedulerVersion {
                let track = prior.clockTrackID ?? key.trackID
                var state = Scheduler.upgrade(prior, sequence: clocks[track, default: 0])
                state.clockTrackID = track
                try execute("UPDATE states SET data=? WHERE id=?", [try json(state), key.storageID])
            }
            try execute("PRAGMA user_version=3")
        }
    }
    public func answerSequences() throws -> [String: Int] {
        Dictionary(uniqueKeysWithValues: try rows("SELECT clock_track,COUNT(*) FROM attempts WHERE undone=0 GROUP BY clock_track").map { ($0[0], Int($0[1])!) })
    }
    public func answersSinceIntroduction(trackID: String) throws -> Int {
        let attempts = try rows("SELECT before_data FROM attempts WHERE undone=0 AND clock_track=? ORDER BY id DESC", [trackID])
        return attempts.firstIndex(where: { $0[0].isEmpty }).map { $0 + 1 } ?? 5
    }
    private func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
    private func decode<T: Decodable>(_ type: T.Type, _ value: String) throws -> T { try decoder.decode(type, from: Data(value.utf8)) }
    private func prepare(_ sql: String, _ values: [String?]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        for (index, value) in values.enumerated() {
            let status = value.map { sqlite3_bind_text(statement, Int32(index + 1), $0, -1, transient) } ?? sqlite3_bind_null(statement, Int32(index + 1))
            guard status == SQLITE_OK else { sqlite3_finalize(statement); throw failure() }
        }
        return statement
    }
    private func failure() -> StoreError { StoreError(message: db.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed.") }
    private func execute(_ sql: String, _ values: [String?] = []) throws {
        let statement = try prepare(sql, values); defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE || status == SQLITE_ROW else { throw failure() }
    }
    private func rows(_ sql: String, _ values: [String?] = []) throws -> [[String]] {
        let statement = try prepare(sql, values); defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw failure() }
            result.append((0..<sqlite3_column_count(statement)).map { index in
                sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
            })
        }
    }
    private func transaction<T>(_ action: () throws -> T) throws -> T {
        if sqlite3_get_autocommit(db) == 0 { return try action() }
        try execute("BEGIN IMMEDIATE")
        do { let result = try action(); try execute("COMMIT"); return result }
        catch { try? execute("ROLLBACK"); throw error }
    }
    public func importBank(_ bank: Bank, builtIn: Bool = false) throws -> ImportSummary {
        let errors = BankCodec.validate(bank, allowBuiltIn: builtIn)
        guard errors.isEmpty else { throw ValidationFailure(errors) }
        return try transaction {
            let prior = try rows("SELECT data FROM banks WHERE id=?", [bank.id]).first.map { try decode(Bank.self, $0[0]) }
            if prior == bank { return ImportSummary(unchanged: true) }
            if let prior, bank.contentVersion <= prior.contentVersion { throw StoreError(message: "Changed content requires a higher contentVersion than \(prior.contentVersion).") }
            let oldRows = try rows("SELECT id,data,active FROM entries WHERE bank_id=?", [bank.id])
            let old = Dictionary(uniqueKeysWithValues: oldRows.map { ($0[0], $0) })
            let incoming = Set(bank.entries.map(\.id))
            var summary = ImportSummary()
            summary.retired = oldRows.filter { $0[2] == "1" && !incoming.contains($0[0]) }.count
            try execute("UPDATE entries SET active=0 WHERE bank_id=?", [bank.id])
            for entry in bank.entries {
                if let owner = try rows("SELECT bank_id FROM entries WHERE id=?", [entry.id]).first?.first, owner != bank.id { throw StoreError(message: "Entry \(entry.id) belongs to bank \(owner); IDs cannot cross bank ownership.") }
                if let previous = old[entry.id] {
                    if try decode(Entry.self, previous[1]) != entry || previous[2] != "1" { summary.changed += 1 }
                } else { summary.added += 1 }
                try execute("INSERT INTO entries VALUES(?,?,?,1) ON CONFLICT(id) DO UPDATE SET data=excluded.data,active=1", [entry.id, bank.id, try json(entry)])
            }
            try execute("INSERT INTO banks VALUES(?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data", [bank.id, try json(bank)])
            return summary
        }
    }
    public func banks() throws -> [Bank] { try rows("SELECT data FROM banks ORDER BY rowid").map { try decode(Bank.self, $0[0]) } }
    public func states() throws -> [CardKey: LearningState] {
        try Dictionary(uniqueKeysWithValues: rows("SELECT key_data,data FROM states").map { (try decode(CardKey.self, $0[0]), try decode(LearningState.self, $0[1])) })
    }
    public func settings() throws -> StudySettings {
        try rows("SELECT data FROM preferences WHERE id='study'").first.map { try decode(StudySettings.self, $0[0]) } ?? StudySettings()
    }
    public func saveSettings(_ settings: StudySettings) throws {
        try execute("INSERT INTO preferences VALUES('study',?) ON CONFLICT(id) DO UPDATE SET data=excluded.data", [try json(settings)])
    }
    public func aliases(direction: Direction) throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for row in try rows("SELECT entry_id,answer FROM aliases WHERE direction=?", [direction.rawValue]) { result[row[0], default: []].append(row[1]) }
        return result
    }
    public func addAlias(entryID: String, direction: Direction, answer: String) throws {
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError(message: "An alias cannot be blank.") }
        try execute("INSERT OR IGNORE INTO aliases VALUES(?,?,?)", [entryID, direction.rawValue, answer])
    }
    public func present(_ key: CardKey, at date: Date) throws {
        try execute("INSERT INTO presentations(key_data,timestamp) VALUES(?,?)", [try json(key), String(date.timeIntervalSince1970)])
    }
    @discardableResult public func grade(_ key: CardKey, answer: String, correct: Bool, at now: Date, sequence: Int, clockTrackID: String? = nil) throws -> LearningState {
        try transaction {
            let before = try rows("SELECT data FROM states WHERE id=?", [key.storageID]).first?.first
            let prior = try before.map { try decode(LearningState.self, $0) } ?? LearningState(due: now)
            let track = clockTrackID ?? key.trackID
            let localSequence = try answerSequences()[track, default: 0] + 1
            let introduced = try states().filter { ($0.value.clockTrackID ?? $0.key.trackID) == track }.count + (before == nil ? 1 : 0)
            var after = Scheduler.grade(prior, correct: correct, mode: key.mode, now: now, sequence: localSequence, introducedCount: introduced)
            after.clockTrackID = track
            try execute("INSERT INTO states VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data", [key.storageID, try json(key), try json(after)])
            try execute("INSERT INTO attempts(key_data,answer,correct,timestamp,before_data,after_data,scheduler_version,clock_track) VALUES(?,?,?,?,?,?,?,?)", [try json(key), answer, correct ? "1" : "0", String(now.timeIntervalSince1970), before, try json(after), String(LearningState.schedulerVersion), track])
            return after
        }
    }
    @discardableResult public func didNotKnow(_ key: CardKey, at now: Date, clockTrackID: String? = nil) throws -> LearningState {
        try grade(key, answer: "", correct: false, at: now, sequence: 0, clockTrackID: clockTrackID)
    }
    @discardableResult public func undo() throws -> CardKey? {
        try transaction {
            guard let row = try rows("SELECT id,key_data,before_data FROM attempts WHERE undone=0 ORDER BY id DESC LIMIT 1").first else { return nil }
            let key = try decode(CardKey.self, row[1])
            if row[2].isEmpty { try execute("DELETE FROM states WHERE id=?", [key.storageID]) }
            else { try execute("UPDATE states SET data=? WHERE id=?", [row[2], key.storageID]) }
            try execute("UPDATE attempts SET undone=1 WHERE id=?", [row[0]])
            try migrateClocks()
            return key
        }
    }
    @discardableResult public func correctLastAnswer(expectedKey: CardKey, saveAlias: Bool) throws -> LearningState {
        try transaction {
            guard let row = try rows("SELECT key_data,answer,timestamp,correct,clock_track FROM attempts WHERE undone=0 ORDER BY id DESC LIMIT 1").first,
                  try decode(CardKey.self, row[0]) == expectedKey, row[3] == "0" else { throw StoreError(message: "The last answer has changed; it cannot be overridden.") }
            _ = try undo()
            if saveAlias { try addAlias(entryID: expectedKey.entryID, direction: expectedKey.direction, answer: row[1]) }
            return try grade(expectedKey, answer: row[1], correct: true, at: Date(timeIntervalSince1970: Double(row[2])!), sequence: answerSequence() + 1, clockTrackID: row[4])
        }
    }
    public func history(limit: Int = 200) throws -> [HistoryItem] {
        try rows("SELECT id,key_data,answer,correct,timestamp,undone FROM attempts ORDER BY id DESC LIMIT ?", [String(limit)]).map {
            HistoryItem(id: Int($0[0])!, key: try decode(CardKey.self, $0[1]), answer: $0[2], correct: $0[3] == "1", timestamp: Date(timeIntervalSince1970: Double($0[4])!), undone: $0[5] == "1")
        }
    }
    public func answerSequence() throws -> Int { Int(try rows("SELECT COUNT(*) FROM attempts WHERE undone=0").first![0])! }
    public func backup(to destination: URL) throws {
        guard destination.standardizedFileURL != url.standardizedFileURL else { throw StoreError(message: "Choose a different backup destination.") }
        var target: OpaquePointer?
        guard sqlite3_open(destination.path, &target) == SQLITE_OK else { sqlite3_close(target); throw StoreError(message: "Cannot open backup destination.") }
        defer { sqlite3_close(target) }
        guard let backup = sqlite3_backup_init(target, "main", db, "main") else { throw StoreError(message: "Cannot start backup.") }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE && finish == SQLITE_OK else { throw StoreError(message: "Backup failed.") }
        // Backup copies the source journal mode. Export a standalone file that
        // can be opened read-only without needing WAL/SHM sidecars.
        guard sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else { throw StoreError(message: "Cannot finalize standalone backup.") }
    }
    public func restore(from source: URL) throws {
        guard source.standardizedFileURL != url.standardizedFileURL else { throw StoreError(message: "Choose a backup file, not the live database.") }
        var candidate: OpaquePointer?
        guard sqlite3_open_v2(source.path, &candidate, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { sqlite3_close(candidate); throw StoreError(message: "Cannot open backup.") }
        defer { sqlite3_close(candidate) }
        func scalar(_ sql: String) throws -> String {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(candidate, sql, -1, &statement, nil) == SQLITE_OK else { throw StoreError(message: "Not a Mal backup: " + String(cString: sqlite3_errmsg(candidate))) }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW, let value = sqlite3_column_text(statement, 0) else { throw StoreError(message: "Invalid backup.") }
            return String(cString: value)
        }
        guard try scalar("PRAGMA integrity_check") == "ok", ["1", "2", "3"].contains(try scalar("PRAGMA user_version")),
              try scalar("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('banks','entries','states','aliases','presentations','attempts','preferences')") == "7" else { throw StoreError(message: "Unsupported or corrupt Mal backup.") }
        // Decode every persisted domain record before replacing anything.
        for (table, column, validate) in [
            ("banks", "data", { (s: String) throws in _ = try self.decode(Bank.self, s) }),
            ("entries", "data", { (s: String) throws in _ = try self.decode(Entry.self, s) }),
            ("states", "data", { (s: String) throws in _ = try self.decode(LearningState.self, s) }),
            ("states", "key_data", { (s: String) throws in _ = try self.decode(CardKey.self, s) }),
            ("preferences", "data", { (s: String) throws in _ = try self.decode(StudySettings.self, s) }),
            ("attempts", "key_data", { (s: String) throws in _ = try self.decode(CardKey.self, s) }),
            ("attempts", "after_data", { (s: String) throws in _ = try self.decode(LearningState.self, s) }),
            ("attempts", "before_data", { (s: String) throws in if !s.isEmpty { _ = try self.decode(LearningState.self, s) } }),
            ("presentations", "key_data", { (s: String) throws in _ = try self.decode(CardKey.self, s) })
        ] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(candidate, "SELECT \(column) FROM \(table)", -1, &statement, nil) == SQLITE_OK else { throw StoreError(message: "Invalid backup schema.") }
            defer { sqlite3_finalize(statement) }
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { break }
                guard status == SQLITE_ROW else { throw StoreError(message: "Unreadable backup record.") }
                let value = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
                try validate(value)
            }
        }
        try backup(to: url.deletingLastPathComponent().appendingPathComponent("pre-restore-\(UUID().uuidString).sqlite"))
        guard let operation = sqlite3_backup_init(db, "main", candidate, "main") else { throw failure() }
        let status = sqlite3_backup_step(operation, -1)
        let finish = sqlite3_backup_finish(operation)
        guard status == SQLITE_DONE && finish == SQLITE_OK else { throw StoreError(message: "Restore failed; original backup retained.") }
        try migrateClocks()
        try execute("PRAGMA journal_mode=WAL")
    }
    public func close() { if db != nil { sqlite3_close(db); db = nil } }
}
