import Foundation

public enum SpokenDecision: Equatable { case correct(String), confirm(String), incorrect }
public enum SpokenGrader {
    public static func decide(heard: String, alternatives: [String], accepted: Set<String>, preferredAnswer: String? = nil) -> SpokenDecision {
        let heard = Grader.normalize(heard, direction: .englishToKorean)
        let targets = accepted.sorted()
        guard !heard.isEmpty else { return .incorrect }
        if accepted.contains(heard) { return .correct(heard) }
        for alternative in alternatives {
            let value = Grader.normalize(alternative, direction: .englishToKorean)
            if accepted.contains(value) { return .correct(value) }
        }
        let soundsLike = targets.filter { difference(heard, $0) == 1 }
        if soundsLike.count == 1 { return .correct(soundsLike[0]) }
        let near = targets.filter { difference(heard, $0) != nil }
        if let candidate = near.first { return .confirm(candidate) }
        // A text transcript alone cannot establish that the learner spoke the wrong
        // word. Unmatched speech requires a decision, never an automatic failure.
        if let preferredAnswer, accepted.contains(preferredAnswer) { return .confirm(preferredAnswer) }
        if let candidate = targets.first { return .confirm(candidate) }
        return .incorrect
    }
    // One substituted Hangul syllable only. Initial plain/tense pairs can pass;
    // other consonant/vowel changes need explicit confirmation. No insertions,
    // deletions, negation removal or conjugation inference.
    private static func difference(_ a: String, _ b: String) -> Int? {
        let lhs = Array(a.unicodeScalars), rhs = Array(b.unicodeScalars)
        guard lhs.count == rhs.count else { return nil }
        let differences = lhs.indices.filter { lhs[$0] != rhs[$0] }
        guard differences.count == 1, let index = differences.first else { return nil }
        let x = Int(lhs[index].value) - 0xAC00, y = Int(rhs[index].value) - 0xAC00
        guard (0..<11172).contains(x), (0..<11172).contains(y) else { return nil }
        let pairs = [[0, 1], [3, 4], [7, 8], [9, 10], [12, 13]]
        if x % 588 == y % 588, pairs.contains(where: { $0.contains(x / 588) && $0.contains(y / 588) }) { return 1 }
        let changedComponents = (x / 588 == y / 588 ? 0 : 1) + ((x % 588) / 28 == (y % 588) / 28 ? 0 : 1) + (x % 28 == y % 28 ? 0 : 1)
        return changedComponents <= 2 ? 2 : nil
    }
}
