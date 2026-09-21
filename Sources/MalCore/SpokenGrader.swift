import Foundation

public enum SpokenDecision: Equatable { case correct(String), confirm(String), incorrect }
public enum SpokenGrader {
    /// Exact vocabulary matches in any current recognition hypothesis. Punctuation
    /// separates words; never accept an arbitrary substring of a longer word.
    /// Extra words are intentionally allowed: this is vocabulary, not sentence grading.
    public static func matches(heard: String, alternatives: [String], accepted: Set<String>) -> Set<String> {
        let words = SpeechMatchingRules.tokens
        let hypotheses = ([heard] + alternatives).map(words)
        return Set(accepted.filter { target in
            let expected = words(target)
            guard !expected.isEmpty else { return false }
            return hypotheses.contains { hypothesis in
                guard hypothesis.count >= expected.count else { return false }
                return (0...(hypothesis.count - expected.count)).contains { start in
                    Array(hypothesis[start..<(start + expected.count)]) == expected
                }
            }
        })
    }
    /// Exact evidence wins; tolerant evidence must identify one accepted answer.
    public static func liveMatch(heard: String, alternatives: [String], accepted: Set<String>) -> String? {
        let exact = matches(heard: heard, alternatives: alternatives, accepted: accepted)
        if let match = exact.sorted().first { return match }
        let answers = Set(SpeechMatchingRules.evaluate(heard: heard, alternatives: alternatives,
            accepted: accepted, live: true).map(\.answer))
        return answers.count == 1 ? answers.first : nil
    }
    public static func confirmationOptions(accepted: Set<String>, preferred: String) -> [String] {
        (accepted.contains(preferred) ? [preferred] : []) + accepted.filter { $0 != preferred }.sorted()
    }
    public static func decide(heard: String, alternatives: [String], accepted: Set<String>, preferredAnswer: String? = nil) -> SpokenDecision {
        let heard = Grader.normalize(heard, direction: .englishToKorean)
        let targets = accepted.sorted()
        guard !heard.isEmpty else { return .incorrect }
        let matches = matches(heard: heard, alternatives: alternatives, accepted: accepted)
        if matches.contains(heard) { return .correct(heard) }
        if let match = matches.sorted().first { return .correct(match) }
        let ruleAnswers = Set(SpeechMatchingRules.evaluate(heard: heard, alternatives: alternatives,
            accepted: accepted).map(\.answer))
        if ruleAnswers.count == 1, let match = ruleAnswers.first { return .correct(match) }
        if let candidate = ruleAnswers.sorted().first { return .confirm(candidate) }
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
