import Foundation

public enum Direction: String, Codable, CaseIterable, Sendable {
    case englishToKorean, koreanToEnglish
    public var label: String { self == .englishToKorean ? "English → Korean" : "Korean → English" }
}
public enum AnswerMode: String, Codable, CaseIterable, Sendable {
    case multipleChoice, writeIn
    public var label: String { self == .multipleChoice ? "Multiple choice" : "Write-in" }
}
public enum PartOfSpeech: String, Codable, CaseIterable, Sendable {
    case noun, verb, adjective, adverb, other
    public var label: String {
        switch self { case .noun: "Nouns"; case .verb: "Action verbs"; case .adjective: "Descriptive verbs / adjectives"; case .adverb: "Adverbs"; case .other: "Other" }
    }
}
public struct KoreanForm: Codable, Equatable, Sendable {
    public var text: String
    public var speechLevel: String?
    public var honorific: Bool?
    public var attributive: Bool?
    public init(_ text: String, speechLevel: String? = nil, honorific: Bool? = nil, attributive: Bool? = nil) {
        self.text = text; self.speechLevel = speechLevel; self.honorific = honorific; self.attributive = attributive
    }
}
public struct Entry: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var lemma: String
    public var partOfSpeech: PartOfSpeech
    public var english: [String]
    public var promptCue: String?
    public var koreanForms: [KoreanForm]
    public var notes: String?
    public var verification: String
    public init(id: String, lemma: String, partOfSpeech: PartOfSpeech, english: [String], promptCue: String? = nil, koreanForms: [KoreanForm] = [], notes: String? = nil, verification: String = "draft") {
        self.id = id; self.lemma = lemma; self.partOfSpeech = partOfSpeech; self.english = english; self.promptCue = promptCue; self.koreanForms = koreanForms; self.notes = notes; self.verification = verification
    }
    public func prompt(_ direction: Direction) -> String {
        let base = direction == .englishToKorean ? (english.first ?? "") : lemma
        guard let cue = promptCue else { return base }
        if direction == .koreanToEnglish { return base }
        return "\(base) (\(cue))"
    }
    public func answer(_ direction: Direction) -> String { direction == .englishToKorean ? lemma : (english.first ?? "") }
}
public struct Provenance: Codable, Equatable, Sendable {
    public var source: String
    public var license: String
    public var notes: String?
    public init(source: String, license: String, notes: String? = nil) { self.source = source; self.license = license; self.notes = notes }
}
public struct Bank: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var contentVersion: Int
    public var title: String
    public var provenance: Provenance
    public var entries: [Entry]
    public init(id: String, title: String, entries: [Entry], contentVersion: Int = 1, provenance: Provenance = .init(source: "Original", license: "Personal use")) {
        schemaVersion = 1; self.id = id; self.title = title; self.entries = entries; self.contentVersion = contentVersion; self.provenance = provenance
    }
}
public struct CardKey: Codable, Hashable, Sendable {
    public var entryID: String
    public var direction: Direction
    public var mode: AnswerMode
    public init(_ entryID: String, _ direction: Direction, _ mode: AnswerMode) { self.entryID = entryID; self.direction = direction; self.mode = mode }
    public var storageID: String { "\(entryID)|\(direction.rawValue)|\(mode.rawValue)" }
}
public enum Phase: String, Codable, Sendable { case learning, review, relearning }
public struct LearningState: Codable, Equatable, Sendable {
    public static let schedulerVersion = 1
    public var phase: Phase = .learning
    public var step: Int = 0
    public var due: Date
    public var interval: TimeInterval = 0
    public var recent: [Bool] = []
    public var totalCorrect: Int = 0
    public var totalWrong: Int = 0
    public var retryAfterSequence: Int = 0
    public var graduated: Bool = false
    public init(due: Date) { self.due = due }
}
public struct StudySettings: Codable, Equatable, Sendable {
    public var direction: Direction = .englishToKorean
    public var mode: AnswerMode = .multipleChoice
    public var bankIDs: Set<String> = ["mal.novice"]
    public var parts: Set<PartOfSpeech> = Set(PartOfSpeech.allCases)
    public var choiceCount: Int = 5
    // Optional so existing settings and backups decode without a schema migration.
    public var singleColumnDefaultApplied: Bool?
    public var automaticPronunciation: Bool?
    public var learningLimit: Int = 10
    // Retained for compatibility with existing settings/backups; no automatic pauses.
    public var reviewBatch: Int = 50
    public init() {}
}
public struct QueueContext: Sendable {
    public var now: Date
    public var sequence: Int
    public var answersSinceIntroduction: Int
    public var previousSense: String?
    public init(now: Date, sequence: Int = 0, answersSinceIntroduction: Int = 5, previousSense: String? = nil) {
        self.now = now; self.sequence = sequence; self.answersSinceIntroduction = answersSinceIntroduction; self.previousSense = previousSense
    }
}
public struct Selection: Equatable, Sendable {
    public var entryID: String
    public var isNew: Bool
    public init(_ id: String, isNew: Bool) { entryID = id; self.isNew = isNew }
}
