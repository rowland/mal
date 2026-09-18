import Foundation

/// Rejects late recognition callbacks after stopping or changing cards.
/// A transcript is only a draft: this type never grades an answer.
public struct DictationDraft: Sendable {
    public private(set) var sessionID: UUID?
    public private(set) var text: String?
    public init() {}
    public mutating func begin(id: UUID) { sessionID = id; text = nil }
    @discardableResult public mutating func receive(_ text: String, id: UUID) -> Bool {
        guard sessionID == id, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // Speech models add sentence punctuation even for a one-word answer.
        // Remove it only from the end of the editable draft, not from grading rules.
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = cleaned.last, ".?!。？！".contains(last) { cleaned.removeLast() }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        self.text = cleaned
        return true
    }
    public mutating func end() { sessionID = nil }
}
