import Foundation

/// Explicit, independently testable recognition accommodations. Never used by
/// typed grading or written back as vocabulary aliases. Rules do not compose:
/// one rule must explain the entire candidate/answer difference.
public enum SpeechMatchingRule: String, CaseIterable, Sendable {
    case vowelPairs = "vowel-pairs-v1"
    case plainTenseInitial = "plain-tense-initial-v1"

    case rieulDigeutBeforeVowel = "rieul-digeut-before-a-eo-v1"

    public var allowsLiveMatch: Bool {
        switch self {
        case .vowelPairs, .plainTenseInitial, .rieulDigeutBeforeVowel: true
        }
    }

    public func matches(_ candidate: String, _ answer: String) -> Bool {
        let lhs = Array(candidate.precomposedStringWithCanonicalMapping.unicodeScalars)
        let rhs = Array(answer.precomposedStringWithCanonicalMapping.unicodeScalars)
        guard lhs.count == rhs.count else { return false }
        let changed = lhs.indices.filter { lhs[$0] != rhs[$0] }
        guard !changed.isEmpty else { return false }
        if self != .vowelPairs && changed.count != 1 { return false }
        return changed.allSatisfy { index in
            let a = Int(lhs[index].value) - 0xAC00, b = Int(rhs[index].value) - 0xAC00
            guard (0..<11172).contains(a), (0..<11172).contains(b) else { return false }
            let onsetA = a / 588, onsetB = b / 588
            let vowelA = (a % 588) / 28, vowelB = (b % 588) / 28
            if self == .rieulDigeutBeforeVowel {
                // One ㄹ/ㄷ coda confusion immediately before 아/어. Permit
                // the already-supported plain/tense onset pair in this same
                // syllable explicitly; no arbitrary chaining of other rules.
                guard Set([a % 28, b % 28]) == Set([7, 8]), vowelA == vowelB,
                      index + 1 < lhs.count, lhs[index + 1] == rhs[index + 1] else { return false }
                let next = Int(lhs[index + 1].value) - 0xAC00
                guard (0..<11172).contains(next), next / 588 == 11,
                      [0, 4].contains((next % 588) / 28) else { return false }
                return onsetA == onsetB || [[0, 1], [3, 4], [7, 8], [9, 10], [12, 13]].contains {
                    $0.contains(onsetA) && $0.contains(onsetB)
                }
            }
            guard a % 28 == b % 28 else { return false }
            switch self {
            case .vowelPairs:
                return onsetA == onsetB && [[1, 5], [3, 7]].contains {
                    $0.contains(vowelA) && $0.contains(vowelB)
                }
            case .rieulDigeutBeforeVowel: return false // Handled above.
            case .plainTenseInitial:
                return vowelA == vowelB && [[0, 1], [3, 4], [7, 8], [9, 10], [12, 13]].contains {
                    $0.contains(onsetA) && $0.contains(onsetB)
                }
            }
        }
    }
}

public struct SpeechRuleMatch: Equatable, Sendable {
    public let answer: String
    public let candidate: String
    public let rule: SpeechMatchingRule
}

public enum SpeechMatchingRules {
    public static let defaults: [SpeechMatchingRule] = [.vowelPairs, .plainTenseInitial, .rieulDigeutBeforeVowel]

    /// Return evidence, not an arbitrary winning rule. Callers resolve ambiguity
    /// across the union of all rules and recognition hypotheses.
    public static func evaluate(heard: String, alternatives: [String], accepted: Set<String>,
                                live: Bool = false,
                                rules: [SpeechMatchingRule] = defaults) -> [SpeechRuleMatch] {
        ([heard] + alternatives).flatMap { hypothesis in
            let words = tokens(hypothesis)
            return accepted.sorted().flatMap { answer -> [SpeechRuleMatch] in
                let count = tokens(answer).count
                guard count > 0, words.count >= count else { return [] }
                return (0...(words.count - count)).flatMap { start in
                    let candidate = words[start..<(start + count)].joined(separator: " ")
                    let expected = tokens(answer).joined(separator: " ")
                    return rules.filter { (!live || $0.allowsLiveMatch) && $0.matches(candidate, expected) }
                        .map { SpeechRuleMatch(answer: answer, candidate: candidate, rule: $0) }
                }
            }
        }
    }

    static func tokens(_ text: String) -> [String] {
        Grader.normalize(text, direction: .englishToKorean)
            .components(separatedBy: CharacterSet.alphanumerics.union(.nonBaseCharacters).inverted)
            .filter { !$0.isEmpty }
    }
}
